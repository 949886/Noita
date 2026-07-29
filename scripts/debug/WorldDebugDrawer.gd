class_name WorldDebugDrawer
extends Node2D

# Project-2 debug renderer adapted to the piece/socket world.

const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS

@export var show_chunk_bounds: bool = true
@export var show_socket_profiles: bool = true
@export var show_chunk_labels: bool = true
@export var show_piece_bounds: bool = true

var world_manager: Node = null

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if world_manager == null:
		return
	var loaded: Dictionary = world_manager.loaded_chunks
	for coord: Vector2i in loaded.keys():
		var data: PieceChunkData = loaded.get(coord, null) as PieceChunkData
		if data == null:
			continue
		var origin: Vector2 = Vector2(coord * CHUNK_SIZE)
		var rect := Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE))
		var base_color := _color_for_chunk(data)
		if show_chunk_bounds:
			var fill_alpha: float = 0.08
			var line_width: float = 2.0
			if data.chunk_type == BiomeMap.ChunkType.CHAMBER:
				fill_alpha = 0.14
				line_width = 3.0
			draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, fill_alpha), true)
			draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, 0.78), false, line_width)
		if show_piece_bounds:
			_draw_piece_bounds(data, origin)
		if show_socket_profiles:
			_draw_profiles(data, origin)
		if show_chunk_labels:
			_draw_chunk_label(data, origin, base_color)
	_draw_special_chunk_placements()

func _draw_special_chunk_placements() -> void:
	if world_manager == null or not show_chunk_bounds:
		return
	var planner: SpecialChunkPlanner = world_manager.special_chunk_planner as SpecialChunkPlanner
	if planner == null:
		return
	var font: Font = ThemeDB.fallback_font
	for placement: SpecialChunkPlacement in planner.placements:
		if placement == null or placement.chunk_def == null:
			continue
		var origin := Vector2(placement.origin_chunk * CHUNK_SIZE)
		var size := Vector2(placement.size_in_chunks * CHUNK_SIZE)
		var rect := Rect2(origin, size)
		draw_rect(rect, Color(0.95, 0.45, 1.0, 0.12), true)
		draw_rect(rect, Color(1.0, 0.55, 1.0, 0.95), false, 4.0)
		if show_chunk_labels and font != null:
			draw_string(font, origin + Vector2(12, 18), "SP %s" % str(placement.chunk_def.id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.86, 1.0, 0.95))

