extends Node
## Game flow and UI for all levels. Rules live in LevelSim; LevelView draws the map.

const MAX_STEP := 0.1
const TOAST_SECONDS := 3.0
const SIM_STEP := 1.0 / 30.0  # fixed, so outcomes don't depend on speed or frame rate
const SPEEDS: Array[int] = [1, 2, 4, 8]
const SHOP_KEYS: Array[String] = ["Q", "W", "E", "R"]
const MAX_FEED_LINES := 40
const TOP_HEIGHT := 72
const BOTTOM_HEIGHT := 100
const FEED_WIDTH := 240

var sim: LevelSim
var level_index := 0
var speed := 1
var progress: Progress

var _infinite := false
var _infinite_seed := 0
var _infinite_depth := 1
var _menu: Control
var _story_cards: Array[Button] = []
var _continue_button: Button
var _infinite_button: Button
var _modal_extras: HBoxContainer
var _top_row: HBoxContainer

var _view: LevelView
var _sfx: Sfx
var _level_title: Label
var _level_name: Label
var _wave_label: Label
var _wave_pips: HBoxContainer
var _budget: Label
var _upkeep: Label
var _integrity: Label
var _integrity_bar: ProgressBar
var _integrity_fill: StyleBoxFlat
var _toast: PanelContainer
var _toast_label: Label
var _fps: Label
var _shop: HBoxContainer
var _start_button: Button
var _pause_button: Button
var _speed_buttons: Dictionary = {}  # speed -> Button
var _accumulator := 0.0
var _feed: RichTextLabel
var _feed_lines: PackedStringArray = []
var _legend: VBoxContainer
var _modal: Control
var _modal_stripe: ColorRect
var _modal_label: RichTextLabel
var _modal_button: Button
var _modal_action: Callable
var _pending_reports: Array[Dictionary] = []
var _selected: DefenseData = null
var _paused := false
var _toast_remaining := 0.0


func _ready() -> void:
	if progress == null:
		progress = Progress.new("user://progress.json")
	_build_ui()
	_load_level(0, false)
	open_menu()


func is_menu_open() -> bool:
	return _menu.visible


func open_menu() -> void:
	_modal.visible = false
	_pending_reports.clear()
	_refresh_menu()
	_menu.visible = true


func start_story(index: int) -> void:
	_menu.visible = false
	_load_level(index)


func start_infinite() -> void:
	_menu.visible = false
	_infinite_seed = randi()
	_load_infinite(1)


func is_infinite() -> bool:
	return _infinite


func infinite_depth() -> int:
	return _infinite_depth


func story_card_count() -> int:
	return _story_cards.size()


func story_card_disabled(index: int) -> bool:
	return _story_cards[index].disabled


func top_bar_width() -> float:
	return _top_row.get_combined_minimum_size().x + 20.0


func modal_choices() -> PackedStringArray:
	var choices := PackedStringArray([_modal_button.text])
	for button: Button in _modal_extras.get_children():
		choices.append(button.text)
	return choices


