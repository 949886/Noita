@tool
class_name SpecialChunkNode
extends Node2D

# Base node for editable SpecialChunk scenes.
# The Ground TileMapLayer is authored in the editor. Demo layouts only populate an empty
# example scene, and the optional transition auto-fill only writes into empty edge cells.

enum DemoLayout {
	NONE,
	MINE_TREASURE_1X1,
	ANCIENT_HALL_2X1,
	SNOW_SHRINE_1X1,
	CRYSTAL_GROTTO_1X1,
}

const SPECIAL_CHUNK_SOURCE_ID: int = TileConstants.SOURCE_SPECIAL_CHUNK
const CRYSTAL_SPECIAL_SOURCE_ID: int = TileConstants.SOURCE_CRYSTAL_GROTTO
const COMMON_SOURCE_ID: int = TileConstants.SOURCE_COMMON
const TILE_COMMON_AIR: Vector2i = TileConstants.COMMON_AIR_COORDS
const TILE_WALL: Vector2i = Vector2i(0, 0)
const TILE_FLOOR: Vector2i = Vector2i(0, 1)
const TILE_PLATFORM: Vector2i = Vector2i(0, 2)
const TILE_DOOR: Vector2i = Vector2i(0, 3)
const TILE_PILLAR: Vector2i = Vector2i(0, 4)
const TILE_BACKGROUND: Vector2i = Vector2i(0, 5)
const TILE_DECORATION: Vector2i = Vector2i(0, 6)
const TILE_DEBUG: Vector2i = Vector2i(0, TileConstants.SPECIAL_DEBUG_ROW)

@export var ground_layer_path: NodePath = ^"Ground"
@export var debug_label_path: NodePath = ^"DebugLabel"
@export var chunk_tile_set: TileSet
@export var sync_tile_set_in_editor: bool = true
@export var show_debug_label: bool = true
@export_enum("None", "Mine Treasure 1x1", "Ancient Hall 2x1 Chunk", "Snow Shrine 1x1", "Crystal Grotto 1x1") var demo_layout: int = DemoLayout.NONE
@export var populate_demo_layout_if_empty: bool = true
@export var auto_fill_transition_border: bool = true
# Authored tiles can come from the default SpecialChunk atlas (10) or a dedicated
# test atlas (11). Environment fill always uses the surrounding biome source.
@export var authored_source_id: int = SPECIAL_CHUNK_SOURCE_ID

var last_environment_fill_count: int = 0

var placement: SpecialChunkPlacement
var chunk_def: SpecialChunkDef

func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_authored_tile_set(chunk_tile_set)
		_populate_demo_layout_if_needed()

func setup_chunk(p_placement: SpecialChunkPlacement, tile_set: TileSet) -> void:
	placement = p_placement
	chunk_def = placement.chunk_def
	_sync_authored_tile_set(tile_set)
	_populate_demo_layout_if_needed()
	_apply_auto_fill_if_needed()
	_update_debug_label()

func _sync_authored_tile_set(tile_set: TileSet) -> void:
	var layer: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	if layer == null:
		return
	if tile_set != null:
		layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _populate_demo_layout_if_needed() -> void:
	if not populate_demo_layout_if_empty:
		return
	if demo_layout == DemoLayout.NONE:
		return
	var layer: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	if layer == null:
		return
	# Do not overwrite authored cells.
	if not layer.get_used_cells().is_empty():
		return
	match demo_layout:
		DemoLayout.MINE_TREASURE_1X1:
			_draw_mine_treasure_chunk(layer)
		DemoLayout.ANCIENT_HALL_2X1:
			_draw_ancient_hall(layer)
		DemoLayout.SNOW_SHRINE_1X1:
			_draw_snow_shrine_chunk(layer)
		DemoLayout.CRYSTAL_GROTTO_1X1:
			_draw_crystal_grotto_chunk(layer)

