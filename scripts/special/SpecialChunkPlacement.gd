class_name SpecialChunkPlacement
extends RefCounted

# Runtime placement of one SpecialChunkDef in chunk coordinates.
# Multi-chunk structures use one placement and mark every occupied chunk in the planner.
var id: StringName = &""
var chunk_def: SpecialChunkDef
var origin_chunk: Vector2i = Vector2i.ZERO
var size_in_chunks: Vector2i = Vector2i.ONE
var biome_id: StringName = &"mine"
var seed: int = 0

func contains_chunk(coord: Vector2i) -> bool:
	return coord.x >= origin_chunk.x \
		and coord.y >= origin_chunk.y \
		and coord.x < origin_chunk.x + size_in_chunks.x \
		and coord.y < origin_chunk.y + size_in_chunks.y

func intersects_chunk_rect(origin: Vector2i, size: Vector2i) -> bool:
	return origin_chunk.x < origin.x + size.x \
		and origin_chunk.x + size_in_chunks.x > origin.x \
		and origin_chunk.y < origin.y + size.y \
		and origin_chunk.y + size_in_chunks.y > origin.y

func local_chunk_offset(coord: Vector2i) -> Vector2i:
	return coord - origin_chunk