func _process(delta: float) -> void:
	step(minf(delta, MAX_STEP))
	_toast_remaining -= delta
	_toast.visible = _toast_remaining > 0.0
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if is_modal_open() or is_menu_open():
		return
	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = _view.get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			click_at(point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_click_at(point)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_paused(not _paused)
			KEY_ESCAPE:
				select_defense(null)
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_speed(SPEEDS[event.keycode - KEY_1])
			KEY_Q:
				select_shop_index(0)
			KEY_W:
				select_shop_index(1)
			KEY_E:
				select_shop_index(2)
			KEY_R:
				select_shop_index(3)
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F3:
				_fps.visible = not _fps.visible
			KEY_F9:
				get_tree().change_scene_to_file("res://scenes/stress.tscn")


func step(delta: float) -> void:
	if _paused or is_modal_open() or is_menu_open():
		return
	_accumulator += delta * speed
	while _accumulator >= SIM_STEP and not is_modal_open():
		sim.tick(SIM_STEP)
		_accumulator -= SIM_STEP


func set_speed(value: int) -> void:
	speed = value
	for choice: int in _speed_buttons:
		_speed_buttons[choice].button_pressed = choice == value


func speed_choices() -> Array[int]:
	return SPEEDS


func is_modal_open() -> bool:
	return _modal.visible


func modal_text() -> String:
	return _modal_label.get_parsed_text()


func close_modal() -> void:
	_modal.visible = false
	if not _pending_reports.is_empty():
		_show_report(_pending_reports.pop_front())


func set_paused(paused: bool) -> void:
	_paused = paused
	_pause_button.text = "Resume" if paused else "Pause"


func selected_defense() -> DefenseData:
	return _selected


func select_defense(data: DefenseData) -> void:
	_selected = data
	_view.selected = data
	for button: Button in _shop.get_children():
		button.button_pressed = button.get_meta("defense") == data
	if data != null:
		_show_toast(_placement_hint(data), UiTheme.CABLE)


func toast_text() -> String:
	return _toast_label.text


func _placement_hint(data: DefenseData) -> String:
	match data.slot:
		GameTypes.SlotType.LINK:
			return "Click a green slot on a cable to place %s." % data.display_name
		GameTypes.SlotType.MAILBOX:
			return "Click the mail server or a workstation to install %s." % data.display_name
		GameTypes.SlotType.ASSET:
			return "Click the database to install %s." % data.display_name
	return "Click a green device to place %s." % data.display_name


func select_shop_index(index: int) -> void:
	if index >= sim.level.allowed_defenses.size():
		return
	var data := sim.level.allowed_defenses[index]
	_sfx.play(Sfx.Sound.CLICK)
	select_defense(null if _selected == data else data)


func click_at(point: Vector2) -> void:
	if _selected == null:
		return
	var slot := _view.slot_at(_selected, point)
	if slot == null:
		return
	if sim.is_occupied(slot):
		_show_toast("This spot already has a defense. Right-click it to sell it.", UiTheme.WARN)
		return
	if sim.place(_selected, slot):
		_sfx.play(Sfx.Sound.PLACE)
	else:
		_show_toast("%s costs $%d. You have $%d." % [_selected.display_name, _selected.cost, sim.economy.budget], UiTheme.BAD)


func right_click_at(point: Vector2) -> void:
	var placed := _view.placed_at(point)
	if placed != null:
		sim.sell(placed)
		_sfx.play(Sfx.Sound.PLACE)
		add_feed_line("Sold %s for $%d." % [placed.data.display_name, placed.data.cost / 2], UiTheme.MUTED)


func retry_level() -> void:
	if _infinite:
		_load_infinite(_infinite_depth, false)
	else:
		_load_level(level_index, false)


func next_level() -> void:
	if _infinite:
		_load_infinite(_infinite_depth + 1)
	else:
		_load_level((level_index + 1) % Content.LEVEL_COUNT)


func shop_button_count() -> int:
	return _shop.get_child_count()


func shop_card_text(index: int) -> String:
	return _shop.get_child(index).get_meta("card_text")


func get_view() -> LevelView:
	return _view


func add_feed_line(text: String, color: Color) -> void:
	_feed_lines.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	if _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines = _feed_lines.slice(_feed_lines.size() - MAX_FEED_LINES)
	_feed.text = "\n".join(_feed_lines)


func feed_text() -> String:
	return _feed.get_parsed_text()


func feed_line_count() -> int:
	return _feed_lines.size()


func _load_level(index: int, show_briefing := true) -> void:
	level_index = index
	_infinite = false
	_start_sim(Content.level(index), "Level %d of %d" % [index + 1, Content.LEVEL_COUNT], show_briefing)


func _load_infinite(depth: int, show_briefing := true) -> void:
	_infinite = true
	_infinite_depth = depth
	_start_sim(LevelGenerator.generate(_infinite_seed, depth), "Infinite play: level %d" % depth, show_briefing)


func _start_sim(level: LevelData, title: String, show_briefing: bool) -> void:
	sim = LevelSim.new(level)
	sim.wave_started.connect(func(number: int) -> void:
		add_feed_line("Wave %d started." % number, UiTheme.CABLE))
	sim.wave_ended.connect(_on_wave_ended)
	sim.unit_breached.connect(func(attack: AttackData) -> void:
		_sfx.play_breach(attack)
		add_feed_line("%s reached the database: -%d integrity." % [attack.display_name, roundi(attack.breach_damage)], UiTheme.BAD))
	sim.unit_killed.connect(func(_attack: AttackData, _point: Vector2) -> void: _sfx.play(Sfx.Sound.KILL))
	sim.email_caught.connect(func(_node_id: int) -> void:
		_sfx.play(Sfx.Sound.KILL)
		add_feed_line("Email Filter caught a phishing email.", UiTheme.GOOD))
	sim.workstation_compromised.connect(func(_id: int) -> void:
		_sfx.play(Sfx.Sound.SOCIAL)
		add_feed_line("An employee clicked the link. Workstation compromised.", UiTheme.WARN)
		_show_toast("An employee clicked the link. Workstation compromised.", UiTheme.WARN))
	sim.workstation_cleaned.connect(func(_id: int) -> void:
		add_feed_line("EDR cleaned a workstation.", UiTheme.GOOD))
	sim.report_raised.connect(_on_report_raised)
	sim.level_won.connect(_on_level_won)
	_view.bind(sim)
	_pending_reports.clear()
	_feed_lines.clear()
	_feed.text = ""
	_accumulator = 0.0
	_modal.visible = false
	set_paused(false)
	_level_title.text = title
	_level_name.text = sim.level.display_name
	_rebuild_shop()
	_rebuild_pips()
	_rebuild_legend()
	select_defense(null)
	if show_briefing:
		_open_modal("[font_size=30][b]%s[/b][/font_size]\n\n%s\n\nPick a defense at the bottom, then click a green slot on the map. Right-click a defense to sell it.\n\n[color=#%s]Q W E R pick a defense. 1 2 3 4 set speed. Space pauses. F11 switches fullscreen.[/color]" % [sim.level.display_name, sim.level.briefing, UiTheme.MUTED.to_html(false)], "Start level", close_modal, UiTheme.CABLE)


func _rebuild_shop() -> void:
	for child in _shop.get_children():
		_shop.remove_child(child)
		child.queue_free()
	for i in sim.level.allowed_defenses.size():
		_shop.add_child(_make_card(sim.level.allowed_defenses[i], i))


func _make_card(data: DefenseData, index: int) -> Button:
	var card := Button.new()
	card.theme_type_variation = "RackCard"
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(214, 0)
	card.tooltip_text = _describe(data)
	card.set_meta("defense", data)
	var price := "$%d + $%d per wave" % [data.cost, data.base_upkeep]
	card.set_meta("card_text", "%s %s" % [data.display_name, price])
	card.pressed.connect(select_shop_index.bind(index))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _view.icon_texture(LevelView.defense_icon_path(data))
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	column.add_child(_text(data.display_name, 16, UiTheme.TEXT, UiTheme.bold_font()))
	var cost_label := _text(price, 13, UiTheme.MUTED)
	cost_label.name = "Cost"
	column.add_child(cost_label)
	row.add_child(_text(SHOP_KEYS[index], 13, UiTheme.MUTED, UiTheme.data_font()))
	return card


func _describe(data: DefenseData) -> String:
	var lines := PackedStringArray()
	match data.slot:
		GameTypes.SlotType.LINK:
			lines.append("Goes on a cable.")
		GameTypes.SlotType.NODE:
			lines.append("Goes on a network device.")
		GameTypes.SlotType.MAILBOX:
			lines.append("Goes on the mail server, which screens all email, or a workstation, which screens only its own.")
		GameTypes.SlotType.ASSET:
			lines.append("Goes on the database.")
	if data.catch_chance > 0.0:
		lines.append("Catches %d%% of phishing emails." % roundi(data.catch_chance * 100.0))
	if data.clean_seconds > 0.0:
		lines.append("Damages malware and cleans compromised workstations in range.")
	if data.restore_fraction > 0.0:
		lines.append("Restores %d%% of a ransomware loss after %d s. Doesn't prevent the hit." % [roundi(data.restore_fraction * 100.0), roundi(data.restore_delay)])
	if data == Content.firewall():
		lines.append("Strong against network traffic, weak against malware, useless against phishing.")
	lines.append("Each extra copy costs more upkeep.")
	return "\n".join(lines)


func _rebuild_pips() -> void:
	for child in _wave_pips.get_children():
		_wave_pips.remove_child(child)
		child.queue_free()
	for i in sim.level.waves.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 8)
		_wave_pips.add_child(pip)


