class_name PieceChunkData
extends RefCounted

var coord: Vector2i = Vector2i.ZERO
var biome_id: StringName = &"mine"
var chunk_type: StringName = &"cave"
var structure_tags: Array[StringName] = []
var visual_image: Image
var material_image: Image
var texture: ImageTexture
var placements: Array[PiecePlacement] = []
var used_glue_count: int = 0
var piece_count: int = 0

func tag_string() -> String:
	var parts: Array[String] = []
	for tag: StringName in structure_tags:
		parts.append(str(tag))
	return ",".join(parts)
