extends GutTest
## Drives the real main scene through its public flow. Visuals are checked by hand.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.progress = Progress.new("user://test_progress_main.json")
	add_child_autofree(main)
	main.start_story(0)


func _first_slot(data: DefenseData) -> LevelSim.Slot:
	return main.sim.slots_for(data)[0]


func test_starts_on_level_one_with_briefing_open() -> void:
	assert_eq(main.level_index, 0)
	assert_true(main.is_modal_open())


func test_time_stops_while_modal_is_open() -> void:
	main.step(5.0)
	assert_eq(main.sim.build_remaining, Content.BUILD_SECONDS)


func test_pause_stops_time_but_allows_placing() -> void:
	main.close_modal()
	main.set_paused(true)
	main.select_defense(Content.firewall())
	var slot := _first_slot(Content.firewall())
	main.click_at(slot.position)
	assert_eq(main.sim.defenses.size(), 1)
	main.step(5.0)
	assert_eq(main.sim.build_remaining, Content.BUILD_SECONDS)


func test_speed_starts_at_normal() -> void:
	assert_eq(main.speed, 1)


func test_speed_multiplies_game_time() -> void:
	main.close_modal()
	main.set_speed(8)
	main.step(1.0)
	assert_almost_eq(main.sim.build_remaining, Content.BUILD_SECONDS - 8.0, 0.05)


func test_speed_buttons_offer_each_choice() -> void:
	assert_eq(main.speed_choices(), [1, 2, 4, 8])


func test_speed_is_kept_after_retry() -> void:
	main.set_speed(4)
	main.retry_level()
	assert_eq(main.speed, 4)


func test_report_stops_time_within_a_fast_step() -> void:
	main.close_modal()
	main.set_speed(8)
	main.sim.start_wave_now()
	var guard := 0
	while not main.is_modal_open() and guard < 1000:
		main.step(0.1)
		guard += 1
	var position: Vector2 = main.sim.units[0].position if not main.sim.units.is_empty() else Vector2.ZERO
	main.step(0.1)
	var after: Vector2 = main.sim.units[0].position if not main.sim.units.is_empty() else Vector2.ZERO
	assert_true(main.is_modal_open())
	assert_eq(after, position)


## Plays level 2 at a speed with one frame size, closing reports, until the level ends.
func _play_level_two(game_speed: int, frame: float) -> Array:
	main.next_level()
	while main.level_index != 1:
		main.next_level()
	main.close_modal()
	main.set_speed(game_speed)
	main.select_defense(Content.firewall())
	main.click_at(main.sim.slots_for(Content.firewall())[2].position)
	var guard := 0
	while main.sim.phase < LevelSim.Phase.WON and guard < 200000:
		main.step(frame)
		if main.is_modal_open() and main.sim.phase < LevelSim.Phase.WON:
			main.close_modal()
		guard += 1
	return [main.sim.phase, main.sim.wave_number, main.sim.integrity.integrity, main.sim.economy.budget, main.sim.compromise_count]


func test_outcome_is_identical_at_every_speed() -> void:
	var normal := _play_level_two(1, 1.0 / 60.0)
	assert_eq(_play_level_two(2, 1.0 / 60.0), normal)
	assert_eq(_play_level_two(4, 1.0 / 60.0), normal)
	assert_eq(_play_level_two(8, 1.0 / 60.0), normal)


func test_outcome_does_not_depend_on_frame_rate() -> void:
	var smooth := _play_level_two(8, 1.0 / 60.0)
	assert_eq(_play_level_two(8, 0.1), smooth)


func test_right_click_sells_a_placed_defense() -> void:
	main.close_modal()
	main.select_defense(Content.firewall())
	var slot := _first_slot(Content.firewall())
	main.click_at(slot.position)
	main.right_click_at(slot.position)
	assert_eq(main.sim.defenses.size(), 0)


func test_first_breach_opens_a_report_that_pauses_time() -> void:
	main.close_modal()
	main.sim.start_wave_now()
	while not main.is_modal_open():
		main.step(0.1)
	assert_string_contains(main.modal_text(), "Port scanner bots")
	var integrity: float = main.sim.integrity.integrity
	main.step(60.0)
	assert_eq(main.sim.integrity.integrity, integrity)


func test_retry_after_loss_gives_a_fresh_attempt() -> void:
	main.close_modal()
	main.select_defense(Content.firewall())
	main.click_at(_first_slot(Content.firewall()).position)
	main.sim.defenses.clear()
	main.sim.integrity.apply_breach(100.0)
	main.retry_level()
	assert_eq(main.sim.defenses.size(), 0)
	assert_eq(main.sim.economy.budget, 250)
	assert_eq(main.level_index, 0)


func test_winning_advances_to_the_next_level() -> void:
	main.close_modal()
	main.next_level()
	assert_eq(main.level_index, 1)
	assert_true(main.is_modal_open())


func test_shop_lists_only_level_defenses() -> void:
	assert_eq(main.shop_button_count(), 1)
	main.close_modal()
	main.next_level()
	assert_eq(main.shop_button_count(), 2)