func _rebuild_legend() -> void:
	for child in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()
	var seen: Array[AttackData] = []
	for wave in sim.level.waves:
		for entry in wave.entries:
			if entry.count > 0 and not seen.has(entry.attack):
				seen.append(entry.attack)
	if seen.has(Content.phishing()):
		seen.append(Content.intruder())
	for attack in seen:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = LevelView.FAMILY_COLORS[attack.family]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_text(attack.display_name, 14, UiTheme.TEXT))
		_legend.add_child(row)


func _on_wave_ended(wave_number: int, breaches: int) -> void:
	if breaches == 0:
		add_feed_line("Wave %d held with no breaches." % wave_number, UiTheme.GOOD)
		_show_toast("Wave %d held with no breaches." % wave_number, UiTheme.GOOD)
	else:
		var noun := "breach" if breaches == 1 else "breaches"
		add_feed_line("Wave %d ended with %d %s." % [wave_number, breaches, noun], UiTheme.WARN)
		_show_toast("Wave %d ended with %d %s." % [wave_number, breaches, noun], UiTheme.WARN)


func _on_report_raised(report: Dictionary) -> void:
	if report["is_loss"]:
		_pending_reports.clear()
		_show_report(report)
	elif is_modal_open():
		_pending_reports.append(report)
	else:
		_show_report(report)