func _color_for_chunk(data: PieceChunkData) -> Color:
	if data == null:
		return Color(0.90, 0.60, 1.00, 1.0)
	match data.chunk_type:
		BiomeMap.ChunkType.MAIN_PATH:
			return Color(0.40, 0.90, 1.00, 1.0)
		BiomeMap.ChunkType.CAVE:
			return Color(0.55, 0.80, 0.55, 1.0)
		BiomeMap.ChunkType.BRANCH:
			return Color(0.90, 0.78, 0.35, 1.0)
		BiomeMap.ChunkType.CHAMBER:
			return Color(0.25, 1.00, 0.85, 1.0)
		BiomeMap.ChunkType.SOLID:
			return Color(0.75, 0.75, 0.75, 1.0)
		BiomeMap.ChunkType.SPECIAL:
			return Color(0.95, 0.55, 1.00, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _draw_piece_bounds(data: PieceChunkData, origin: Vector2) -> void:
	for placement: PiecePlacement in data.placements:
		var rect: Rect2i = placement.pixel_rect(UNIT_SIZE)
		var color: Color = _phase_color(placement.phase)
		draw_rect(Rect2(origin + Vector2(rect.position), Vector2(rect.size)), color, false, 1.5)

func _phase_color(phase: StringName) -> Color:
	match phase:
		&"anchor":
			return Color(1.0, 0.25, 0.25, 0.78)
		&"regular":
			return Color(0.35, 1.0, 0.45, 0.68)
		&"glue":
			return Color(1.0, 0.65, 0.1, 0.68)
		_:
			return Color(0.8, 0.8, 0.8, 0.6)

func _draw_profiles(data: PieceChunkData, origin: Vector2) -> void:
	for i: int in range(UNITS_PER_CHUNK):
		var center_x: float = origin.x + i * UNIT_SIZE + UNIT_SIZE * 0.5
		var center_y: float = origin.y + i * UNIT_SIZE + UNIT_SIZE * 0.5
		_draw_socket_marker(Vector2(center_x, origin.y + 8), data.top_profile[i] if i < data.top_profile.size() else PieceSocket.SOLID)
		_draw_socket_marker(Vector2(origin.x + CHUNK_SIZE - 8, center_y), data.right_profile[i] if i < data.right_profile.size() else PieceSocket.SOLID)
		_draw_socket_marker(Vector2(center_x, origin.y + CHUNK_SIZE - 8), data.bottom_profile[i] if i < data.bottom_profile.size() else PieceSocket.SOLID)
		_draw_socket_marker(Vector2(origin.x + 8, center_y), data.left_profile[i] if i < data.left_profile.size() else PieceSocket.SOLID)

func _draw_socket_marker(pos: Vector2, socket_value: int) -> void:
	var socket: PieceSocket.Socket = PieceSocket.from_value(socket_value)
	var color := Color(0.9, 0.9, 0.9, 0.30)
	var radius := 3.0
	match socket:
		PieceSocket.OPEN_SMALL:
			color = Color(0.35, 1.0, 0.55, 0.88)
			radius = 4.5
		PieceSocket.DOUBLE_OPEN_SMALL:
			color = Color(0.35, 0.8, 1.0, 0.88)
			radius = 5.0
		PieceSocket.OPEN_MEDIUM:
			color = Color(0.2, 0.95, 0.75, 0.90)
			radius = 6.0
		PieceSocket.OPEN_LARGE, PieceSocket.ROOM:
			color = Color(1.0, 0.75, 0.25, 0.92)
			radius = 7.5
		PieceSocket.SHAFT:
			color = Color(0.8, 0.55, 1.0, 0.90)
			radius = 5.5
		PieceSocket.SOLID:
			color = Color(1.0, 1.0, 1.0, 0.22)
			radius = 2.5
	draw_circle(pos, radius, color)

func _draw_chunk_label(data: PieceChunkData, origin: Vector2, color: Color) -> void:
	var chamber_line: String = ""
	if data.chamber_id != &"":
		chamber_line = "\n%s %s pieces %d/glue %d" % [str(data.chamber_id), str(data.chamber_size), data.piece_count, data.used_glue_count]
	var special_line: String = ""
	if data.special_chunk_id != &"":
		if data.special_chunk_gateway_side != &"":
			special_line = "\nGW %s -> %s" % [str(data.special_chunk_gateway_side), str(data.special_chunk_id)]
		else:
			special_line = "\nSP %s" % str(data.special_chunk_id)
	var text := "%s\n%s/%s\n%s%s%s\npieces %d  glue %d  sockets %d" % [
		str(data.coord),
		str(data.biome_id),
		BiomeMap.chunk_type_name(data.chunk_type),
		data.structure_tag_string(),
		chamber_line,
		special_line,
		data.piece_count,
		data.used_glue_count,
		data.compatible_match_tiles,
	]
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var bg_height: float = 66.0
	if data.chamber_id != &"":
		bg_height += 16.0
	if data.special_chunk_id != &"":
		bg_height += 16.0
	var bg_rect := Rect2(origin + Vector2(8, 8), Vector2(210, bg_height))
	draw_rect(bg_rect, Color(0.02, 0.025, 0.035, 0.62), true)
	draw_rect(bg_rect, Color(color.r, color.g, color.b, 0.42), false, 1.0)
	draw_multiline_string(font, origin + Vector2(14, 22), text, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 11, 11, Color(0.88, 0.94, 1.0, 0.92))

func toggle_visible() -> void:
	visible = not visible
