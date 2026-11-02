extends GutTest


func _two_route_graph() -> NetworkGraph:
	var g := NetworkGraph.new()
	g.add_node(0, Vector2(0, 0))
	g.add_node(1, Vector2(100, 0))
	g.add_node(2, Vector2(100, 20))
	g.add_node(3, Vector2(200, 0))
	g.add_cable(0, 1)
	g.add_cable(1, 3)
	g.add_cable(0, 2)
	g.add_cable(2, 3)
	return g


func test_route_takes_shortest_path() -> void:
	assert_eq(_two_route_graph().cable_route(0, 3), PackedInt64Array([0, 1, 3]))


func test_defended_link_moves_route_to_other_path() -> void:
	var g := _two_route_graph()
	g.set_link_defended(0, 1, true)
	assert_eq(g.cable_route(0, 3), PackedInt64Array([0, 2, 3]))


func test_removing_defense_restores_route() -> void:
	var g := _two_route_graph()
	g.set_link_defended(1, 0, true)
	g.set_link_defended(0, 1, false)
	assert_eq(g.cable_route(0, 3), PackedInt64Array([0, 1, 3]))


func test_cable_route_ignores_social_edges() -> void:
	var g := NetworkGraph.new()
	g.add_node(0, Vector2.ZERO)
	g.add_node(1, Vector2(100, 0))
	g.add_social(0, 1)
	assert_eq(g.cable_route(0, 1).size(), 0)
	assert_eq(g.social_route(0, 1), PackedInt64Array([0, 1]))


func test_disconnected_target_has_empty_route() -> void:
	var g := _two_route_graph()
	g.add_node(9, Vector2(500, 500))
	assert_eq(g.cable_route(0, 9).size(), 0)