func _show_report(report: Dictionary) -> void:
	var heading := "Data Integrity reached 0" if report["is_loss"] else "Incident report"
	var muted := UiTheme.MUTED.to_html(false)
	var text := "[font_size=30][b]%s[/b][/font_size]\n\n[color=#%s]What got in[/color]\n[b]%s[/b]\n\n[color=#%s]Path it took[/color]\n%s\n\n[color=#%s]What would have stopped it[/color]\n[b]%s[/b]\n\n%s" % [heading, muted, report["attack"], muted, report["path"], muted, report["counter"], report["lesson"]]
	var stripe: Color = UiTheme.BAD if report["is_loss"] else LevelView.FAMILY_COLORS[report["family"]]
	if report["is_loss"] and _infinite:
		_open_modal(text, "Start a new run", start_infinite, stripe, [["Main menu", open_menu]])
	elif report["is_loss"]:
		_open_modal(text, "Try again", retry_level, stripe, [["Main menu", open_menu]])
	else:
		_open_modal(text, "Back to the network", close_modal, stripe)


func _on_level_won() -> void:
	_pending_reports.clear()
	var integrity := roundi(sim.integrity.integrity)
	var result := "Perfect defense: 100 Data Integrity." if integrity >= 100 else "You finished with %d Data Integrity. Can you keep it at 100?" % integrity
	var text := "[font_size=30][b]%s secured[/b][/font_size]\n\n%s" % [sim.level.display_name, result]
	if _infinite:
		progress.record_infinite(_infinite_depth)
		_open_modal("%s\n\nDeepest run so far: level %d." % [text, progress.infinite_best()], "Next network", next_level, UiTheme.GOOD, [["Main menu", open_menu]])
		return
	progress.record_level(level_index, sim.integrity.integrity)
	_refresh_menu()
	var extras: Array = [["Replay level", retry_level], ["Main menu", open_menu]]
	if level_index == Content.LEVEL_COUNT - 1:
		text += "\n\nThat's every story level. Infinite play generates new networks that keep getting harder until one beats you."
		_open_modal(text, "Start infinite play", start_infinite, UiTheme.GOOD, extras)
	else:
		_open_modal(text, "Next level", next_level, UiTheme.GOOD, extras)


