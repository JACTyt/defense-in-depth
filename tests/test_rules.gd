extends GutTest


func test_strong_is_full_damage() -> void:
	assert_eq(Combat.damage(10.0, GameTypes.Rating.STRONG), 10.0)


func test_weak_is_reduced() -> void:
	assert_almost_eq(Combat.damage(10.0, GameTypes.Rating.WEAK), 3.5, 0.001)


func test_none_is_zero() -> void:
	assert_eq(Combat.damage(10.0, GameTypes.Rating.NONE), 0.0)


func test_license_upkeep_escalates() -> void:
	var e := Economy.new(1000, 100)
	for i in 3:
		e.buy(Content.firewall())
	assert_eq(e.upkeep_due(), 30)  # 5 + 10 + 15


func test_mixed_types_each_pay_first_copy_rate() -> void:
	var e := Economy.new(1000, 100)
	e.buy(Content.firewall())
	e.buy(Content.edr())
	assert_eq(e.upkeep_due(), 15)


func test_buy_fails_without_funds() -> void:
	var e := Economy.new(50, 100)
	assert_false(e.buy(Content.firewall()))
	assert_eq(e.budget, 50)
	assert_eq(e.upkeep_due(), 0)


func test_upkeep_can_make_budget_negative_and_blocks_buying() -> void:
	var e := Economy.new(100, 100)
	e.buy(Content.firewall())
	e.start_wave()
	assert_eq(e.budget, -5)
	assert_false(e.can_afford(1))


func test_income_only_after_waves_three_and_six() -> void:
	var e := Economy.new(0, 100)
	for wave in range(1, 9):
		e.end_wave(wave)
	assert_eq(e.budget, 200)


func test_sell_refunds_half_and_drops_upkeep() -> void:
	var e := Economy.new(100, 100)
	e.buy(Content.firewall())
	e.sell(Content.firewall())
	assert_eq(e.budget, 50)
	assert_eq(e.upkeep_due(), 0)


func test_breach_reduces_integrity() -> void:
	var t := IntegrityTracker.new()
	t.apply_breach(30.0)
	assert_eq(t.integrity, 70.0)


func test_restore_arrives_after_delay() -> void:
	var t := IntegrityTracker.new()
	t.apply_ransomware(40.0, 0.75, 10.0)
	t.tick(9.9)
	assert_eq(t.integrity, 60.0)
	t.tick(0.2)
	assert_eq(t.integrity, 90.0)


func test_restore_is_clamped_to_maximum() -> void:
	var t := IntegrityTracker.new()
	t.apply_ransomware(40.0, 2.0, 1.0)
	t.tick(2.0)
	assert_eq(t.integrity, 100.0)


func test_depletion_is_final_while_restore_pending() -> void:
	var t := IntegrityTracker.new()
	t.apply_breach(70.0)
	t.apply_ransomware(40.0, 0.75, 10.0)
	assert_true(t.is_depleted())
	t.tick(11.0)
	assert_true(t.is_depleted())
	assert_eq(t.integrity, 0.0)


func test_catch_rate_is_about_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var caught := 0
	for i in 1000:
		if PhishingRules.is_caught(rng, 0.6):
			caught += 1
	assert_between(caught, 550, 650)


func test_same_seed_gives_same_rolls() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	for i in 20:
		assert_eq(PhishingRules.is_caught(a, 0.6), PhishingRules.is_caught(b, 0.6))


func test_no_uncompromised_target_returns_minus_one() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(PhishingRules.pick_target(rng, []), -1)


func test_workstation_waits_then_spawns_on_schedule() -> void:
	var w := Workstation.new()
	w.compromise()
	assert_eq(w.tick(2.9), 0)
	assert_eq(w.tick(0.2), 1)
	assert_eq(w.tick(7.7), 0)
	assert_eq(w.tick(0.4), 1)


func test_workstation_caps_at_four_per_wave() -> void:
	var w := Workstation.new()
	w.compromise()
	var total := 0
	for i in 100:
		total += w.tick(1.0)
	assert_eq(total, 4)


func test_clean_stops_spawning() -> void:
	var w := Workstation.new()
	w.compromise()
	w.clean()
	assert_false(w.is_compromised)
	assert_eq(w.tick(100.0), 0)


func test_reset_for_wave_clears_compromise() -> void:
	var w := Workstation.new()
	w.compromise()
	w.reset_for_wave()
	assert_false(w.is_compromised)
	assert_eq(w.tick(100.0), 0)


func _count(level: LevelData, attack: AttackData) -> int:
	var total := 0
	for wave: LevelData.WaveData in level.waves:
		for entry: LevelData.SpawnEntry in wave.entries:
			if entry.attack == attack:
				total += entry.count
	return total


func test_wave_totals_match_balance_sheet() -> void:
	assert_eq(_count(Content.level(0), Content.scanner()), 66)
	assert_eq(_count(Content.level(1), Content.scanner()), 46)
	assert_eq(_count(Content.level(1), Content.phishing()), 18)
	assert_eq(_count(Content.level(2), Content.scanner()), 68)
	assert_eq(_count(Content.level(2), Content.phishing()), 16)
	assert_eq(_count(Content.level(2), Content.ransomware()), 9)


func test_every_cable_spawn_has_a_route() -> void:
	for i in Content.LEVEL_COUNT:
		var level := Content.level(i)
		var graph := level.build_graph()
		for wave: LevelData.WaveData in level.waves:
			for entry: LevelData.SpawnEntry in wave.entries:
				if entry.attack.path == GameTypes.PathType.CABLE:
					assert_gt(graph.cable_route(entry.entry_node, entry.target_node).size(), 0)
