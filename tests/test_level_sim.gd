extends GutTest
## Plays whole levels headlessly to check rules and the balance sheet's tuning targets.

const STEP := 1.0 / 30.0


func _link_slot(sim: LevelSim, a: int, b: int) -> LevelSim.Slot:
	for slot in sim.slots_for(Content.firewall()):
		if (slot.a == a and slot.b == b) or (slot.a == b and slot.b == a):
			return slot
	return null


func _node_slot(sim: LevelSim, data: DefenseData, id: int) -> LevelSim.Slot:
	for slot in sim.slots_for(data):
		if slot.a == id:
			return slot
	return null


func _run_to_end(sim: LevelSim) -> void:
	var guard := 0
	while sim.phase != LevelSim.Phase.WON and sim.phase != LevelSim.Phase.LOST and guard < 200000:
		sim.tick(STEP)
		guard += 1


## Keeps buying the queued placements in order whenever the budget allows.
func _run_with_queue(sim: LevelSim, queue: Array) -> void:
	var guard := 0
	while sim.phase != LevelSim.Phase.WON and sim.phase != LevelSim.Phase.LOST and guard < 200000:
		if not queue.is_empty() and sim.economy.can_afford(queue[0][0].cost):
			var item: Array = queue.pop_front()
			sim.place(item[0], item[1])
		sim.tick(STEP)
		guard += 1


func _l2_firewalls(sim: LevelSim) -> Array:
	return [
		[Content.firewall(), _link_slot(sim, 2, 4)],
		[Content.firewall(), _link_slot(sim, 3, 4)],
		[Content.firewall(), _link_slot(sim, 1, 2)],
		[Content.firewall(), _link_slot(sim, 1, 3)],
	]


func _l3_firewalls(sim: LevelSim) -> Array:
	return [
		[Content.firewall(), _link_slot(sim, 2, 11)],
		[Content.firewall(), _link_slot(sim, 3, 12)],
		[Content.firewall(), _link_slot(sim, 4, 13)],
	]


func test_starts_in_build_phase_with_level_budget() -> void:
	var sim := LevelSim.new(Content.level(0))
	assert_eq(sim.phase, LevelSim.Phase.BUILD)
	assert_eq(sim.economy.budget, 250)


func test_build_timer_starts_the_wave() -> void:
	var sim := LevelSim.new(Content.level(0))
	for i in int(Content.BUILD_SECONDS / STEP) + 2:
		sim.tick(STEP)
	assert_eq(sim.phase, LevelSim.Phase.ATTACK)
	assert_eq(sim.wave_number, 1)


func test_start_wave_now_skips_the_timer() -> void:
	var sim := LevelSim.new(Content.level(0))
	sim.start_wave_now()
	assert_eq(sim.phase, LevelSim.Phase.ATTACK)


func test_firewall_only_fits_link_slots() -> void:
	var sim := LevelSim.new(Content.level(1))
	var mail_slot := sim.slots_for(Content.email_filter())[0]
	assert_false(sim.place(Content.firewall(), mail_slot))


func test_slot_holds_one_defense() -> void:
	var sim := LevelSim.new(Content.level(0))
	var slot := _link_slot(sim, 2, 4)
	assert_true(sim.place(Content.firewall(), slot))
	assert_false(sim.place(Content.firewall(), slot))


func test_level_rejects_defenses_it_does_not_allow() -> void:
	var sim := LevelSim.new(Content.level(0))
	assert_eq(sim.slots_for(Content.edr()).size(), 0)


func test_placing_during_build_is_active_immediately() -> void:
	var sim := LevelSim.new(Content.level(0))
	sim.place(Content.firewall(), _link_slot(sim, 2, 4))
	assert_true(sim.defenses[0].is_active())


func test_placing_during_wave_deploys_after_three_seconds() -> void:
	var sim := LevelSim.new(Content.level(0))
	sim.start_wave_now()
	sim.place(Content.firewall(), _link_slot(sim, 2, 4))
	sim.tick(2.9)
	assert_false(sim.defenses[0].is_active())
	sim.tick(0.2)
	assert_true(sim.defenses[0].is_active())


func test_defended_route_applies_only_at_next_wave() -> void:
	var sim := LevelSim.new(Content.level(0))
	sim.start_wave_now()
	sim.tick(STEP)
	var first_route: PackedInt64Array = sim.units[0].route
	sim.place(Content.firewall(), _link_slot(sim, first_route[1], first_route[2]))
	sim.tick(7.0)  # past deployment and the next spawn
	assert_gt(sim.units.size(), 1)
	assert_eq(sim.units[-1].route, first_route)


func test_scanners_avoid_a_firewalled_route_next_wave() -> void:
	var sim := LevelSim.new(Content.level(0))
	var baseline := LevelSim.new(Content.level(0))
	baseline.start_wave_now()
	baseline.tick(STEP)
	var natural: PackedInt64Array = baseline.units[0].route
	sim.place(Content.firewall(), _link_slot(sim, natural[1], natural[2]))
	sim.start_wave_now()
	sim.tick(STEP)
	assert_ne(sim.units[0].route, natural)


func test_firing_defense_reports_its_shot() -> void:
	var sim := LevelSim.new(Content.level(0))
	for slot in sim.slots_for(Content.firewall()):
		sim.economy.add_bounty(100)
		sim.place(Content.firewall(), slot)
	watch_signals(sim)
	sim.start_wave_now()
	for i in 300:
		sim.tick(STEP)
	assert_signal_emitted(sim, "defense_fired")


