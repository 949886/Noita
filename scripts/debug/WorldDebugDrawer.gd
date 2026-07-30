class_name WorldDebugDrawer
extends Node2D

# Project-2 debug renderer adapted to the piece/socket world.

const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const SOCKET_MARKER_RING_RADIUS: float = 7.0
const SOCKET_MARKER_DOT_RADIUS: float = 3.2
const SOCKET_MARKER_RING_WIDTH: float = 2.0

@export var show_chunk_bounds: bool = true
@export var show_socket_profiles: bool = true
@export var show_chunk_labels: bool = true
@export var show_piece_bounds: bool = true
@export_range(0.05, 1.0, 0.05) var redraw_interval: float = 0.15

var world_manager: Node = null
var redraw_accum: float = 999.0

func _process(delta: float) -> void:
	if not visible:
		return
	redraw_accum += delta
	if redraw_accum >= redraw_interval:
		redraw_accum = 0.0
		queue_redraw()

func request_debug_redraw() -> void:
	redraw_accum = redraw_interval
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
		&"seam_repair":
			return Color(1.0, 0.05, 0.05, 0.82)
		_:
			return Color(0.8, 0.8, 0.8, 0.6)

func _draw_profiles(data: PieceChunkData, origin: Vector2) -> void:
	for i: int in range(UNITS_PER_CHUNK):
		var center_x: float = origin.x + i * UNIT_SIZE + UNIT_SIZE * 0.5
		var center_y: float = origin.y + i * UNIT_SIZE + UNIT_SIZE * 0.5
		_draw_profile_marker_pair(Vector2(center_x, origin.y + 16), _socket_at(data.top_profile, i), _socket_at(data.actual_top_profile, i), Rect2(origin + Vector2(i * UNIT_SIZE, 0), Vector2(UNIT_SIZE, 20)))
		_draw_profile_marker_pair(Vector2(origin.x + CHUNK_SIZE - 16, center_y), _socket_at(data.right_profile, i), _socket_at(data.actual_right_profile, i), Rect2(origin + Vector2(CHUNK_SIZE - 20, i * UNIT_SIZE), Vector2(20, UNIT_SIZE)))
		_draw_profile_marker_pair(Vector2(center_x, origin.y + CHUNK_SIZE - 16), _socket_at(data.bottom_profile, i), _socket_at(data.actual_bottom_profile, i), Rect2(origin + Vector2(i * UNIT_SIZE, CHUNK_SIZE - 20), Vector2(UNIT_SIZE, 20)))
		_draw_profile_marker_pair(Vector2(origin.x + 16, center_y), _socket_at(data.left_profile, i), _socket_at(data.actual_left_profile, i), Rect2(origin + Vector2(0, i * UNIT_SIZE), Vector2(20, UNIT_SIZE)))

func _socket_at(profile: Array[PieceSocket.Socket], index: int) -> PieceSocket.Socket:
	if index >= 0 and index < profile.size():
		return PieceSocket.from_value(profile[index])
	return PieceSocket.SOLID

func _draw_profile_marker_pair(marker_pos: Vector2, expected: PieceSocket.Socket, actual: PieceSocket.Socket, edge_rect: Rect2) -> void:
	if actual != expected:
		draw_rect(edge_rect, Color(1.0, 0.05, 0.05, 0.42), true)
	_draw_expected_socket_ring(marker_pos, expected)
	_draw_actual_socket_dot(marker_pos, actual)

func _socket_color(socket_value: int) -> Color:
	var socket: PieceSocket.Socket = PieceSocket.from_value(socket_value)
	match socket:
		PieceSocket.OPEN_SMALL:
			return Color(0.35, 1.0, 0.55, 0.92)
		PieceSocket.DOUBLE_OPEN_SMALL:
			return Color(0.35, 0.8, 1.0, 0.92)
		PieceSocket.OPEN_MEDIUM:
			return Color(0.2, 0.95, 0.75, 0.94)
		PieceSocket.OPEN_LARGE:
			return Color(1.0, 0.75, 0.25, 0.95)
		PieceSocket.ANY:
			return Color(1.0, 1.0, 1.0, 0.68)
		PieceSocket.SOLID:
			return Color(1.0, 1.0, 1.0, 0.30)
	return Color(0.9, 0.9, 0.9, 0.35)

func _draw_expected_socket_ring(pos: Vector2, socket_value: int) -> void:
	var color: Color = _socket_color(socket_value)
	draw_arc(pos, SOCKET_MARKER_RING_RADIUS, 0.0, TAU, 32, color, SOCKET_MARKER_RING_WIDTH, true)

func _draw_actual_socket_dot(pos: Vector2, socket_value: int) -> void:
	var color: Color = _socket_color(socket_value)
	draw_circle(pos, SOCKET_MARKER_DOT_RADIUS, color)

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
	var text := "%s\n%s/%s\n%s%s%s\npieces %d  glue %d  repairs %d  broken %d" % [
		str(data.coord),
		str(data.biome_id),
		BiomeMap.chunk_type_name(data.chunk_type),
		data.structure_tag_string(),
		chamber_line,
		special_line,
		data.piece_count,
		data.used_glue_count,
		data.seam_repair_count,
		data.seam_broken_count,
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