func _open_modal(text: String, button_text: String, action: Callable, stripe: Color, extras: Array = []) -> void:
	_modal_label.text = text
	_modal_button.text = button_text
	_modal_action = action
	_modal_stripe.color = stripe
	for child in _modal_extras.get_children():
		_modal_extras.remove_child(child)
		child.queue_free()
	for extra: Array in extras:
		var button := Button.new()
		button.text = extra[0]
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(extra[1])
		_modal_extras.add_child(button)
	_modal_extras.visible = not extras.is_empty()
	_modal.visible = true
	_modal.modulate.a = 0.0
	create_tween().tween_property(_modal, "modulate:a", 1.0, 0.14)
	_modal_button.grab_focus()


func _show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_remaining = TOAST_SECONDS


func _refresh_hud() -> void:
	var waves := sim.level.waves.size()
	_wave_label.text = "%d of %d" % [mini(sim.wave_number, waves), waves]
	for i in _wave_pips.get_child_count():
		var pip: ColorRect = _wave_pips.get_child(i)
		if i + 1 < sim.wave_number:
			pip.color = UiTheme.MUTED
		elif i + 1 == sim.wave_number:
			pip.color = UiTheme.CABLE
		else:
			pip.color = UiTheme.LINE
	_budget.text = "$%d" % sim.economy.budget
	_budget.add_theme_color_override("font_color", UiTheme.BAD if sim.economy.budget < 0 else UiTheme.TEXT)
	_upkeep.text = "$%d" % sim.economy.upkeep_due()
	var integrity := sim.integrity.integrity
	var integrity_color := UiTheme.integrity_color(integrity)
	_integrity.text = "%d" % ceili(integrity)
	_integrity.add_theme_color_override("font_color", integrity_color)
	_integrity_bar.value = integrity
	_integrity_fill.bg_color = integrity_color
	_start_button.disabled = sim.phase != LevelSim.Phase.BUILD
	if sim.phase == LevelSim.Phase.BUILD:
		_start_button.text = "Start wave %d\nor wait %d s" % [sim.wave_number + 1, ceili(maxf(sim.build_remaining, 0.0))]
	else:
		_start_button.text = "Wave %d\nunder attack" % sim.wave_number
	for card: Button in _shop.get_children():
		var data: DefenseData = card.get_meta("defense")
		var cost_label := card.find_child("Cost", true, false) as Label
		cost_label.add_theme_color_override("font_color", UiTheme.MUTED if sim.economy.can_afford(data.cost) else UiTheme.BAD)