func _set_tile(layer: TileMapLayer, cell: Vector2i, atlas_coords: Vector2i) -> void:
	layer.set_cell(cell, authored_source_id, atlas_coords, 0)

func _set_tile_from_source(layer: TileMapLayer, cell: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	layer.set_cell(cell, source_id, atlas_coords, 0)

func _set_tile_if_empty(layer: TileMapLayer, cell: Vector2i, atlas_coords: Vector2i) -> void:
	if layer.get_cell_source_id(cell) != -1:
		return
	_set_tile(layer, cell, atlas_coords)

func _fill_rect(layer: TileMapLayer, rect: Rect2i, atlas_coords: Vector2i) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_set_tile(layer, Vector2i(x, y), atlas_coords)

func _draw_chunk_frame(layer: TileMapLayer, width: int, height: int, side_doors: bool, style: int) -> void:
	_fill_rect(layer, Rect2i(0, 0, width, height), TILE_BACKGROUND)
	for x: int in range(width):
		_set_tile(layer, Vector2i(x, 0), _transition_coords(style, SpecialChunkTransitionLookup.Usage.WALL, SpecialChunkTransitionLookup.Direction.TOP))
		_set_tile(layer, Vector2i(x, height - 1), _transition_coords(style, SpecialChunkTransitionLookup.Usage.WALL, SpecialChunkTransitionLookup.Direction.BOTTOM))
	for y: int in range(height):
		_set_tile(layer, Vector2i(0, y), _transition_coords(style, SpecialChunkTransitionLookup.Usage.WALL, SpecialChunkTransitionLookup.Direction.LEFT))
		_set_tile(layer, Vector2i(width - 1, y), _transition_coords(style, SpecialChunkTransitionLookup.Usage.WALL, SpecialChunkTransitionLookup.Direction.RIGHT))
	# Inner wall ring makes the transition border read as broken cave-to-structure material.
	for x: int in range(1, width - 1):
		_set_tile(layer, Vector2i(x, 1), TILE_WALL)
		_set_tile(layer, Vector2i(x, height - 2), TILE_WALL)
	for y: int in range(1, height - 1):
		_set_tile(layer, Vector2i(1, y), TILE_WALL)
		_set_tile(layer, Vector2i(width - 2, y), TILE_WALL)
	if side_doors:
		var mid_y: int = floori(float(height) / 2.0)
		for dy: int in [-1, 0]:
			_set_tile(layer, Vector2i(0, mid_y + dy), _transition_coords(style, SpecialChunkTransitionLookup.Usage.DOOR, SpecialChunkTransitionLookup.Direction.LEFT))
			_set_tile(layer, Vector2i(1, mid_y + dy), TILE_DOOR)
			_set_tile(layer, Vector2i(width - 1, mid_y + dy), _transition_coords(style, SpecialChunkTransitionLookup.Usage.DOOR, SpecialChunkTransitionLookup.Direction.RIGHT))
			_set_tile(layer, Vector2i(width - 2, mid_y + dy), TILE_DOOR)

func _draw_mine_treasure_chunk(layer: TileMapLayer) -> void:
	var width: int = TileConstants.TILES_PER_CHUNK
	var height: int = TileConstants.TILES_PER_CHUNK
	_draw_chunk_frame(layer, width, height, true, SpecialChunkDef.TransitionStyle.ROCK)
	for x: int in range(2, 6):
		_set_tile(layer, Vector2i(x, 5), TILE_FLOOR)
	_set_tile(layer, Vector2i(3, 4), TILE_PLATFORM)
	_set_tile(layer, Vector2i(4, 4), TILE_PLATFORM)
	_set_tile(layer, Vector2i(3, 3), TILE_DECORATION)
	_set_tile(layer, Vector2i(4, 3), TILE_DECORATION)
	_set_tile(layer, Vector2i(2, 2), TILE_PILLAR)
	_set_tile(layer, Vector2i(5, 2), TILE_PILLAR)
	_update_debug_label()

func _draw_ancient_hall(layer: TileMapLayer) -> void:
	var width: int = TileConstants.TILES_PER_CHUNK * 2
	var height: int = TileConstants.TILES_PER_CHUNK
	_draw_chunk_frame(layer, width, height, true, SpecialChunkDef.TransitionStyle.RUINS)
	for x: int in range(1, width - 1):
		_set_tile(layer, Vector2i(x, 6), TILE_FLOOR)
	for x: int in range(6, 10):
		_set_tile(layer, Vector2i(x, 4), TILE_PLATFORM)
	_set_tile(layer, Vector2i(7, 3), TILE_DECORATION)
	_set_tile(layer, Vector2i(8, 3), TILE_DECORATION)
	for y: int in range(2, 6):
		_set_tile(layer, Vector2i(3, y), TILE_PILLAR)
		_set_tile(layer, Vector2i(12, y), TILE_PILLAR)
	_set_tile(layer, Vector2i(1, 3), TILE_DOOR)
	_set_tile(layer, Vector2i(width - 2, 3), TILE_DOOR)
	_update_debug_label()

func _draw_snow_shrine_chunk(layer: TileMapLayer) -> void:
	var width: int = TileConstants.TILES_PER_CHUNK
	var height: int = TileConstants.TILES_PER_CHUNK
	_draw_chunk_frame(layer, width, height, true, SpecialChunkDef.TransitionStyle.SNOW)
	for x: int in range(2, 6):
		_set_tile(layer, Vector2i(x, 5), TILE_FLOOR)
	_set_tile(layer, Vector2i(3, 3), TILE_DECORATION)
	_set_tile(layer, Vector2i(4, 3), TILE_DECORATION)
	_set_tile(layer, Vector2i(3, 4), TILE_PLATFORM)
	_set_tile(layer, Vector2i(4, 4), TILE_PLATFORM)
	_set_tile(layer, Vector2i(2, 2), TILE_PILLAR)
	_set_tile(layer, Vector2i(5, 2), TILE_PILLAR)
	_update_debug_label()

func _draw_crystal_grotto_chunk(layer: TileMapLayer) -> void:
	# Common air explicitly marks the continuous room interior. Empty cells outside
	# this authored air mask are still filled by ENVIRONMENT_WANG_FILL with the
	# surrounding biome Wang tiles. This keeps the room readable while the edges
	# remain naturally embedded in the cave.
	for y: int in range(2, 7):
		for x: int in range(1, 7):
			_set_tile_from_source(layer, Vector2i(x, y), COMMON_SOURCE_ID, TILE_COMMON_AIR)
	# Leave a little irregularity so the air mask does not become a perfect card.
	var air_mask_holes: Array[Vector2i] = [Vector2i(1, 2), Vector2i(6, 2), Vector2i(1, 6), Vector2i(6, 6)]
	for cell: Vector2i in air_mask_holes:
		layer.erase_cell(cell)

	var old_source_id: int = authored_source_id
	authored_source_id = CRYSTAL_SPECIAL_SOURCE_ID
	# Solid anchors and floor pieces remain Ground tiles because they should affect
	# the environment fill. Only the core is a separate interactive Node.
	_set_tile(layer, Vector2i(2, 4), TILE_PILLAR)
	_set_tile(layer, Vector2i(5, 4), TILE_PILLAR)
	_set_tile(layer, Vector2i(3, 4), TILE_WALL)
	_set_tile(layer, Vector2i(4, 4), TILE_WALL)
	_set_tile(layer, Vector2i(3, 5), TILE_FLOOR)
	_set_tile(layer, Vector2i(4, 5), TILE_FLOOR)
	# Sparse environment decoration tiles remain on Ground. They have open-like
	# edge metadata and transparent art, so they do not seal the room.
	_set_tile(layer, Vector2i(2, 3), TILE_BACKGROUND)
	_set_tile(layer, Vector2i(5, 3), TILE_BACKGROUND)
	_set_tile(layer, Vector2i(2, 6), TILE_DECORATION)
	_set_tile(layer, Vector2i(5, 6), TILE_DECORATION)
	authored_source_id = old_source_id
	_update_debug_label()

func _apply_auto_fill_if_needed() -> void:
	last_environment_fill_count = 0
	if chunk_def == null:
		return
	match chunk_def.fill_mode:
		SpecialChunkDef.FillMode.NONE:
			return
		SpecialChunkDef.FillMode.TRANSITION_BORDER:
			_auto_fill_transition_border_if_needed()
		SpecialChunkDef.FillMode.ENVIRONMENT_WANG_FILL:
			_auto_fill_environment_wang_if_needed()

func _auto_fill_transition_border_if_needed() -> void:
	if not auto_fill_transition_border:
		return
	var layer: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	if layer == null:
		return
	var width: int = chunk_def.size_in_chunks.x * TileConstants.TILES_PER_CHUNK
	var height: int = chunk_def.size_in_chunks.y * TileConstants.TILES_PER_CHUNK
	_fill_horizontal_transition(layer, 0, width, chunk_def.top_profile, SpecialChunkTransitionLookup.Direction.TOP)
	_fill_horizontal_transition(layer, height - 1, width, chunk_def.bottom_profile, SpecialChunkTransitionLookup.Direction.BOTTOM)
	_fill_vertical_transition(layer, 0, height, chunk_def.left_profile, SpecialChunkTransitionLookup.Direction.LEFT)
	_fill_vertical_transition(layer, width - 1, height, chunk_def.right_profile, SpecialChunkTransitionLookup.Direction.RIGHT)

func _auto_fill_environment_wang_if_needed() -> void:
	var layer: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	if layer == null:
		return
	last_environment_fill_count = SpecialChunkEnvironmentFill.fill_empty_cells(layer, chunk_def, placement)

func _fill_horizontal_transition(layer: TileMapLayer, y: int, length: int, profile: Array[int], direction: int) -> void:
	# Skip corners; corner art is more art-directed and is best hand-authored.
	for x: int in range(1, maxi(1, length - 1)):
		var edge_value: int = TileDef.Edge.SOLID
		if x < profile.size():
			edge_value = profile[x]
		var usage: int = SpecialChunkTransitionLookup.usage_for_edge(edge_value)
		_set_tile_if_empty(layer, Vector2i(x, y), _transition_coords(chunk_def.transition_style, usage, direction))

func _fill_vertical_transition(layer: TileMapLayer, x: int, length: int, profile: Array[int], direction: int) -> void:
	# Skip corners; corner art is more art-directed and is best hand-authored.
	for y: int in range(1, maxi(1, length - 1)):
		var edge_value: int = TileDef.Edge.SOLID
		if y < profile.size():
			edge_value = profile[y]
		var usage: int = SpecialChunkTransitionLookup.usage_for_edge(edge_value)
		_set_tile_if_empty(layer, Vector2i(x, y), _transition_coords(chunk_def.transition_style, usage, direction))

func _transition_coords(style: int, usage: int, direction: int) -> Vector2i:
	return SpecialChunkTransitionLookup.coords(style, usage, direction)

func _update_debug_label() -> void:
	var label: Label = get_node_or_null(debug_label_path) as Label
	if label == null:
		return
	label.visible = show_debug_label
	if not show_debug_label:
		return
	if chunk_def != null:
		var text: String = str(chunk_def.display_name)
		if chunk_def.fill_mode == SpecialChunkDef.FillMode.ENVIRONMENT_WANG_FILL:
			text += "\nfill env-wang: %d" % last_environment_fill_count
		elif chunk_def.fill_mode == SpecialChunkDef.FillMode.TRANSITION_BORDER:
			text += "\nfill transition"
		label.text = text
	elif name != "":
		label.text = name
