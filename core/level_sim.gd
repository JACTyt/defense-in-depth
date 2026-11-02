class_name LevelSim
extends RefCounted
## One attempt at a level, with no scene tree dependency. Scenes draw this state and forward input.
## Create a new instance to restart: the seeded RNG makes the attempt replay identically.

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int, breaches: int)
signal unit_breached(attack: AttackData)
signal unit_killed(attack: AttackData, position: Vector2)
signal defense_fired(placed: Placed, unit: Unit)
signal email_caught(node_id: int)
signal workstation_compromised(id: int)
signal workstation_cleaned(id: int)
signal report_raised(report: Dictionary)
signal level_won
signal level_lost

enum Phase { BUILD, ATTACK, WON, LOST }


class Slot:
	var type: GameTypes.SlotType
	var a: int
	var b: int
	var position: Vector2

	func _init(p_type: GameTypes.SlotType, p_a: int, p_b: int, p_position: Vector2) -> void:
		type = p_type
		a = p_a
		b = p_b
		position = p_position

	func key() -> String:
		return "%d:%d:%d" % [type, mini(a, b), maxi(a, b)]


class Placed:
	var data: DefenseData
	var slot: Slot
	var deploy_remaining: float
	var cooldown := 0.0

	func _init(p_data: DefenseData, p_slot: Slot, p_deploy: float) -> void:
		data = p_data
		slot = p_slot
		deploy_remaining = p_deploy

	func is_active() -> bool:
		return deploy_remaining <= 0.0


class Unit:
	var attack: AttackData
	var route: PackedInt64Array
	var points: PackedVector2Array
	var position: Vector2
	var hp: float
	var next_point := 1
	var target_workstation := -1

	func _init(p_attack: AttackData, p_route: PackedInt64Array, p_points: PackedVector2Array) -> void:
		attack = p_attack
		route = p_route
		points = p_points
		position = p_points[0]
		hp = p_attack.hp


var level: LevelData
var graph: NetworkGraph
var economy: Economy
var integrity := IntegrityTracker.new()
var phase := Phase.BUILD
var wave_number := 0
var build_remaining := Content.BUILD_SECONDS
var compromise_count := 0
var defenses: Array[Placed] = []
var units: Array[Unit] = []
var workstations: Dictionary = {}  # node id -> Workstation

var _rng := RandomNumberGenerator.new()
var _occupied: Dictionary = {}
var _elapsed := 0.0
var _spawns: Array[Dictionary] = []
var _routes: Dictionary = {}
var _clean_progress: Dictionary = {}
var _reported: Dictionary = {}
var _wave_breaches := 0
var _asset_id := -1
var _mail_id := -1
var _last_breach: Unit = null


func _init(p_level: LevelData) -> void:
	level = p_level
	graph = level.build_graph()
	economy = Economy.new(level.start_budget, level.quarterly_income)
	_rng.seed = level.rng_seed
	for node in level.nodes:
		match node.kind:
			GameTypes.NodeKind.WORKSTATION:
				workstations[node.id] = Workstation.new()
			GameTypes.NodeKind.ASSET:
				_asset_id = node.id
			GameTypes.NodeKind.MAIL_SERVER:
				_mail_id = node.id


func slots_for(data: DefenseData) -> Array[Slot]:
	var result: Array[Slot] = []
	if not level.allowed_defenses.has(data):
		return result
	if data.slot == GameTypes.SlotType.LINK:
		for link in level.links:
			if link.has_slot and not link.social:
				var middle := graph.position_of(link.a).lerp(graph.position_of(link.b), 0.5)
				result.append(Slot.new(data.slot, link.a, link.b, middle))
		return result
	for node in level.nodes:
		var fits := false
		match data.slot:
			GameTypes.SlotType.NODE:
				fits = node.has_slot
			GameTypes.SlotType.MAILBOX:
				fits = node.kind == GameTypes.NodeKind.MAIL_SERVER or node.kind == GameTypes.NodeKind.WORKSTATION
			GameTypes.SlotType.ASSET:
				fits = node.kind == GameTypes.NodeKind.ASSET
		if fits:
			result.append(Slot.new(data.slot, node.id, node.id, node.position))
	return result


func is_occupied(slot: Slot) -> bool:
	return _occupied.has(slot.key())


func place(data: DefenseData, slot: Slot) -> bool:
	if phase == Phase.WON or phase == Phase.LOST:
		return false
	if slot == null or slot.type != data.slot or is_occupied(slot) or not level.allowed_defenses.has(data):
		return false
	if not economy.buy(data):
		return false
	var deploy := Content.DEPLOY_SECONDS if phase == Phase.ATTACK else 0.0
	var placed := Placed.new(data, slot, deploy)
	defenses.append(placed)
	_occupied[slot.key()] = true
	if placed.is_active():
		_on_activated(placed)
	return true


