class_name WorldStructure
extends RefCounted

# Deterministic macro structure generated from the world seed.
# WorldGenerator uses this to turn chunks into main path, branch, chamber or solid chunks.

var nodes: Dictionary = {}
var main_path_x_by_y: Dictionary = {}
var min_x: int = -16
var max_x: int = 16
var min_y: int = 0
var max_y: int = 96

func set_node(node: WorldStructureNode) -> void:
	nodes[node.coord] = node

func has_node(coord: Vector2i) -> bool:
	return nodes.has(coord)

func get_node(coord: Vector2i) -> WorldStructureNode:
	return nodes.get(coord, null) as WorldStructureNode

func get_or_create_node(coord: Vector2i, biome_id: StringName, chunk_type: int = BiomeMap.ChunkType.SOLID) -> WorldStructureNode:
	var existing: WorldStructureNode = get_node(coord)
	if existing != null:
		return existing
	var node: WorldStructureNode = WorldStructureNode.new(coord, biome_id, chunk_type)
	set_node(node)
	return node

func get_main_path_x(y: int, fallback_x: int = 0) -> int:
	return int(main_path_x_by_y.get(y, fallback_x))

func set_main_path_x(y: int, x: int) -> void:
	main_path_x_by_y[y] = x

func has_connection(coord: Vector2i, side: StringName) -> bool:
	var node: WorldStructureNode = get_node(coord)
	return node != null and node.has_connection(side)

func are_same_chamber(a: Vector2i, b: Vector2i) -> bool:
	var node_a: WorldStructureNode = get_node(a)
	var node_b: WorldStructureNode = get_node(b)
	return node_a != null and node_a.is_same_chamber(node_b)

func tags_for(coord: Vector2i) -> Array[StringName]:
	var node: WorldStructureNode = get_node(coord)
	return node.structure_tags.duplicate() if node != null else []

func tag_string_for(coord: Vector2i) -> String:
	var node: WorldStructureNode = get_node(coord)
	return node.tag_string() if node != null else "fallback"
