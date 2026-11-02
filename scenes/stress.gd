extends Node
## Performance check for the decision point: 100 units with defenses, reporting average fps.
## Open with F9 in the game. Esc returns to the game.

const UNIT_COUNT := 100
const SAMPLE_SECONDS := 10.0

var _sim: LevelSim
var _label: Label
var _elapsed := 0.0
var _frames := 0


func _ready() -> void:
	_sim = LevelSim.new(Content.level(2))
	for data: DefenseData in [Content.firewall(), Content.edr()]:
		for slot in _sim.slots_for(data):
			_sim.economy.add_bounty(data.cost)
			_sim.place(data, slot)
	_sim.start_wave_now()
	var view := LevelView.new()
	add_child(view)
	view.bind(_sim)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_label)


func _process(delta: float) -> void:
	_keep_units_alive()
	_sim.tick(minf(delta, 0.1))
	_elapsed += delta
	_frames += 1
	var average := _frames / maxf(_elapsed, 0.001)
	_label.text = "%d units   %.0f fps average   %.0f fps now" % [_sim.units.size(), average, Engine.get_frames_per_second()]
	if _elapsed >= SAMPLE_SECONDS and _frames > 0:
		print("STRESS units=%d avg_fps=%.1f" % [_sim.units.size(), average])
		_elapsed = 0.0
		_frames = 0


func _keep_units_alive() -> void:
	var route := _sim.graph.cable_route(0, 6)
	var points := PackedVector2Array()
	for id in route:
		points.append(_sim.graph.position_of(id))
	while _sim.units.size() < UNIT_COUNT:
		var unit := LevelSim.Unit.new(Content.intruder(), route, points)
		unit.next_point = 1
		unit.position = points[0].lerp(points[1], randf())
		_sim.units.append(unit)
	_sim.integrity.integrity = IntegrityTracker.MAXIMUM


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
