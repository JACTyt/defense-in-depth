extends GutTest
## Main menu, level select, and moving between story and infinite play.

const TEST_SAVE := "user://test_progress_menu.json"

var main: Node


func before_each() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	main = load("res://scenes/main.tscn").instantiate()
	main.progress = Progress.new(TEST_SAVE)
	add_child_autofree(main)


func after_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)


func test_game_opens_on_the_menu() -> void:
	assert_true(main.is_menu_open())


func test_time_stops_on_the_menu() -> void:
	var before: float = main.sim.build_remaining
	main.step(5.0)
	assert_eq(main.sim.build_remaining, before)


func test_level_select_shows_all_ten_with_only_first_open() -> void:
	assert_eq(main.story_card_count(), 10)
	assert_false(main.story_card_disabled(0))
	assert_true(main.story_card_disabled(1))


func test_starting_story_closes_the_menu_on_that_level() -> void:
	main.start_story(0)
	assert_false(main.is_menu_open())
	assert_eq(main.level_index, 0)
	assert_true(main.is_modal_open())


func test_winning_saves_the_result_and_unlocks_the_next_card() -> void:
	main.start_story(0)
	main.close_modal()
	main.sim.level_won.emit()
	assert_eq(main.progress.best(0), 100)
	assert_false(main.story_card_disabled(1))


func test_perfect_win_says_so() -> void:
	main.start_story(0)
	main.close_modal()
	main.sim.level_won.emit()
	assert_string_contains(main.modal_text(), "Perfect")


func test_imperfect_win_offers_a_replay() -> void:
	main.start_story(0)
	main.close_modal()
	main.sim.integrity.apply_breach(10.0)
	main.sim.level_won.emit()
	assert_string_contains(main.modal_text(), "90")
	assert_true(main.modal_choices().has("Replay level"))


func test_finishing_level_ten_offers_infinite_play() -> void:
	main.start_story(9)
	main.close_modal()
	main.sim.level_won.emit()
	assert_true(main.modal_choices().has("Start infinite play"))
	assert_true(main.modal_choices().has("Main menu"))


func test_infinite_play_starts_at_level_one_on_a_generated_map() -> void:
	main.start_infinite()
	assert_false(main.is_menu_open())
	assert_true(main.is_infinite())
	assert_eq(main.infinite_depth(), 1)


func test_clearing_an_infinite_level_moves_deeper_and_saves() -> void:
	main.start_infinite()
	main.close_modal()
	main.sim.level_won.emit()
	assert_eq(main.progress.infinite_best(), 1)
	main.next_level()
	assert_eq(main.infinite_depth(), 2)
	assert_true(main.is_infinite())


func test_losing_in_infinite_offers_a_new_run() -> void:
	main.start_infinite()
	main.close_modal()
	main.sim.report_raised.emit({"is_loss": true, "attack": "Intruder", "family": GameTypes.Family.MALWARE, "path": "x", "counter": "y", "lesson": "z"})
	assert_true(main.modal_choices().has("Start a new run"))


func test_top_bar_fits_with_the_longest_level_name() -> void:
	main.start_story(9)
	main.close_modal()
	assert_lte(main.top_bar_width(), 1280.0)


func test_node_labels_are_unique_except_workstations() -> void:
	for i in Content.LEVEL_COUNT:
		var seen := {}
		for node in Content.level(i).nodes:
			if node.kind != GameTypes.NodeKind.WORKSTATION:
				assert_false(seen.has(node.label), "%s repeats %s" % [Content.level(i).display_name, node.label])
				seen[node.label] = true


func test_workstations_do_not_cover_their_office_label() -> void:
	var level := Content.level(9)
	for node in level.nodes:
		if node.label.begins_with("Office"):
			var label_center := node.position + Vector2(0, 41)
			for other in level.nodes:
				if other.kind == GameTypes.NodeKind.WORKSTATION:
					assert_gt(other.position.distance_to(label_center), 30.0, node.label)


func test_menu_button_returns_to_the_menu() -> void:
	main.start_story(0)
	main.close_modal()
	main.open_menu()
	assert_true(main.is_menu_open())
	assert_false(main.is_modal_open())
