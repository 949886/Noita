class_name WorldStructureNode
extends RefCounted

# One low-resolution structure cell. A node maps to one streamed world chunk.
# It stores the intended macro role before piece-level generation runs.

var coord: Vector2i = Vector2i.ZERO
var biome_id: StringName = &"mine"
var chunk_type: int = BiomeMap.ChunkType.SOLID
var structure_tags: Array[StringName] = []
var intended_connections: Dictionary = {
	&"top": false,
	&"right": false,
	&"bottom": false,
	&"left": false,
}
# Chamber metadata lets the piece generator treat a multi-chunk chamber as one
# continuous cave instead of carving each chunk as an isolated small room.
var chamber_id: StringName = &""
var chamber_origin: Vector2i = Vector2i.ZERO
var chamber_size: Vector2i = Vector2i.ONE

# SpecialChunk integration metadata. Occupied nodes are skipped by normal terrain
# streaming; gateway nodes are ordinary chunks that must carve a path to an authored entrance.
var special_chunk_id: StringName = &""
var special_chunk_origin: Vector2i = Vector2i.ZERO
var special_chunk_size: Vector2i = Vector2i.ONE
var special_chunk_gateway_side: StringName = &""

func _init(p_coord: Vector2i = Vector2i.ZERO, p_biome_id: StringName = &"mine", p_chunk_type: int = BiomeMap.ChunkType.SOLID) -> void:
	coord = p_coord
	biome_id = p_biome_id
	chunk_type = p_chunk_type

func add_tag(tag: StringName) -> void:
	if not structure_tags.has(tag):
		structure_tags.append(tag)

func has_tag(tag: StringName) -> bool:
	return structure_tags.has(tag)

func set_connection(side: StringName, enabled: bool = true) -> void:
	intended_connections[side] = enabled

func has_connection(side: StringName) -> bool:
	return bool(intended_connections.get(side, false))

func is_chamber() -> bool:
	return chamber_id != &"" or has_tag(&"chamber")

func is_special_chunk_occupied() -> bool:
	return special_chunk_id != &"" and has_tag(&"special_chunk_occupied")

func is_special_chunk_gateway() -> bool:
	return special_chunk_id != &"" and has_tag(&"special_chunk_gateway")

func is_same_chamber(other: WorldStructureNode) -> bool:
	return other != null and chamber_id != &"" and chamber_id == other.chamber_id

func tag_string() -> String:
	if structure_tags.is_empty():
		return "none"
	var parts: Array[String] = []
	for tag: StringName in structure_tags:
		parts.append(str(tag))
	return ",".join(parts)
