class_name ChunkData
extends RefCounted

var coord: Vector2i
var biome_id: StringName = &"mine"
var chunk_type: int = BiomeMap.ChunkType.CAVE
var tiles: Array = []
var top_profile: Array[int] = []
var right_profile: Array[int] = []
var bottom_profile: Array[int] = []
var left_profile: Array[int] = []
var fallback_tiles: int = 0
var compatible_match_tiles: int = 0
var exact_match_tiles: int = 0
# Number of tiles upgraded to AAAA by AirPocketPass. Useful for tuning pocket frequency.
var air_tile_count: int = 0
var air_pocket_count: int = 0
var connectivity_adjusted: bool = false
var open_side_count: int = 0
var structure_tags: Array = []
var structure_source: String = "fallback"
var intended_connection_count: int = 0
var chamber_id: StringName = &""
var chamber_origin: Vector2i = Vector2i.ZERO
var chamber_size: Vector2i = Vector2i.ONE
var chamber_carve_air_tiles: int = 0
var chamber_carve_open_tiles: int = 0
# Number of cells opened by ChunkConnectivityCarvePass to connect entrances on different chunk sides.
var connectivity_path_tiles: int = 0
var connected_open_sides: int = 0

func chunk_type_name() -> String:
	return BiomeMap.chunk_type_name(chunk_type)

func structure_tag_string() -> String:
	if structure_tags.is_empty():
		return structure_source
	var parts: Array[String] = []
	for tag in structure_tags:
		parts.append(str(tag))
	return ",".join(parts)

func _init(p_coord: Vector2i = Vector2i.ZERO) -> void:
	coord = p_coord

func tile_at(x: int, y: int) -> TileDef:
	return tiles[y * 8 + x] as TileDef
