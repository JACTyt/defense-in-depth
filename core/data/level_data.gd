class_name LevelData
extends RefCounted


class NodeDef:
	var id: int
	var kind: GameTypes.NodeKind
	var label: String
	var position: Vector2
	var has_slot: bool

	func _init(p_id: int, p_kind: GameTypes.NodeKind, p_label: String, p_position: Vector2, p_has_slot := false) -> void:
		id = p_id
		kind = p_kind
		label = p_label
		position = p_position
		has_slot = p_has_slot


class LinkDef:
	var a: int
	var b: int
	var social: bool
	var has_slot: bool

	func _init(p_a: int, p_b: int, p_social := false, p_has_slot := false) -> void:
		a = p_a
		b = p_b
		social = p_social
		has_slot = p_has_slot


class SpawnEntry:
	var attack: AttackData
	var count: int
	var entry_node: int
	var target_node: int
	var start_delay: float
	var interval: float

	func _init(p_attack: AttackData, p_count: int, p_entry: int, p_target: int, p_start_delay: float, p_interval: float) -> void:
		attack = p_attack
		count = p_count
		entry_node = p_entry
		target_node = p_target
		start_delay = p_start_delay
		interval = p_interval


class WaveData:
	var entries: Array[SpawnEntry]
	var attack_seconds: float

	func _init(p_entries: Array[SpawnEntry], p_attack_seconds: float) -> void:
		entries = p_entries
		attack_seconds = p_attack_seconds


var display_name: String
var nodes: Array[NodeDef] = []
var links: Array[LinkDef] = []
var waves: Array[WaveData] = []
var start_budget: int
var quarterly_income: int
var allowed_defenses: Array[DefenseData] = []
var rng_seed: int
var briefing: String


func build_graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	for node in nodes:
		graph.add_node(node.id, node.position)
	for link in links:
		if link.social:
			graph.add_social(link.a, link.b)
		else:
			graph.add_cable(link.a, link.b)
	return graph


func node_def(id: int) -> NodeDef:
	for node in nodes:
		if node.id == id:
			return node
	return null