func sell(placed: Placed) -> void:
	if not defenses.has(placed):
		return
	defenses.erase(placed)
	_occupied.erase(placed.slot.key())
	economy.sell(placed.data)
	if placed.data.slot == GameTypes.SlotType.LINK:
		graph.set_link_defended(placed.slot.a, placed.slot.b, false)


func start_wave_now() -> void:
	if phase == Phase.BUILD:
		_start_wave()


func tick(delta: float) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	integrity.tick(delta)
	_tick_deployments(delta)
	if phase == Phase.BUILD:
		build_remaining -= delta
		if build_remaining <= 0.0:
			_start_wave()
		return
	_elapsed += delta
	_tick_spawns()
	_tick_workstations(delta)
	_tick_defenses(delta)
	_tick_units(delta)
	if phase == Phase.ATTACK and _wave_is_over():
		_end_wave()


## Sends one phishing email: a mail server filter rolls first, then a random uncompromised
## workstation is targeted. A filter on that workstation rolls again when the email arrives.
func deliver_email() -> void:
	if _filter_catches(_mail_id):
		return
	var open: Array[int] = []
	for id: int in workstations:
		if not workstations[id].is_compromised:
			open.append(id)
	var target := PhishingRules.pick_target(_rng, open)
	if target == -1:
		return
	var route := graph.social_route(_mail_id, target)
	if route.is_empty():
		push_error("No social route from mail server to workstation %d" % target)
		return
	var unit := Unit.new(Content.phishing(), route, _points_of(route))
	unit.target_workstation = target
	units.append(unit)


func _start_wave() -> void:
	wave_number += 1
	phase = Phase.ATTACK
	_elapsed = 0.0
	_wave_breaches = 0
	economy.start_wave()
	_spawns.clear()
	_routes.clear()
	_clean_progress.clear()
	var wave := level.waves[wave_number - 1]
	for entry in wave.entries:
		if entry.count > 0:
			_spawns.append({"entry": entry, "next": entry.start_delay, "left": entry.count})
			if entry.attack.path == GameTypes.PathType.CABLE:
				_route_between(entry.entry_node, entry.target_node)
	for id: int in workstations:
		_route_between(id, _asset_id)
	wave_started.emit(wave_number)


func _end_wave() -> void:
	for id: int in workstations:
		workstations[id].reset_for_wave()
	economy.end_wave(wave_number)
	wave_ended.emit(wave_number, _wave_breaches)
	if wave_number >= level.waves.size():
		phase = Phase.WON
		level_won.emit()
		return
	phase = Phase.BUILD
	build_remaining = Content.BUILD_SECONDS


func _wave_is_over() -> bool:
	return _elapsed >= level.waves[wave_number - 1].attack_seconds and units.is_empty() and _spawns.is_empty()


func _route_between(from_id: int, to_id: int) -> PackedInt64Array:
	var route_key := Vector2i(from_id, to_id)
	if not _routes.has(route_key):
		_routes[route_key] = graph.cable_route(from_id, to_id)
	return _routes[route_key]


