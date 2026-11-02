class_name NetworkGraph
extends RefCounted
## Cable and social edges. Separate graphs keep cable units off social edges.

const DEFENDED_LINK_PENALTY := 150.0

var _cables := CostAStar.new()
var _social := CostAStar.new()


func add_node(id: int, position: Vector2) -> void:
	_cables.add_point(id, position)
	_social.add_point(id, position)


func position_of(id: int) -> Vector2:
	return _cables.get_point_position(id)


func add_cable(a: int, b: int) -> void:
	_cables.connect_points(a, b)


func add_social(a: int, b: int) -> void:
	_social.connect_points(a, b)


func set_link_defended(a: int, b: int, defended: bool) -> void:
	var link := CostAStar.key(a, b)
	if defended:
		_cables.penalties[link] = DEFENDED_LINK_PENALTY
	else:
		_cables.penalties.erase(link)


func cable_route(from_id: int, to_id: int) -> PackedInt64Array:
	return _cables.get_id_path(from_id, to_id)


func social_route(from_id: int, to_id: int) -> PackedInt64Array:
	return _social.get_id_path(from_id, to_id)
