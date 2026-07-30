class_name PieceChunkData
extends RefCounted

var coord: Vector2i = Vector2i.ZERO
var biome_id: StringName = &"mine"
var chunk_type: int = BiomeMap.ChunkType.CAVE
var structure_tags: Array[StringName] = []
var structure_source: String = "fallback"
var intended_connection_count: int = 0

var top_profile: Array[PieceSocket.Socket] = []
var right_profile: Array[PieceSocket.Socket] = []
var bottom_profile: Array[PieceSocket.Socket] = []
var left_profile: Array[PieceSocket.Socket] = []

# Actual profiles are computed after piece placement and seam repair.
# Expected profiles are the canonical WorldSeamRegistry contract; actual profiles
# describe what the rendered/material image now exposes at the chunk edge.
var actual_top_profile: Array[PieceSocket.Socket] = []
var actual_right_profile: Array[PieceSocket.Socket] = []
var actual_bottom_profile: Array[PieceSocket.Socket] = []
var actual_left_profile: Array[PieceSocket.Socket] = []
var seam_issue_count: int = 0
var seam_repair_count: int = 0
var seam_exact_count: int = 0
var seam_compatible_count: int = 0
var seam_broken_count: int = 0
var seam_repairs: Array[Dictionary] = []

var visual_image: Image
var material_image: Image
var texture: ImageTexture
var placements: Array[PiecePlacement] = []
var used_glue_count: int = 0
var piece_count: int = 0
var regular_piece_count: int = 0
var fallback_tiles: int = 0
var compatible_match_tiles: int = 0
var exact_match_tiles: int = 0

var air_tile_count: int = 0
var air_pocket_count: int = 0
var connectivity_adjusted: bool = false
var open_side_count: int = 0
var chamber_id: StringName = &""
var chamber_origin: Vector2i = Vector2i.ZERO
var chamber_size: Vector2i = Vector2i.ONE
var chamber_carve_air_tiles: int = 0
var chamber_carve_open_tiles: int = 0
var connectivity_path_tiles: int = 0
var connected_open_sides: int = 0
var special_chunk_id: StringName = &""
var special_chunk_origin: Vector2i = Vector2i.ZERO
var special_chunk_size: Vector2i = Vector2i.ONE
var special_chunk_gateway_side: StringName = &""

func chunk_type_name() -> String:
	return BiomeMap.chunk_type_name(chunk_type)

func structure_tag_string() -> String:
	if structure_tags.is_empty():
		return structure_source
	var parts: Array[String] = []
	for tag: StringName in structure_tags:
		parts.append(str(tag))
	return ",".join(parts)

func tag_string() -> String:
	return structure_tag_string()

func _init(p_coord: Vector2i = Vector2i.ZERO) -> void:
	coord = p_coord

func placement_at_unit(unit: Vector2i) -> PiecePlacement:
	# Search newest first so seam-repair glue overlays take precedence over
	# earlier multi-unit pieces that occupied the same 128px unit.
	for i: int in range(placements.size() - 1, -1, -1):
		var placement: PiecePlacement = placements[i]
		var rect: Rect2i = Rect2i(placement.unit_pos, placement.size_units)
		if rect.has_point(unit):
			return placement
	return null


func profile_for_side(side: StringName, actual: bool = false) -> Array[PieceSocket.Socket]:
	if actual:
		match side:
			&"top":
				return actual_top_profile
			&"right":
				return actual_right_profile
			&"bottom":
				return actual_bottom_profile
			&"left":
				return actual_left_profile
	else:
		match side:
			&"top":
				return top_profile
			&"right":
				return right_profile
			&"bottom":
				return bottom_profile
			&"left":
				return left_profile
	var empty: Array[PieceSocket.Socket] = []
	return empty

func set_actual_profile(side: StringName, profile: Array[PieceSocket.Socket]) -> void:
	match side:
		&"top":
			actual_top_profile = profile
		&"right":
			actual_right_profile = profile
		&"bottom":
			actual_bottom_profile = profile
		&"left":
			actual_left_profile = profile
