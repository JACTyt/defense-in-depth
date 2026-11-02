extends GutTest
## Workstation filters, saved progress, the ten story levels and generated levels.

const STEP := 1.0 / 30.0
const TEST_SAVE := "user://test_progress_rules.json"


func before_each() -> void:
	DirAccess.remove_absolute(TEST_SAVE)


func after_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)


func test_email_filter_fits_mail_server_and_every_workstation() -> void:
	var sim := LevelSim.new(Content.level(1))
	assert_eq(sim.slots_for(Content.email_filter()).size(), 7)


func test_workstation_filter_catches_only_its_own_emails() -> void:
	var sim := LevelSim.new(Content.level(1))
	var slots := sim.slots_for(Content.email_filter())
	var guarded: int = slots[1].a
	sim.economy.add_bounty(1000)
	sim.place(Content.email_filter(), slots[1])
	var caught_at: Array[int] = []
	sim.email_caught.connect(func(id: int) -> void: caught_at.append(id))
	sim.start_wave_now()
	for i in 200:
		sim.deliver_email()
		for t in 300:
			sim.tick(STEP)
			if sim.units.is_empty():
				break
		for id: int in sim.workstations:
			sim.workstations[id].reset_for_wave()
		sim.integrity = IntegrityTracker.new()
	assert_gt(caught_at.size(), 0)
	for id in caught_at:
		assert_eq(id, guarded)


func test_progress_starts_with_only_level_one_open() -> void:
	var p := Progress.new(TEST_SAVE)
	assert_true(p.is_unlocked(0))
	assert_false(p.is_unlocked(1))
	assert_eq(p.best(0), -1)


func test_finishing_a_level_unlocks_the_next() -> void:
	var p := Progress.new(TEST_SAVE)
	p.record_level(0, 70.0)
	assert_true(p.is_unlocked(1))
	assert_false(p.is_unlocked(2))


func test_progress_keeps_the_best_integrity() -> void:
	var p := Progress.new(TEST_SAVE)
	p.record_level(0, 90.0)
	p.record_level(0, 50.0)
	assert_eq(p.best(0), 90)


func test_progress_survives_a_reload() -> void:
	var p := Progress.new(TEST_SAVE)
	p.record_level(2, 100.0)
	p.record_infinite(4)
	var again := Progress.new(TEST_SAVE)
	assert_eq(again.best(2), 100)
	assert_eq(again.infinite_best(), 4)


func test_damaged_save_starts_fresh() -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_eq(Progress.new(TEST_SAVE).best(0), -1)


func test_there_are_ten_story_levels() -> void:
	assert_eq(Content.LEVEL_COUNT, 10)


func test_every_level_is_well_formed() -> void:
	for i in Content.LEVEL_COUNT:
		_assert_well_formed(Content.level(i))


func test_generated_levels_are_well_formed() -> void:
	for level_seed in 25:
		_assert_well_formed(LevelGenerator.generate(level_seed, 1 + level_seed % 8))


func test_generation_repeats_for_the_same_seed() -> void:
	var a := LevelGenerator.generate(7, 3)
	var b := LevelGenerator.generate(7, 3)
	assert_eq(a.nodes.size(), b.nodes.size())
	assert_eq(a.waves.size(), b.waves.size())
	assert_eq(a.nodes[-1].position, b.nodes[-1].position)


func test_generation_varies_between_seeds() -> void:
	var shapes := {}
	for level_seed in 25:
		shapes[LevelGenerator.generate(level_seed, 3).nodes.size()] = true
	assert_gt(shapes.size(), 2)


func test_generated_levels_get_harder() -> void:
	assert_gt(_threat(LevelGenerator.generate(5, 8)), _threat(LevelGenerator.generate(5, 1)))


func _threat(level: LevelData) -> int:
	var total := 0
	for wave in level.waves:
		for entry in wave.entries:
			total += entry.count * maxi(1, roundi(entry.attack.breach_damage))
	return total


func _assert_well_formed(level: LevelData) -> void:
	var graph := level.build_graph()
	var ids := {}
	var asset := -1
	var mail := -1
	for node in level.nodes:
		assert_false(ids.has(node.id), "%s: duplicate node id" % level.display_name)
		ids[node.id] = true
		assert_between(node.position.x, 40.0, 1200.0, "%s: x off the map" % node.label)
		assert_between(node.position.y, 30.0, 690.0, "%s: y off the map" % node.label)
		if node.kind == GameTypes.NodeKind.ASSET:
			asset = node.id
		if node.kind == GameTypes.NodeKind.MAIL_SERVER:
			mail = node.id
	assert_ne(asset, -1, "%s has no database" % level.display_name)
	for node in level.nodes:
		if node.kind == GameTypes.NodeKind.WORKSTATION:
			assert_gt(graph.cable_route(node.id, asset).size(), 0, "%s: workstation cut off" % level.display_name)
			assert_gt(graph.social_route(mail, node.id).size(), 0, "%s: no mail route" % level.display_name)
	for wave in level.waves:
		for entry in wave.entries:
			if entry.attack.path == GameTypes.PathType.CABLE:
				assert_gt(graph.cable_route(entry.entry_node, entry.target_node).size(), 0)
