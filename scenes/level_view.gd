class_name LevelView
extends Node2D
## Draws a LevelSim as a bright network map. Colors follow the GDD's family coding;
## shapes repeat that coding so it doesn't rely on color alone.

const MAP_OFFSET := Vector2(24, 62)
const MAP_SCALE := 0.8
const BASE_SIZE := Vector2(1280, 720)
const PICK_RADIUS := 26.0
const MAX_EFFECTS := 80
const TRACER_SECONDS := 0.12
const FLOAT_SECONDS := 0.9
const RING_SECONDS := 0.5
const BACKGROUND := Color("e9f0f7")
const GRID := Color("d5e0ec")
const CABLE_EDGE := Color("8497b0")
const CABLE_CORE := Color("c5d2e2")
const SOCIAL := Color(0.56, 0.27, 0.84, 0.55)
const INK := Color("243045")
const OPEN_SLOT := Color("149a62")
const FAMILY_COLORS := {
	GameTypes.Family.NETWORK: Color("e0453a"),
	GameTypes.Family.SOCIAL: Color("8e44d6"),
	GameTypes.Family.MALWARE: Color("1f9a45"),
	GameTypes.Family.INSIDER: Color("e8b923"),
	GameTypes.Family.BOSS: Color("ffffff"),
}
const ICON_DIR := "res://art/icons/"
const COMPROMISED_ICON := ICON_DIR + "workstation_compromised.svg"
const LABEL_ICONS := {
	"Modem": "modem",
	"Core switch": "switch",
	"Web zone": "web_zone",
	"App zone": "web_zone",
	"Web servers": "server",
	"App servers": "server",
	"Office north": "office",
	"Office south": "office",
	"North office": "office",
	"Center office": "office",
	"South office": "office",
}
const DEFENSE_ICONS := {
	"Firewall": "firewall",
	"Email Filter": "email_filter",
	"EDR Agent": "edr",
	"Backups": "backups",
}


class Backdrop:
	extends Node2D
	## Drawn once, not every frame.

	func _draw() -> void:
		draw_rect(Rect2(-800, -600, 3200, 2200), BACKGROUND)
		for x in range(-800, 2400, 40):
			draw_line(Vector2(x, -600), Vector2(x, 1600), GRID, 1.0)
		for y in range(-600, 1600, 40):
			draw_line(Vector2(-800, y), Vector2(2400, y), GRID, 1.0)


var sim: LevelSim
var selected: DefenseData = null
var _slots: Dictionary = {}  # DefenseData -> Array[LevelSim.Slot]
var _icons: Dictionary = {}  # path -> Texture2D, held because canvas draws don't keep textures alive
var _effects: Array[Dictionary] = []


static func node_icon_path(node: LevelData.NodeDef) -> String:
	var icon: String = LABEL_ICONS.get(node.label, "office" if node.label.begins_with("Office") else "router")
	match node.kind:
		GameTypes.NodeKind.INTERNET:
			icon = "internet"
		GameTypes.NodeKind.ASSET:
			icon = "database"
		GameTypes.NodeKind.MAIL_SERVER:
			icon = "mail"
		GameTypes.NodeKind.WORKSTATION:
			icon = "workstation"
	return ICON_DIR + icon + ".svg"


static func defense_icon_path(data: DefenseData) -> String:
	return ICON_DIR + DEFENSE_ICONS.get(data.display_name, "") + ".svg"


func _ready() -> void:
	scale = Vector2(MAP_SCALE, MAP_SCALE)
	var backdrop := Backdrop.new()
	backdrop.show_behind_parent = true
	add_child(backdrop)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


func centered_position(window: Vector2) -> Vector2:
	return MAP_OFFSET + (window - BASE_SIZE) / 2.0


func _fit_to_window() -> void:
	position = centered_position(get_viewport_rect().size)


func bind(p_sim: LevelSim) -> void:
	sim = p_sim
	_effects.clear()
	rebuild_slots()
	sim.defense_fired.connect(_on_defense_fired)
	sim.unit_killed.connect(_on_unit_killed)
	sim.unit_breached.connect(_on_unit_breached)
	sim.email_caught.connect(_on_email_caught)