func _text(value: String, size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _stat(parent: Control, caption: String) -> Label:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.add_child(_text(caption, 13, UiTheme.MUTED))
	var value := _text("", 24, UiTheme.TEXT, UiTheme.data_font())
	column.add_child(value)
	parent.add_child(column)
	return value


func _bar(preset: Control.LayoutPreset, height: int) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.add_theme_stylebox_override("panel", UiTheme.flush(UiTheme.PANEL))
	panel.custom_minimum_size.y = height
	panel.offset_top = 0 if preset == Control.PRESET_TOP_WIDE else -height
	panel.offset_bottom = height if preset == Control.PRESET_TOP_WIDE else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	panel.add_child(row)
	row.set_meta("panel", panel)
	return row


func _build_ui() -> void:
	_view = LevelView.new()
	add_child(_view)
	_sfx = Sfx.new()
	add_child(_sfx)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_build_feed(root)
	_build_top(root)
	_build_bottom(root)
	_build_toast(root)
	_build_modal(root)
	_build_menu(root)
	set_speed(speed)


func _build_top(root: Control) -> void:
	var row := _bar(Control.PRESET_TOP_WIDE, TOP_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	_top_row = row
	root.add_child(row.get_meta("panel"))

	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 0)
	title.custom_minimum_size.x = 170
	_level_title = _text("", 13, UiTheme.MUTED)
	title.add_child(_level_title)
	_level_name = _text("", 19, UiTheme.TEXT, UiTheme.bold_font())
	title.add_child(_level_name)
	row.add_child(title)

	var wave := VBoxContainer.new()
	wave.alignment = BoxContainer.ALIGNMENT_CENTER
	wave.add_theme_constant_override("separation", 6)
	var wave_top := HBoxContainer.new()
	wave_top.add_theme_constant_override("separation", 8)
	wave_top.add_child(_text("Wave", 13, UiTheme.MUTED))
	_wave_label = _text("", 13, UiTheme.TEXT, UiTheme.data_font())
	wave_top.add_child(_wave_label)
	wave.add_child(wave_top)
	_wave_pips = HBoxContainer.new()
	_wave_pips.add_theme_constant_override("separation", 4)
	wave.add_child(_wave_pips)
	row.add_child(wave)

	_budget = _stat(row, "Budget")
	_upkeep = _stat(row, "Upkeep/wave")

	var health := VBoxContainer.new()
	health.alignment = BoxContainer.ALIGNMENT_CENTER
	health.add_theme_constant_override("separation", 2)
	var health_top := HBoxContainer.new()
	var health_caption := _text("Data Integrity", 14, UiTheme.TEXT, UiTheme.bold_font())
	health_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_top.add_child(health_caption)
	_integrity = _text("", 24, UiTheme.GOOD, UiTheme.data_font())
	health_top.add_child(_integrity)
	health.add_child(health_top)
	_integrity_bar = ProgressBar.new()
	_integrity_bar.show_percentage = false
	_integrity_bar.custom_minimum_size = Vector2(190, 14)
	_integrity_bar.max_value = IntegrityTracker.MAXIMUM
	_integrity_fill = UiTheme.box(UiTheme.GOOD, Color.TRANSPARENT, 0, 0)
	_integrity_bar.add_theme_stylebox_override("fill", _integrity_fill)
	health.add_child(_integrity_bar)
	row.add_child(health)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_fps = _text("", 13, UiTheme.MUTED, UiTheme.data_font())
	_fps.visible = false
	row.add_child(_fps)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 3)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	for choice in SPEEDS:
		var speed_button := Button.new()
		speed_button.text = "x%d" % choice
		speed_button.toggle_mode = true
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.custom_minimum_size = Vector2(42, 42)
		speed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		speed_button.add_theme_font_override("font", UiTheme.data_font())
		speed_button.tooltip_text = "Game speed (key %d)" % (SPEEDS.find(choice) + 1)
		speed_button.pressed.connect(func() -> void:
			_sfx.play(Sfx.Sound.CLICK)
			set_speed(choice))
		controls.add_child(speed_button)
		_speed_buttons[choice] = speed_button
	var gap := Control.new()
	gap.custom_minimum_size.x = 8
	controls.add_child(gap)
	_pause_button = Button.new()
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.custom_minimum_size = Vector2(72, 42)
	_pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_button.tooltip_text = "Pause or resume (Space)"
	_pause_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		set_paused(not _paused))
	controls.add_child(_pause_button)
	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.custom_minimum_size = Vector2(64, 42)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		open_menu())
	controls.add_child(menu_button)
	row.add_child(controls)


func _build_bottom(root: Control) -> void:
	var row := _bar(Control.PRESET_BOTTOM_WIDE, BOTTOM_HEIGHT)
	row.add_theme_constant_override("separation", 10)
	root.add_child(row.get_meta("panel"))
	_shop = HBoxContainer.new()
	_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop.add_theme_constant_override("separation", 8)
	row.add_child(_shop)
	_start_button = Button.new()
	_start_button.theme_type_variation = "PrimaryButton"
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.custom_minimum_size = Vector2(190, 0)
	_start_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		sim.start_wave_now())
	row.add_child(_start_button)


func _build_feed(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -FEED_WIDTH
	panel.offset_right = 0
	panel.offset_top = TOP_HEIGHT
	panel.offset_bottom = -BOTTOM_HEIGHT
	panel.add_theme_stylebox_override("panel", UiTheme.flush(UiTheme.INK, 12))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_text("Attacks in this level", 15, UiTheme.TEXT, UiTheme.bold_font()))
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 3)
	column.add_child(_legend)
	var rule := ColorRect.new()
	rule.color = UiTheme.LINE
	rule.custom_minimum_size.y = 1
	column.add_child(rule)
	column.add_child(_text("What's happening", 15, UiTheme.TEXT, UiTheme.bold_font()))
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_following = true
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.add_theme_font_size_override("normal_font_size", 13)
	_feed.add_theme_constant_override("line_separation", 5)
	column.add_child(_feed)