func test_kill_reports_where_the_unit_died() -> void:
	var sim := LevelSim.new(Content.level(0))
	for slot in sim.slots_for(Content.firewall()):
		sim.economy.add_bounty(100)
		sim.place(Content.firewall(), slot)
	var spots: Array[Vector2] = []
	sim.unit_killed.connect(func(_attack: AttackData, position: Vector2) -> void: spots.append(position))
	sim.start_wave_now()
	for i in 300:
		sim.tick(STEP)
	assert_gt(spots.size(), 0)
	assert_ne(spots[0], Vector2.ZERO)


func test_selling_refunds_and_removes_the_defense() -> void:
	var sim := LevelSim.new(Content.level(0))
	sim.place(Content.firewall(), _link_slot(sim, 2, 4))
	sim.sell(sim.defenses[0])
	assert_eq(sim.defenses.size(), 0)
	assert_eq(sim.economy.budget, 200)


func test_all_workstations_compromised_means_email_has_no_effect() -> void:
	var sim := LevelSim.new(Content.level(1))
	for id: int in sim.workstations:
		sim.workstations[id].compromise()
	sim.deliver_email()
	assert_eq(sim.units.size(), 0)
	assert_eq(sim.compromise_count, 0)


func test_first_breach_of_each_attack_reports_once() -> void:
	var sim := LevelSim.new(Content.level(0))
	watch_signals(sim)
	_run_to_end(sim)
	assert_signal_emit_count(sim, "report_raised", 2)  # first scanner breach and the loss


func test_same_seed_replays_identically() -> void:
	var a := LevelSim.new(Content.level(1))
	var b := LevelSim.new(Content.level(1))
	_run_with_queue(a, _l2_firewalls(a))
	_run_with_queue(b, _l2_firewalls(b))
	assert_eq(a.compromise_count, b.compromise_count)
	assert_eq(a.integrity.integrity, b.integrity.integrity)
	assert_eq(a.wave_number, b.wave_number)


func test_tuning_l1_no_defenses_loses() -> void:
	var sim := LevelSim.new(Content.level(0))
	_run_to_end(sim)
	assert_eq(sim.phase, LevelSim.Phase.LOST)


func test_tuning_l1_two_firewalls_wins() -> void:
	var sim := LevelSim.new(Content.level(0))
	_run_with_queue(sim, [
		[Content.firewall(), _link_slot(sim, 2, 4)],
		[Content.firewall(), _link_slot(sim, 3, 5)],
	])
	assert_eq(sim.phase, LevelSim.Phase.WON)


func test_tuning_l2_firewall_only_loses() -> void:
	var sim := LevelSim.new(Content.level(1))
	_run_with_queue(sim, _l2_firewalls(sim))
	gut.p("L2 firewall-only: wave %d integrity %.0f" % [sim.wave_number, sim.integrity.integrity])
	assert_eq(sim.phase, LevelSim.Phase.LOST)


func test_tuning_l2_firewall_and_filter_wins() -> void:
	var sim := LevelSim.new(Content.level(1))
	var queue := _l2_firewalls(sim)
	queue.insert(1, [Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	_run_with_queue(sim, queue)
	gut.p("L2 layered: integrity %.0f" % sim.integrity.integrity)
	assert_eq(sim.phase, LevelSim.Phase.WON)


func test_tuning_l2_firewalls_really_kill_intruders() -> void:
	var sim := LevelSim.new(Content.level(1))
	var kills := [0]
	sim.unit_killed.connect(func(attack: AttackData, _at: Vector2) -> void:
		if attack == Content.intruder():
			kills[0] += 1)
	var queue := _l2_firewalls(sim)
	queue.insert(1, [Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	_run_with_queue(sim, queue)
	gut.p("L2 intruders killed by firewalls: %d" % kills[0])
	assert_gt(kills[0], 3)


func test_tuning_l3_no_backups_no_edr_loses() -> void:
	var sim := LevelSim.new(Content.level(2))
	var queue := _l3_firewalls(sim)
	queue.append([Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	_run_with_queue(sim, queue)
	assert_eq(sim.phase, LevelSim.Phase.LOST)


func test_tuning_l3_backups_only_loses() -> void:
	var sim := LevelSim.new(Content.level(2))
	var queue := _l3_firewalls(sim)
	queue.append([Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	queue.append([Content.backups(), sim.slots_for(Content.backups())[0]])
	_run_with_queue(sim, queue)
	gut.p("L3 backups-only: wave %d integrity %.0f" % [sim.wave_number, sim.integrity.integrity])
	assert_eq(sim.phase, LevelSim.Phase.LOST)


func test_tuning_l3_edr_only_loses() -> void:
	var sim := LevelSim.new(Content.level(2))
	var queue := _l3_firewalls(sim)
	queue.append([Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	queue.append([Content.edr(), _node_slot(sim, Content.edr(), 5)])
	queue.append([Content.edr(), _node_slot(sim, Content.edr(), 12)])
	_run_with_queue(sim, queue)
	gut.p("L3 EDR-only: wave %d integrity %.0f" % [sim.wave_number, sim.integrity.integrity])
	assert_eq(sim.phase, LevelSim.Phase.LOST)


func test_tuning_l3_edr_and_backups_wins() -> void:
	var sim := LevelSim.new(Content.level(2))
	var queue := _l3_firewalls(sim)
	queue.append([Content.email_filter(), sim.slots_for(Content.email_filter())[0]])
	queue.append([Content.edr(), _node_slot(sim, Content.edr(), 5)])
	queue.append([Content.edr(), _node_slot(sim, Content.edr(), 12)])
	queue.append([Content.backups(), sim.slots_for(Content.backups())[0]])
	_run_with_queue(sim, queue)
	gut.p("L3 layered: wave %d integrity %.0f" % [sim.wave_number, sim.integrity.integrity])
	assert_eq(sim.phase, LevelSim.Phase.WON)
