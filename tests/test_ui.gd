extends GutTest
## Checks the UI's real content. Its look is checked by screenshot.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.progress = Progress.new("user://test_progress_ui.json")
	add_child_autofree(main)
	main.start_story(0)


func test_bundled_fonts_load() -> void:
	assert_not_null(UiTheme.body_font())
	assert_not_null(UiTheme.data_font())
	assert_ne(UiTheme.body_font().get_font_name(), "")


func test_window_edge_panels_are_flush() -> void:
	var style := UiTheme.flush(UiTheme.PANEL)
	assert_eq(style.corner_radius_top_left, 0)
	assert_eq(style.corner_radius_bottom_right, 0)
	assert_eq(style.bg_color, UiTheme.PANEL)


func test_floating_elements_keep_their_chamfer() -> void:
	assert_eq(UiTheme.box(UiTheme.PANEL).corner_radius_top_left, UiTheme.CHAMFER)


func test_theme_replaces_default_buttons() -> void:
	var theme := UiTheme.build()
	assert_true(theme.has_stylebox("normal", "Button"))
	assert_true(theme.has_stylebox("hover", "Button"))
	assert_eq(theme.default_font, UiTheme.body_font())


func test_shop_card_shows_price_and_upkeep() -> void:
	var text: String = main.shop_card_text(0)
	assert_string_contains(text, "Firewall")
	assert_string_contains(text, "$100")
	assert_string_contains(text, "$5")


func test_shop_hotkey_selects_a_defense() -> void:
	main.close_modal()
	main.select_shop_index(0)
	assert_eq(main.selected_defense(), Content.firewall())
	main.select_shop_index(0)
	assert_null(main.selected_defense())


func test_out_of_range_shop_hotkey_is_ignored() -> void:
	main.close_modal()
	main.select_shop_index(3)
	assert_null(main.selected_defense())


func test_selecting_email_filter_says_where_it_goes() -> void:
	main.close_modal()
	main.select_defense(Content.email_filter())
	assert_string_contains(main.toast_text(), "mail server")


func test_selecting_each_defense_gives_a_placement_hint() -> void:
	main.close_modal()
	for data in Content.level(2).allowed_defenses:
		main.select_defense(data)
		assert_string_contains(main.toast_text(), "Click")


func test_clicking_an_occupied_slot_explains_why_nothing_happened() -> void:
	main.close_modal()
	main.next_level()
	main.close_modal()
	main.select_defense(Content.email_filter())
	var slot: LevelSim.Slot = main.sim.slots_for(Content.email_filter())[0]
	main.click_at(slot.position)
	main.click_at(slot.position)
	assert_eq(main.sim.defenses.size(), 1)
	assert_string_contains(main.toast_text(), "already has")


func test_game_targets_full_hd_fullscreen() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/mode"), DisplayServer.WINDOW_MODE_FULLSCREEN)
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_eq(1920 * height, 1080 * width, "the base layout must scale evenly to 1920x1080")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_map_stays_centered_on_taller_screens() -> void:
	var view: LevelView = main.get_view()
	assert_eq(view.centered_position(Vector2(1280, 720)), LevelView.MAP_OFFSET)
	assert_eq(view.centered_position(Vector2(1280, 800)), LevelView.MAP_OFFSET + Vector2(0, 40))


func test_intruder_advice_is_honest_about_when_edr_unlocks() -> void:
	assert_string_contains(Content.intruder().counter_text, "level 3")


func test_feed_records_a_wave_start() -> void:
	main.close_modal()
	main.sim.start_wave_now()
	assert_string_contains(main.feed_text(), "Wave 1")


func test_feed_is_capped() -> void:
	for i in 100:
		main.add_feed_line("line %d" % i, Color.WHITE)
	assert_lte(main.feed_line_count(), main.MAX_FEED_LINES)


func test_new_level_clears_the_feed() -> void:
	main.add_feed_line("old", Color.WHITE)
	main.retry_level()
	assert_eq(main.feed_line_count(), 0)


func test_integrity_color_warns_as_it_drops() -> void:
	assert_eq(UiTheme.integrity_color(100.0), UiTheme.GOOD)
	assert_eq(UiTheme.integrity_color(50.0), UiTheme.WARN)
	assert_eq(UiTheme.integrity_color(20.0), UiTheme.BAD)


func test_view_effects_are_capped_during_fast_play() -> void:
	var view: LevelView = main.get_view()
	for i in 500:
		view.add_float(Vector2.ZERO, "+$5", Color.WHITE)
	assert_lte(view.effect_count(), LevelView.MAX_EFFECTS)
