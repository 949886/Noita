class_name WorldDebugDrawer
extends Node2D

# World-space debug renderer for chunk streaming and edge-profile inspection.
# It draws lightweight overlays only; it never changes generated world data.

const CHUNK_SIZE: int = TileConstants.CHUNK_SIZE
const TILE_SIZE: int = TileConstants.TILE_SIZE
const TILES_PER_CHUNK: int = TileConstants.TILES_PER_CHUNK

@export var show_chunk_bounds: bool = true
@export var show_edge_profiles: bool = true
@export var show_chunk_labels: bool = true

var world_manager: Node = null

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if world_manager == null:
		return
	var loaded: Dictionary = world_manager.loaded_chunks
	for coord: Vector2i in loaded.keys():
		var data: ChunkData = loaded.get(coord, null) as ChunkData
		var origin := Vector2(coord.x * CHUNK_SIZE, coord.y * CHUNK_SIZE)
		var rect := Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE))
		var base_color := _color_for_chunk(data)
		if show_chunk_bounds:
			var fill_alpha: float = 0.08
			var line_width: float = 2.0
			if data != null and data.chunk_type == BiomeMap.ChunkType.CHAMBER:
				fill_alpha = 0.14
				line_width = 3.0
			draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, fill_alpha), true)
			draw_rect(rect, Color(base_color.r, base_color.g, base_color.b, 0.78), false, line_width)
		if data != null and show_edge_profiles:
			_draw_profiles(data, origin)
		if data != null and show_chunk_labels:
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
		var origin := Vector2(placement.origin_chunk.x * CHUNK_SIZE, placement.origin_chunk.y * CHUNK_SIZE)
		var size := Vector2(placement.size_in_chunks.x * CHUNK_SIZE, placement.size_in_chunks.y * CHUNK_SIZE)
		var rect := Rect2(origin, size)
		draw_rect(rect, Color(0.95, 0.45, 1.0, 0.12), true)
		draw_rect(rect, Color(1.0, 0.55, 1.0, 0.95), false, 4.0)
		if show_chunk_labels and font != null:
			draw_string(font, origin + Vector2(12, 18), "SC %s" % str(placement.chunk_def.id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.86, 1.0, 0.95))

func _color_for_chunk(data: ChunkData) -> Color:
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

func _draw_profiles(data: ChunkData, origin: Vector2) -> void:
	for i: int in range(TILES_PER_CHUNK):
		var center_x: float = origin.x + i * TILE_SIZE + TILE_SIZE * 0.5
		var center_y: float = origin.y + i * TILE_SIZE + TILE_SIZE * 0.5
		_draw_edge_marker(Vector2(center_x, origin.y + 5), data.top_profile[i] if i < data.top_profile.size() else TileDef.Edge.SOLID)
		_draw_edge_marker(Vector2(origin.x + CHUNK_SIZE - 5, center_y), data.right_profile[i] if i < data.right_profile.size() else TileDef.Edge.SOLID)
		_draw_edge_marker(Vector2(center_x, origin.y + CHUNK_SIZE - 5), data.bottom_profile[i] if i < data.bottom_profile.size() else TileDef.Edge.SOLID)
		_draw_edge_marker(Vector2(origin.x + 5, center_y), data.left_profile[i] if i < data.left_profile.size() else TileDef.Edge.SOLID)

func _draw_edge_marker(pos: Vector2, edge_value: int) -> void:
	var color := Color(0.9, 0.9, 0.9, 0.65)
	var radius := 3.0
	match edge_value:
		TileDef.Edge.OPEN:
			color = Color(0.25, 1.0, 0.55, 0.88)
			radius = 4.5
		TileDef.Edge.AIR:
			color = Color(0.30, 0.75, 1.0, 0.88)
			radius = 5.0
		TileDef.Edge.SOLID:
			color = Color(1.0, 1.0, 1.0, 0.22)
			radius = 2.5
	draw_circle(pos, radius, color)

func _draw_chunk_label(data: ChunkData, origin: Vector2, color: Color) -> void:
	var chamber_line: String = ""
	if data.chamber_id != &"":
		chamber_line = "\n%s %s carve A%d/O%d" % [str(data.chamber_id), str(data.chamber_size), data.chamber_carve_air_tiles, data.chamber_carve_open_tiles]
	var special_line: String = ""
	if data.special_chunk_id != &"":
		if data.special_chunk_gateway_side != &"":
			special_line = "\nGW %s -> %s" % [str(data.special_chunk_gateway_side), str(data.special_chunk_id)]
		else:
			special_line = "\nSC %s" % str(data.special_chunk_id)
	var text := "%s\n%s/%s\n%s%s%s\nair %d  fb %d  path %d" % [
		str(data.coord),
		str(data.biome_id),
		BiomeMap.chunk_type_name(data.chunk_type),
		data.structure_tag_string(),
		chamber_line,
		special_line,
		data.air_tile_count,
		data.fallback_tiles,
		data.connectivity_path_tiles,
	]
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var bg_height: float = 66.0
	if data.chamber_id != &"":
		bg_height += 16.0
	if data.special_chunk_id != &"":
		bg_height += 16.0
	var bg_rect := Rect2(origin + Vector2(8, 8), Vector2(190, bg_height))
	draw_rect(bg_rect, Color(0.02, 0.025, 0.035, 0.62), true)
	draw_rect(bg_rect, Color(color.r, color.g, color.b, 0.42), false, 1.0)
	draw_multiline_string(font, origin + Vector2(14, 22), text, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 11, 11, Color(0.88, 0.94, 1.0, 0.92))

func toggle_visible() -> void:
	visible = not visible