func icon_texture(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = load(path)
	return _icons[path]


func is_icon_cached(path: String) -> bool:
	return _icons.has(path)


func rebuild_slots() -> void:
	_slots.clear()
	for data in sim.level.allowed_defenses:
		_slots[data] = sim.slots_for(data)


func slot_at(data: DefenseData, point: Vector2) -> LevelSim.Slot:
	var best: LevelSim.Slot = null
	var best_distance := PICK_RADIUS
	for slot: LevelSim.Slot in _slots.get(data, []):
		var distance := slot.position.distance_to(point)
		if distance <= best_distance:
			best = slot
			best_distance = distance
	return best


func placed_at(point: Vector2) -> LevelSim.Placed:
	var best: LevelSim.Placed = null
	var best_distance := PICK_RADIUS
	for placed in sim.defenses:
		var distance := placed.slot.position.distance_to(point)
		if distance <= best_distance:
			best = placed
			best_distance = distance
	return best


func add_float(point: Vector2, text: String, color: Color) -> void:
	_add_effect({"kind": "float", "at": point, "text": text, "color": color, "life": FLOAT_SECONDS, "span": FLOAT_SECONDS})


func effect_count() -> int:
	return _effects.size()


func _add_effect(effect: Dictionary) -> void:
	_effects.append(effect)
	if _effects.size() > MAX_EFFECTS:
		_effects.pop_front()


func _on_defense_fired(placed: LevelSim.Placed, unit: LevelSim.Unit) -> void:
	_add_effect({"kind": "tracer", "from": placed.slot.position, "to": unit.position, "color": FAMILY_COLORS[unit.attack.family], "life": TRACER_SECONDS, "span": TRACER_SECONDS})


func _on_unit_killed(attack: AttackData, point: Vector2) -> void:
	add_float(point, "+$%d" % attack.bounty, OPEN_SLOT)


func _on_unit_breached(attack: AttackData) -> void:
	for node in sim.level.nodes:
		if node.kind == GameTypes.NodeKind.ASSET:
			add_float(node.position + Vector2(0, -44), "-%d" % roundi(attack.breach_damage), FAMILY_COLORS[GameTypes.Family.NETWORK])
			_add_effect({"kind": "ring", "at": node.position, "color": FAMILY_COLORS[GameTypes.Family.NETWORK], "life": RING_SECONDS, "span": RING_SECONDS})


func _on_email_caught(node_id: int) -> void:
	add_float(sim.graph.position_of(node_id) + Vector2(0, -30), "Caught", FAMILY_COLORS[GameTypes.Family.SOCIAL])


func _process(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		_effects[i]["life"] -= delta
		if _effects[i]["life"] <= 0.0:
			_effects.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for link in sim.level.links:
		_draw_link(link)
	for node in sim.level.nodes:
		_draw_node(node)
	_draw_open_slots()
	_draw_hover()
	for placed in sim.defenses:
		_draw_defense(placed)
	for unit in sim.units:
		_draw_unit(unit)
	for effect in _effects:
		_draw_effect(effect)


func _draw_link(link: LevelData.LinkDef) -> void:
	var from := sim.graph.position_of(link.a)
	var to := sim.graph.position_of(link.b)
	if link.social:
		draw_dashed_line(from, to, SOCIAL, 1.5, 7.0)
	else:
		draw_line(from, to, CABLE_EDGE, 7.0)
		draw_line(from, to, CABLE_CORE, 3.5)


func _draw_node(node: LevelData.NodeDef) -> void:
	var path := node_icon_path(node)
	var radius := 26.0
	match node.kind:
		GameTypes.NodeKind.ASSET:
			radius = 38.0
		GameTypes.NodeKind.WORKSTATION:
			radius = 20.0
			if sim.workstations[node.id].is_compromised:
				path = COMPROMISED_ICON
				radius = 30.0
				draw_arc(node.position, radius + 4.0, 0.0, TAU, 32, FAMILY_COLORS[GameTypes.Family.MALWARE], 3.0)
	_draw_icon(path, node.position, radius)
	if node.kind != GameTypes.NodeKind.WORKSTATION:
		_draw_tag(node.position + Vector2(0, radius + 15), node.label, INK, Color(1, 1, 1, 0.85), 15)


func _draw_tag(center: Vector2, text: String, ink: Color, fill: Color, size: int) -> void:
	var font := UiTheme.body_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(center - Vector2(width / 2.0 + 5.0, size * 0.75), Vector2(width + 10.0, size * 1.45)), fill)
	draw_string(font, center + Vector2(-width / 2.0, size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


func _draw_open_slots() -> void:
	if selected == null:
		return
	for slot: LevelSim.Slot in _slots.get(selected, []):
		if not sim.is_occupied(slot):
			var on_device := selected.slot != GameTypes.SlotType.LINK
			var radius := 15.0
			if on_device:
				radius = 26.0 if sim.workstations.has(slot.a) else 34.0
			draw_circle(slot.position, radius, Color(OPEN_SLOT, 0.2 if on_device else 0.3))
			draw_arc(slot.position, radius, 0.0, TAU, 8, OPEN_SLOT, 3.5 if on_device else 2.5)


func _draw_hover() -> void:
	var mouse := get_local_mouse_position()
	if selected != null:
		var slot := slot_at(selected, mouse)
		if slot != null and not sim.is_occupied(slot):
			_draw_range(slot.position, selected.range_px, OPEN_SLOT)
			_draw_icon(defense_icon_path(selected), slot.position, 20.0, Color(1, 1, 1, 0.65))
	var placed := placed_at(mouse)
	if placed != null:
		_draw_range(placed.slot.position, placed.data.range_px, INK)
		_draw_tag(placed.slot.position + Vector2(0, -38), "%s: right-click to sell" % placed.data.display_name, UiTheme.TEXT, UiTheme.INK, 14)
	for unit in sim.units:
		if unit.position.distance_to(mouse) <= PICK_RADIUS:
			draw_polyline(unit.points, FAMILY_COLORS[unit.attack.family], 3.0)
			_draw_tag(unit.position + Vector2(0, -24), unit.attack.display_name, UiTheme.TEXT, UiTheme.INK, 14)
			break


func _draw_range(center: Vector2, radius: float, color: Color) -> void:
	if radius > 0.0:
		draw_circle(center, radius, Color(color, 0.1))
		draw_arc(center, radius, 0.0, TAU, 56, color, 1.5)


func _draw_defense(placed: LevelSim.Placed) -> void:
	var center := placed.slot.position
	var linked := placed.data.slot == GameTypes.SlotType.LINK or placed.data.slot == GameTypes.SlotType.NODE
	if linked:
		draw_circle(center, 25.0, Color.WHITE)
		draw_arc(center, 25.0, 0.0, TAU, 32, INK, 2.5)
		_draw_icon(defense_icon_path(placed.data), center, 18.0, Color.WHITE if placed.is_active() else Color(1, 1, 1, 0.4))
	else:
		_draw_badge(center + Vector2(28, -28), placed)
	if not placed.is_active():
		var done := 1.0 - placed.deploy_remaining / Content.DEPLOY_SECONDS
		draw_arc(center, 29.0, -PI / 2.0, -PI / 2.0 + TAU * done, 32, OPEN_SLOT, 4.0)


## A defense installed on a device sits on its corner rather than covering it.
func _draw_badge(center: Vector2, placed: LevelSim.Placed) -> void:
	draw_circle(center, 18.0, Color.WHITE)
	draw_arc(center, 18.0, 0.0, TAU, 28, INK, 2.5)
	_draw_icon(defense_icon_path(placed.data), center, 13.0, Color.WHITE if placed.is_active() else Color(1, 1, 1, 0.4))


func _draw_unit(unit: LevelSim.Unit) -> void:
	var color: Color = FAMILY_COLORS[unit.attack.family]
	var at := unit.position
	if unit.attack.path == GameTypes.PathType.SOCIAL:
		_draw_icon(ICON_DIR + "mail.svg", at, 13.0)
	elif unit.attack.encrypts:
		var diamond := PackedVector2Array([at + Vector2(0, -14), at + Vector2(14, 0), at + Vector2(0, 14), at + Vector2(-14, 0)])
		draw_colored_polygon(diamond, color)
		diamond.append(diamond[0])
		draw_polyline(diamond, INK, 2.5)
		var width := 34.0
		draw_rect(Rect2(at + Vector2(-width / 2.0, -25), Vector2(width, 5)), INK)
		draw_rect(Rect2(at + Vector2(-width / 2.0, -25), Vector2(width * maxf(unit.hp, 0.0) / unit.attack.hp, 5)), UiTheme.BAD)
	elif unit.attack.path == GameTypes.PathType.INTERNAL:
		var triangle := PackedVector2Array([at + Vector2(0, -10), at + Vector2(9, 7), at + Vector2(-9, 7)])
		draw_colored_polygon(triangle, color)
		triangle.append(triangle[0])
		draw_polyline(triangle, Color.WHITE, 1.5)
	else:
		draw_circle(at, 7.0, color)
		draw_arc(at, 7.0, 0.0, TAU, 14, Color.WHITE, 1.5)


func _draw_effect(effect: Dictionary) -> void:
	var left: float = effect["life"] / effect["span"]
	var color: Color = effect["color"]
	match effect["kind"]:
		"tracer":
			draw_line(effect["from"], effect["to"], Color(color, left), 3.0)
		"ring":
			draw_arc(effect["at"], 40.0 + (1.0 - left) * 50.0, 0.0, TAU, 40, Color(color, left), 5.0)
		"float":
			var at: Vector2 = effect["at"] + Vector2(0, -28.0 * (1.0 - left))
			draw_string_outline(UiTheme.bold_font(), at, effect["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, 5, Color(1, 1, 1, left))
			draw_string(UiTheme.bold_font(), at, effect["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(color, left))


func _draw_icon(path: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	draw_texture_rect(icon_texture(path), rect, false, tint)