func _build_toast(root: Control) -> void:
	_toast = PanelContainer.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.offset_left = -FEED_WIDTH - 12
	_toast.offset_right = -FEED_WIDTH - 12
	_toast.offset_top = TOP_HEIGHT + 10
	_toast.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.INK, UiTheme.LINE, 1, 9))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	root.add_child(_toast)
	_toast_label = _text("", 15, UiTheme.TEXT)
	_toast.add_child(_toast_label)


func _build_modal(root: Control) -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.LINE, 1, 0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_modal_stripe = ColorRect.new()
	_modal_stripe.custom_minimum_size.y = 8
	column.add_child(_modal_stripe)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	column.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	margin.add_child(body)
	_modal_label = RichTextLabel.new()
	_modal_label.bbcode_enabled = true
	_modal_label.fit_content = true
	_modal_label.scroll_active = false
	body.add_child(_modal_label)
	_modal_button = Button.new()
	_modal_button.theme_type_variation = "PrimaryButton"
	_modal_button.custom_minimum_size.y = 50
	_modal_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		_modal_action.call())
	body.add_child(_modal_button)
	_modal_extras = HBoxContainer.new()
	_modal_extras.add_theme_constant_override("separation", 8)
	body.add_child(_modal_extras)


func _build_menu(root: Control) -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_theme_stylebox_override("panel", UiTheme.flush(UiTheme.INK, 56))
	root.add_child(_menu)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	_menu.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)
	left.add_child(_text("Defense\nin Depth", 68, UiTheme.CABLE, UiTheme.bold_font()))
	var tagline := _text("Your firewall is great until someone clicks the phishing link.", 18, UiTheme.TEXT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	left.add_child(gap)
	_continue_button = Button.new()
	_continue_button.theme_type_variation = "PrimaryButton"
	_continue_button.custom_minimum_size.y = 60
	_continue_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		start_story(_next_story_level()))
	left.add_child(_continue_button)
	_infinite_button = Button.new()
	_infinite_button.custom_minimum_size.y = 60
	_infinite_button.add_theme_font_size_override("font_size", 16)
	_infinite_button.tooltip_text = "Random networks that keep getting harder until one beats you."
	_infinite_button.pressed.connect(func() -> void:
		_sfx.play(Sfx.Sound.CLICK)
		start_infinite())
	left.add_child(_infinite_button)
	if not OS.has_feature("web"):
		var quit_button := Button.new()
		quit_button.text = "Quit"
		quit_button.custom_minimum_size.y = 42
		quit_button.pressed.connect(func() -> void: get_tree().quit())
		left.add_child(quit_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	right.add_child(_text("Story levels", 22, UiTheme.TEXT, UiTheme.bold_font()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	for i in Content.LEVEL_COUNT:
		var card := Button.new()
		card.theme_type_variation = "RackCard"
		card.custom_minimum_size = Vector2(0, 76)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.pressed.connect(func() -> void:
			_sfx.play(Sfx.Sound.CLICK)
			start_story(i))
		grid.add_child(card)
		_story_cards.append(card)


func _next_story_level() -> int:
	for i in Content.LEVEL_COUNT:
		if progress.best(i) < 0:
			return i
	return 0


func _refresh_menu() -> void:
	var next := _next_story_level()
	var started := progress.best(0) >= 0
	_continue_button.text = "Play story: level %d" % (next + 1) if started else "Play story"
	var deepest := progress.infinite_best()
	_infinite_button.text = "Infinite play (deepest: level %d)" % deepest if deepest > 0 else "Infinite play"
	for i in _story_cards.size():
		var card := _story_cards[i]
		var best := progress.best(i)
		card.disabled = not progress.is_unlocked(i)
		var status := "Locked"
		if best >= 100:
			status = "Perfect: 100 integrity"
		elif best >= 0:
			status = "Best: %d integrity" % best
		elif progress.is_unlocked(i):
			status = "Not played yet"
		card.text = "%d. %s\n%s" % [i + 1, Content.level(i).display_name, status]
		card.add_theme_color_override("font_color", UiTheme.GOOD if best >= 100 else UiTheme.TEXT)
