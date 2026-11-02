extends GutTest
## Plays every story level with scripted builds, to keep the difficulty curve from drifting.

const STEP := 1.0 / 30.0


func _into_core(sim: LevelSim, slot: LevelSim.Slot) -> bool:
	for node in sim.level.nodes:
		if node.label == "Core switch" and (slot.a == node.id or slot.b == node.id):
			return true
	return false


func _firewall_slots(sim: LevelSim) -> Array:
	var near_core: Array = []
	var others: Array = []
	for slot in sim.slots_for(Content.firewall()):
		if _into_core(sim, slot):
			near_core.append(slot)
		else:
			others.append(slot)
	return near_core + others


## Core switch first, then devices along the route attackers take.
func _edr_slots(sim: LevelSim) -> Array:
	var database := -1
	for node in sim.level.nodes:
		if node.kind == GameTypes.NodeKind.ASSET:
			database = node.id
	var route := sim.graph.cable_route(0, database)
	var slots := sim.slots_for(Content.edr())
	var ordered: Array = []
	for i in range(route.size() - 1, -1, -1):
		for slot in slots:
			if slot.a == route[i]:
				ordered.append(slot)
	for slot in slots:
		if not ordered.has(slot):
			ordered.append(slot)
	return ordered


func _firewalls_only(sim: LevelSim) -> Array:
	var queue: Array = []
	for slot in _firewall_slots(sim):
		queue.append([Content.firewall(), slot])
	return queue


## Firewalls by the core, a mail filter, EDR along the route, Backups, then everything else.
func _everything(sim: LevelSim) -> Array:
	var queue: Array = []
	var firewalls := _firewall_slots(sim)
	var routes := 0
	for slot in firewalls:
		if _into_core(sim, slot):
			routes += 1
	for i in routes:
		queue.append([Content.firewall(), firewalls[i]])
	var allowed := sim.level.allowed_defenses
	if allowed.has(Content.email_filter()):
		queue.append([Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	if allowed.has(Content.edr()):
		for slot in _edr_slots(sim):
			queue.append([Content.edr(), slot])
		queue.append([Content.backups(), sim.slots_for(Content.backups())[0]])
	for i in range(routes, firewalls.size()):
		queue.append([Content.firewall(), firewalls[i]])
	if allowed.has(Content.email_filter()):
		var mailboxes := sim.slots_for(Content.email_filter())
		for i in range(1, mailboxes.size()):
			queue.append([Content.email_filter(), mailboxes[i]])
	return queue


func _play(level: LevelData, build: Callable) -> LevelSim:
	var sim := LevelSim.new(level)
	var queue: Array = build.call(sim)
	var guard := 0
	while sim.phase != LevelSim.Phase.WON and sim.phase != LevelSim.Phase.LOST and guard < 300000:
		if not queue.is_empty() and sim.economy.can_afford(queue[0][0].cost):
			var item: Array = queue.pop_front()
			sim.place(item[0], item[1])
		sim.tick(STEP)
		guard += 1
	return sim


func test_firewalls_alone_lose_from_level_two_on() -> void:
	for i in range(1, Content.LEVEL_COUNT):
		assert_eq(_play(Content.level(i), _firewalls_only).phase, LevelSim.Phase.LOST, Content.level(i).display_name)


func test_a_full_build_wins_every_story_level() -> void:
	for i in Content.LEVEL_COUNT:
		var sim := _play(Content.level(i), _everything)
		gut.p("%s: integrity %d" % [sim.level.display_name, roundi(sim.integrity.integrity)])
		assert_eq(sim.phase, LevelSim.Phase.WON, sim.level.display_name)


func test_first_two_levels_can_be_finished_at_100() -> void:
	assert_eq(_play(Content.level(0), _everything).integrity.integrity, 100.0)
	assert_eq(_play(Content.level(1), _everything).integrity.integrity, 100.0)


func test_early_infinite_levels_are_winnable() -> void:
	for level_seed in [11, 22, 33]:
		assert_eq(_play(LevelGenerator.generate(level_seed, 1), _everything).phase, LevelSim.Phase.WON)


func test_deep_infinite_levels_beat_even_a_full_build() -> void:
	for level_seed in [11, 22, 33]:
		assert_eq(_play(LevelGenerator.generate(level_seed, 30), _everything).phase, LevelSim.Phase.LOST)
