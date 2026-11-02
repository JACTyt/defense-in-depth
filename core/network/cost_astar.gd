class_name CostAStar
extends AStar2D
## AStar2D with per-link penalties, which the engine class doesn't support directly.

var penalties: Dictionary = {}


static func key(a: int, b: int) -> int:
	return (mini(a, b) << 32) | maxi(a, b)


func _compute_cost(from_id: int, to_id: int) -> float:
	var distance := get_point_position(from_id).distance_to(get_point_position(to_id))
	return distance + penalties.get(key(from_id, to_id), 0.0)


func _estimate_cost(from_id: int, to_id: int) -> float:
	return get_point_position(from_id).distance_to(get_point_position(to_id))