func _points_of(route: PackedInt64Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for id in route:
		points.append(graph.position_of(id))
	return points


func _tick_deployments(delta: float) -> void:
	for placed in defenses:
		if not placed.is_active():
			placed.deploy_remaining -= delta
			if placed.is_active():
				_on_activated(placed)


func _on_activated(placed: Placed) -> void:
	if placed.data.slot == GameTypes.SlotType.LINK:
		graph.set_link_defended(placed.slot.a, placed.slot.b, true)


func _tick_spawns() -> void:
	for i in range(_spawns.size() - 1, -1, -1):
		var spawn := _spawns[i]
		while spawn["left"] > 0 and spawn["next"] <= _elapsed:
			var entry: LevelData.SpawnEntry = spawn["entry"]
			if entry.attack.path == GameTypes.PathType.SOCIAL:
				deliver_email()
			else:
				_spawn_on_cable(entry.attack, entry.entry_node, entry.target_node)
			spawn["left"] -= 1
			spawn["next"] += entry.interval
		if spawn["left"] == 0:
			_spawns.remove_at(i)


func _spawn_on_cable(attack: AttackData, from_id: int, to_id: int) -> void:
	var route := _route_between(from_id, to_id)
	if route.is_empty():
		push_error("No cable route from %d to %d" % [from_id, to_id])
		return
	units.append(Unit.new(attack, route, _points_of(route)))


func _tick_workstations(delta: float) -> void:
	for id: int in workstations:
		var workstation: Workstation = workstations[id]
		for i in workstation.tick(delta):
			_spawn_on_cable(Content.intruder(), id, _asset_id)
		if workstation.is_compromised:
			_tick_cleaning(id, workstation, delta)


func _tick_cleaning(id: int, workstation: Workstation, delta: float) -> void:
	var position := graph.position_of(id)
	for placed in defenses:
		var cleans := placed.is_active() and placed.data.clean_seconds > 0.0
		if cleans and placed.slot.position.distance_to(position) <= placed.data.range_px:
			_clean_progress[id] = _clean_progress.get(id, 0.0) + delta
			if _clean_progress[id] >= placed.data.clean_seconds:
				_clean_progress.erase(id)
				workstation.clean()
				workstation_cleaned.emit(id)
			return


func _tick_defenses(delta: float) -> void:
	for placed in defenses:
		if not placed.is_active() or placed.data.damage <= 0.0:
			continue
		placed.cooldown = maxf(0.0, placed.cooldown - delta)
		if placed.cooldown > 0.0:
			continue
		var target := _nearest_target(placed)
		if target != null:
			target.hp -= Combat.damage(placed.data.damage, placed.data.rating_against(target.attack.family))
			placed.cooldown = 1.0 / placed.data.shots_per_second
			defense_fired.emit(placed, target)


func _nearest_target(placed: Placed) -> Unit:
	var best: Unit = null
	var best_distance := placed.data.range_px
	for unit in units:
		if unit.hp <= 0.0 or placed.data.rating_against(unit.attack.family) == GameTypes.Rating.NONE:
			continue
		var distance := unit.position.distance_to(placed.slot.position)
		if distance <= best_distance:
			best = unit
			best_distance = distance
	return best


func _tick_units(delta: float) -> void:
	var index := 0
	while index < units.size():
		var unit := units[index]
		if unit.attack.path != GameTypes.PathType.SOCIAL and unit.hp <= 0.0:
			units.remove_at(index)
			economy.add_bounty(unit.attack.bounty)
			unit_killed.emit(unit.attack, unit.position)
			continue
		if _advance(unit, delta):
			units.remove_at(index)
			_on_arrived(unit)
			if phase == Phase.LOST:
				return
			continue
		index += 1


## Returns true when the unit reached the end of its route.
func _advance(unit: Unit, delta: float) -> bool:
	var distance := unit.attack.speed * delta
	while unit.next_point < unit.points.size():
		var target := unit.points[unit.next_point]
		var gap := unit.position.distance_to(target)
		if gap > distance:
			unit.position = unit.position.move_toward(target, distance)
			return false
		distance -= gap
		unit.position = target
		unit.next_point += 1
	return true


func _on_arrived(unit: Unit) -> void:
	if unit.target_workstation != -1:
		var workstation: Workstation = workstations[unit.target_workstation]
		if not workstation.is_compromised and not _filter_catches(unit.target_workstation):
			workstation.compromise()
			compromise_count += 1
			workstation_compromised.emit(unit.target_workstation)
		return
	_breach(unit)


func _breach(unit: Unit) -> void:
	_wave_breaches += 1
	_last_breach = unit
	if unit.attack.encrypts:
		var backups := _active_backups()
		var fraction := backups.data.restore_fraction if backups != null else 0.0
		var delay := backups.data.restore_delay if backups != null else 0.0
		integrity.apply_ransomware(unit.attack.breach_damage, fraction, delay)
	else:
		integrity.apply_breach(unit.attack.breach_damage)
	unit_breached.emit(unit.attack)
	if integrity.is_depleted():
		phase = Phase.LOST
		report_raised.emit(_report(unit, true))
		level_lost.emit()
	elif not _reported.has(unit.attack):
		_reported[unit.attack] = true
		report_raised.emit(_report(unit, false))


func _report(unit: Unit, is_loss: bool) -> Dictionary:
	var hops := PackedStringArray()
	for id in unit.route:
		hops.append(level.node_def(id).label)
	return {
		"is_loss": is_loss,
		"attack": unit.attack.display_name,
		"family": unit.attack.family,
		"path": " > ".join(hops),
		"counter": unit.attack.counter_text,
		"lesson": unit.attack.lesson_text,
	}


func _filter_catches(node_id: int) -> bool:
	for placed in defenses:
		if placed.is_active() and placed.data.catch_chance > 0.0 and placed.slot.a == node_id:
			if PhishingRules.is_caught(_rng, placed.data.catch_chance):
				economy.add_bounty(Content.phishing().bounty)
				email_caught.emit(node_id)
				return true
	return false


func _active_backups() -> Placed:
	for placed in defenses:
		if placed.is_active() and placed.data.restore_fraction > 0.0:
			return placed
	return null
