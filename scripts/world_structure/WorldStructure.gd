class_name WorldStructure
extends RefCounted

# Deterministic macro structure generated from the world seed.
# PieceChunkGenerator uses this to turn chunks into main path, branch, chamber or solid chunks.

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
	var result: Array[StringName] = []
	var node: WorldStructureNode = get_node(coord)
	if node != null:
		for tag: StringName in node.structure_tags:
			result.append(tag)
	return result

func tag_string_for(coord: Vector2i) -> String:
	var node: WorldStructureNode = get_node(coord)
	return node.tag_string() if node != null else "fallback"

func mark_special_chunk_placement(placement: SpecialChunkPlacement) -> void:
	# Write SpecialChunk placement data back into the macro-structure graph.
	# Normal generation can then treat neighbor chunks as gateways and carve paths
	# toward authored entrances instead of leaving SpecialChunks as isolated overrides.
	if placement == null or placement.chunk_def == null:
		return
	_mark_special_chunk_occupied_nodes(placement)
	_mark_special_chunk_gateways(placement)

func _mark_special_chunk_occupied_nodes(placement: SpecialChunkPlacement) -> void:
	for yy: int in range(placement.origin_chunk.y, placement.origin_chunk.y + placement.size_in_chunks.y):
		for xx: int in range(placement.origin_chunk.x, placement.origin_chunk.x + placement.size_in_chunks.x):
			var coord := Vector2i(xx, yy)
			var node: WorldStructureNode = get_node(coord)
			if node == null:
				continue
			node.chunk_type = BiomeMap.ChunkType.SPECIAL
			node.add_tag(&"special_chunk_occupied")
			node.add_tag(StringName("special_%s" % str(placement.chunk_def.id)))
			node.special_chunk_id = placement.chunk_def.id
			node.special_chunk_origin = placement.origin_chunk
			node.special_chunk_size = placement.size_in_chunks

func _mark_special_chunk_gateways(placement: SpecialChunkPlacement) -> void:
	var def: SpecialChunkDef = placement.chunk_def
	var slots_per_chunk: int = PieceWorldConstants.CHUNK_UNITS
	for local_y: int in range(placement.size_in_chunks.y):
		if _special_profile_slice_has_open(def.left_profile, local_y, slots_per_chunk):
			_mark_special_gateway(placement, Vector2i(placement.origin_chunk.x - 1, placement.origin_chunk.y + local_y), &"right")
		if _special_profile_slice_has_open(def.right_profile, local_y, slots_per_chunk):
			_mark_special_gateway(placement, Vector2i(placement.origin_chunk.x + placement.size_in_chunks.x, placement.origin_chunk.y + local_y), &"left")
	for local_x: int in range(placement.size_in_chunks.x):
		if _special_profile_slice_has_open(def.top_profile, local_x, slots_per_chunk):
			_mark_special_gateway(placement, Vector2i(placement.origin_chunk.x + local_x, placement.origin_chunk.y - 1), &"bottom")
		if _special_profile_slice_has_open(def.bottom_profile, local_x, slots_per_chunk):
			_mark_special_gateway(placement, Vector2i(placement.origin_chunk.x + local_x, placement.origin_chunk.y + placement.size_in_chunks.y), &"top")

func _mark_special_gateway(placement: SpecialChunkPlacement, coord: Vector2i, side_to_special: StringName) -> void:
	var node: WorldStructureNode = get_node(coord)
	if node == null:
		return
	if node.has_tag(&"special_chunk_occupied"):
		return
	node.add_tag(&"near_special_chunk")
	node.add_tag(&"special_chunk_gateway")
	node.add_tag(StringName("gateway_%s" % str(placement.chunk_def.id)))
	node.special_chunk_id = placement.chunk_def.id
	node.special_chunk_origin = placement.origin_chunk
	node.special_chunk_size = placement.size_in_chunks
	node.special_chunk_gateway_side = side_to_special
	node.set_connection(side_to_special, true)
	if node.chunk_type == BiomeMap.ChunkType.SOLID:
		node.chunk_type = BiomeMap.ChunkType.BRANCH

func _special_profile_slice_has_open(profile: Array[int], local_chunk_index: int, slots_per_chunk: int) -> bool:
	var start: int = local_chunk_index * slots_per_chunk
	var end: int = mini(start + slots_per_chunk, profile.size())
	for i: int in range(start, end):
		var socket: PieceSocket.Socket = PieceSocket.from_value(profile[i])
		if PieceSocket.is_open(socket):
			return true
	return false
