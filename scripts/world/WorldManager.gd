extends Node2D

# Runtime streaming coordinator. Normal chunks are painted into GroundLayer;
# chunks occupied by SpecialChunks are skipped and instantiated by SpecialChunkManager.

const DEFAULT_CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"
const TILE_SIZE: int = TileConstants.TILE_SIZE
const TILES_PER_CHUNK: int = TileConstants.TILES_PER_CHUNK
const CHUNK_SIZE: int = TileConstants.CHUNK_SIZE

@export var world_gen_config: WorldGenConfig
@export var override_seed: bool = false
@export var world_seed: int = 20260706
@export var use_runtime_generated_fallback: bool = false

var tile_library: TileLibrary
var generator: WorldGenerator
var renderer: ChunkTileMapRenderer
var loaded_chunks: Dictionary = {}
var player: Node2D
var debug_overlay: CanvasLayer
var ground_layer: TileMapLayer
var active_config: WorldGenConfig
var load_radius: int = 2
var special_chunk_planner: SpecialChunkPlanner
var special_chunk_manager: SpecialChunkManager
var special_chunks_parent: Node2D

func _ready() -> void:
	ground_layer = get_node_or_null("GroundLayer") as TileMapLayer
	if ground_layer == null:
		push_error("WorldManager: GroundLayer TileMapLayer node not found.")
		return
	ground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	active_config = _load_config()
	if active_config == null:
		push_error("WorldManager: Unable to load WorldGenConfig.")
		return
	if override_seed:
		active_config.world_seed = world_seed
	world_seed = active_config.world_seed
	load_radius = active_config.load_radius

	tile_library = TileLibrary.new()
	tile_library.load_from_config(active_config)
	if active_config.tile_set == null:
		active_config.tile_set = TileSetBuilder.build_from_config(active_config, active_config.enable_tilemap_collision)
	ground_layer.tile_set = active_config.tile_set

	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map)
	special_chunks_parent = get_node_or_null("SpecialChunks") as Node2D
	if special_chunks_parent == null:
		special_chunks_parent = Node2D.new()
		special_chunks_parent.name = "SpecialChunks"
		add_child(special_chunks_parent)
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, active_config.tile_set, special_chunks_parent)

	generator = WorldGenerator.new(world_seed, tile_library, active_config, special_chunk_planner)
	renderer = ChunkTileMapRenderer.new(tile_library)
	player = get_node_or_null("Player")
	debug_overlay = get_node_or_null("DebugOverlay")
	if player == null:
		push_warning("WorldManager: Player node not found. Chunks will load around origin.")
	_update_loaded_chunks(true)

func _load_config() -> WorldGenConfig:
	if world_gen_config != null:
		return world_gen_config
	var loaded: WorldGenConfig = ResourceLoader.load(DEFAULT_CONFIG_PATH) as WorldGenConfig
	if loaded != null:
		return loaded
	if use_runtime_generated_fallback:
		var runtime_library: TileLibrary = TileLibrary.new()
		return runtime_library.build_demo_library()
	return null

func _process(_delta: float) -> void:
	_update_loaded_chunks(false)
	if debug_overlay != null and debug_overlay.has_method("set_debug_data"):
		var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
		debug_overlay.set_debug_data(world_seed, center, loaded_chunks.size(), tile_library.fallback_count, "TileMapLayer + SpecialChunks")

func world_pos_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK_SIZE)), floori(pos.y / float(CHUNK_SIZE)))

func _update_loaded_chunks(force: bool) -> void:
	if ground_layer == null:
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	var needed: Dictionary = {}
	for y: int in range(center.y - load_radius, center.y + load_radius + 1):
		for x: int in range(center.x - load_radius, center.x + load_radius + 1):
			var coord: Vector2i = Vector2i(x, y)
			needed[coord] = true
			if force or not loaded_chunks.has(coord):
				_load_chunk(coord)
	if special_chunk_manager != null:
		special_chunk_manager.update_loaded_chunks(needed)
	var existing: Array = loaded_chunks.keys()
	for coord_to_check: Vector2i in existing:
		if not needed.has(coord_to_check):
			_unload_chunk(coord_to_check)

func _load_chunk(coord: Vector2i) -> void:
	if loaded_chunks.has(coord):
		return
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		loaded_chunks[coord] = null
		return
	var data: ChunkData = generator.generate_chunk(coord)
	renderer.paint_chunk(data, ground_layer)
	loaded_chunks[coord] = data

func _unload_chunk(coord: Vector2i) -> void:
	var existing: Variant = loaded_chunks.get(coord, null)
	if existing != null:
		renderer.clear_chunk(coord, ground_layer)
	loaded_chunks.erase(coord)
