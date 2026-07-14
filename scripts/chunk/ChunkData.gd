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

func _init(p_coord: Vector2i = Vector2i.ZERO) -> void:
	coord = p_coord

func tile_at(x: int, y: int) -> TileDef:
	return tiles[y * 8 + x] as TileDef
