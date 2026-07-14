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
var world_debug_drawer: WorldDebugDrawer
var debug_world_visible: bool = true
var ground_layer: TileMapLayer
var active_config: WorldGenConfig
var load_radius: int = 2
var special_chunk_planner: SpecialChunkPlanner
var special_chunk_manager: SpecialChunkManager
var special_chunks_parent: Node2D
var world_structure: WorldStructure

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

	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map)
	special_chunks_parent = get_node_or_null("SpecialChunks") as Node2D
	if special_chunks_parent == null:
		special_chunks_parent = Node2D.new()
		special_chunks_parent.name = "SpecialChunks"
		add_child(special_chunks_parent)
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, active_config.tile_set, special_chunks_parent)

	generator = WorldGenerator.new(world_seed, tile_library, active_config, special_chunk_planner, world_structure)
	renderer = ChunkTileMapRenderer.new(tile_library)
	player = get_node_or_null("Player")
	debug_overlay = get_node_or_null("DebugOverlay")
	world_debug_drawer = get_node_or_null("WorldDebugDrawer") as WorldDebugDrawer
	if world_debug_drawer != null:
		world_debug_drawer.world_manager = self
		world_debug_drawer.visible = debug_world_visible
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
	_update_debug_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				if debug_overlay != null:
					debug_overlay.visible = not debug_overlay.visible
			KEY_F2:
				debug_world_visible = not debug_world_visible
				if world_debug_drawer != null:
					world_debug_drawer.visible = debug_world_visible
			KEY_F3:
				_regenerate_world(false)
			KEY_F4:
				_regenerate_world(true)

func _update_debug_ui() -> void:
	if debug_overlay == null or not debug_overlay.has_method("set_debug_snapshot"):
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	debug_overlay.call("set_debug_snapshot", _build_debug_snapshot(center))

func _build_debug_snapshot(center: Vector2i) -> Dictionary:
	var current_chunk: ChunkData = loaded_chunks.get(center, null) as ChunkData
	var special_info: String = ""
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(center):
		var placement: SpecialChunkPlacement = special_chunk_planner.get_chunk_at(center)
		if placement != null and placement.chunk_def != null:
			special_info = "%s @ %s" % [str(placement.chunk_def.id), str(placement.origin_chunk)]
	var chunk_type_text: String = "unknown"
	if current_chunk != null:
		chunk_type_text = BiomeMap.chunk_type_name(current_chunk.chunk_type)
	elif special_info != "":
		chunk_type_text = "special"
	return {
		"seed": world_seed,
		"center_chunk": center,
		"loaded_count": loaded_chunks.size(),
		"load_radius": load_radius,
		"renderer": "TileMapLayer + SpecialChunks",
		"biome": current_chunk.biome_id if current_chunk != null else biome_map_name(center),
		"chunk_type": chunk_type_text,
		"open_sides": current_chunk.open_side_count if current_chunk != null else 0,
		"top_profile": _profile_to_string(current_chunk.top_profile) if current_chunk != null else "--------",
		"right_profile": _profile_to_string(current_chunk.right_profile) if current_chunk != null else "--------",
		"bottom_profile": _profile_to_string(current_chunk.bottom_profile) if current_chunk != null else "--------",
		"left_profile": _profile_to_string(current_chunk.left_profile) if current_chunk != null else "--------",
		"exact_matches": _loaded_exact_match_count(),
		"compatible_matches": _loaded_compatible_match_count(),
		"fallback_count": _loaded_fallback_count(),
		"air_tiles": _loaded_air_tile_count(),
		"air_pockets": _loaded_air_pocket_count(),
		"chamber_carve_air": _loaded_chamber_carve_air_count(),
		"chamber_carve_open": _loaded_chamber_carve_open_count(),
		"connectivity_path_tiles": _loaded_connectivity_path_tile_count(),
		"connected_open_sides": current_chunk.connected_open_sides if current_chunk != null else 0,
		"current_chamber": _current_chamber_debug(current_chunk),
		"connectivity_adjusted": _loaded_connectivity_adjusted_count(),
		"special_info": special_info,
		"structure_tags": current_chunk.structure_tag_string() if current_chunk != null else (world_structure.tag_string_for(center) if world_structure != null else "fallback"),
		"structure_source": current_chunk.structure_source if current_chunk != null else ("structure_v1" if world_structure != null and world_structure.has_node(center) else "fallback"),
		"intended_connections": current_chunk.intended_connection_count if current_chunk != null else 0,
	}

func biome_map_name(coord: Vector2i) -> StringName:
	if generator != null and generator.biome_map != null:
		return generator.biome_map.get_biome(coord)
	return &"unknown"

func _loaded_air_tile_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.air_tile_count
	return total


func _loaded_chamber_carve_air_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.chamber_carve_air_tiles
	return total

func _loaded_chamber_carve_open_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.chamber_carve_open_tiles
	return total

func _loaded_connectivity_path_tile_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.connectivity_path_tiles
	return total

func _current_chamber_debug(chunk_data: ChunkData) -> String:
	if chunk_data == null or chunk_data.chamber_id == &"":
		return ""
	return "%s %s@%s carve A%d/O%d" % [
		str(chunk_data.chamber_id),
		str(chunk_data.chamber_size),
		str(chunk_data.chamber_origin),
		chunk_data.chamber_carve_air_tiles,
		chunk_data.chamber_carve_open_tiles,
	]

func _loaded_air_pocket_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.air_pocket_count
	return total

func _loaded_exact_match_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.exact_match_tiles
	return total

func _loaded_compatible_match_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.compatible_match_tiles
	return total

func _loaded_fallback_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null:
			total += chunk_data.fallback_tiles
	return total

func _loaded_connectivity_adjusted_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: ChunkData = item as ChunkData
		if chunk_data != null and chunk_data.connectivity_adjusted:
			total += 1
	return total

func _profile_to_string(profile: Array[int]) -> String:
	var result: String = ""
	for edge_value: int in profile:
		result += TileDef.edge_to_char(edge_value)
	return result

func _regenerate_world(advance_seed: bool) -> void:
	if advance_seed:
		world_seed += 1
		if active_config != null:
			active_config.world_seed = world_seed
	if tile_library != null:
		tile_library.fallback_count = 0
		tile_library.compatible_match_count = 0
	for coord: Vector2i in loaded_chunks.keys():
		var existing: Variant = loaded_chunks.get(coord, null)
		if existing != null:
			renderer.clear_chunk(coord, ground_layer)
	loaded_chunks.clear()
	if special_chunks_parent != null:
		for child in special_chunks_parent.get_children():
			child.queue_free()
	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map)
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, active_config.tile_set, special_chunks_parent)
	generator = WorldGenerator.new(world_seed, tile_library, active_config, special_chunk_planner, world_structure)
	_update_loaded_chunks(true)

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
