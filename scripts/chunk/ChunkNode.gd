class_name ChunkNode
extends Node2D

var coord: Vector2i
var data: ChunkData

func setup(p_data: ChunkData, chunk_pixel_size: int) -> void:
	data = p_data
	coord = data.coord
	position = Vector2(coord.x * chunk_pixel_size, coord.y * chunk_pixel_size)
	name = "Chunk_%d_%d_%s_%s" % [coord.x, coord.y, data.biome_id, data.chunk_type]
