class_name ChunkNode
extends Node2D

# Compatibility wrapper for code that still wants a chunk node. Runtime rendering
# now uses PieceChunkRenderer directly.
var coord: Vector2i
var data: PieceChunkData

func setup(p_data: PieceChunkData, chunk_pixel_size: int) -> void:
	data = p_data
	coord = data.coord
	position = Vector2(coord.x * chunk_pixel_size, coord.y * chunk_pixel_size)
	name = "Chunk_%d_%d_%s_%s" % [coord.x, coord.y, data.biome_id, BiomeMap.chunk_type_name(data.chunk_type)]
