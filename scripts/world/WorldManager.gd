extends Node2D

# Runtime streaming coordinator for the migrated piece world.
# TileMap generation has been removed from the main runtime path; chunks are
# generated as 4 x 4 piece-unit images where each unit is 128px.

const DEFAULT_CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

@export var world_gen_config: WorldGenConfig
@export var piece_library: PieceLibrary
@export var override_seed: bool = false
@export var world_seed: int = 20260706
@export var use_runtime_generated_fallback: bool = false

var library: PieceLibrary
var generator: PieceChunkGenerator
var loaded_chunks: Dictionary = {}
var chunk_renderers: Dictionary = {}
var player: Node2D
var debug_overlay: CanvasLayer
var world_debug_drawer: WorldDebugDrawer
var debug_world_visible: bool = true
var active_config: WorldGenConfig
var load_radius: int = 2
var special_chunk_planner: SpecialChunkPlanner
var special_chunk_manager: SpecialChunkManager
var special_chunks_parent: Node2D
var chunk_renderers_parent: Node2D
var world_structure: WorldStructure

func _ready() -> void:
	active_config = _load_config()
	if active_config == null:
		push_error("WorldManager: Unable to load WorldGenConfig.")
		return
	if override_seed:
		active_config.world_seed = world_seed
	world_seed = active_config.world_seed
	load_radius = active_config.load_radius
	library = _load_piece_library()
	if library == null:
		push_error("WorldManager: Unable to load PieceLibrary.")
		return
	library.prepare()

	chunk_renderers_parent = get_node_or_null("ChunkRenderers") as Node2D
	if chunk_renderers_parent == null:
		chunk_renderers_parent = Node2D.new()
		chunk_renderers_parent.name = "ChunkRenderers"
		add_child(chunk_renderers_parent)

	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map, world_structure)
	special_chunks_parent = get_node_or_null("SpecialChunks") as Node2D
	if special_chunks_parent == null:
		special_chunks_parent = Node2D.new()
		special_chunks_parent.name = "SpecialChunks"
		add_child(special_chunks_parent)
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, special_chunks_parent)

	generator = PieceChunkGenerator.new(world_seed, library, active_config, special_chunk_planner, world_structure)
	player = get_node_or_null("Player") as Node2D
	debug_overlay = get_node_or_null("DebugOverlay") as CanvasLayer
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
	return null

func _load_piece_library() -> PieceLibrary:
	if piece_library != null:
		return piece_library.duplicate(false) as PieceLibrary
	if active_config != null and active_config.piece_library != null:
		return active_config.piece_library.duplicate(false) as PieceLibrary
	var loaded: PieceLibrary = ResourceLoader.load("res://resources/pieces/piece_library.tres") as PieceLibrary
	if loaded != null:
		return loaded.duplicate(false) as PieceLibrary
	var runtime_library: PieceLibrary = PieceLibrary.new()
	runtime_library.load_from_default_dirs()
	return runtime_library

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
	var current_chunk: PieceChunkData = loaded_chunks.get(center, null) as PieceChunkData
	var seam_debug: Dictionary = ChunkSeamValidator.validate_loaded_chunks(loaded_chunks)
	var special_info: String = ""
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(center):
		var placement: SpecialChunkPlacement = special_chunk_planner.get_chunk_at(center)
		if placement != null and placement.chunk_def != null:
			special_info = "%s @ %s" % [str(placement.chunk_def.id), str(placement.origin_chunk)]
	elif world_structure != null:
		var special_node: WorldStructureNode = world_structure.get_node(center)
		if special_node != null and special_node.special_chunk_id != &"":
			if special_node.has_tag(&"special_chunk_gateway"):
				special_info = "gateway %s via %s" % [str(special_node.special_chunk_id), str(special_node.special_chunk_gateway_side)]
			else:
				special_info = "near %s" % str(special_node.special_chunk_id)
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
		"renderer": "PieceImage + SpecialPiece",
		"unit_size": UNIT_SIZE,
		"units_per_chunk": UNITS_PER_CHUNK,
		"biome": current_chunk.biome_id if current_chunk != null else biome_map_name(center),
		"chunk_type": chunk_type_text,
		"open_sides": current_chunk.open_side_count if current_chunk != null else 0,
		"top_profile": _profile_to_string(current_chunk.top_profile) if current_chunk != null else "SSSS",
		"right_profile": _profile_to_string(current_chunk.right_profile) if current_chunk != null else "SSSS",
		"bottom_profile": _profile_to_string(current_chunk.bottom_profile) if current_chunk != null else "SSSS",
		"left_profile": _profile_to_string(current_chunk.left_profile) if current_chunk != null else "SSSS",
		"actual_top_profile": _profile_to_string(current_chunk.actual_top_profile) if current_chunk != null else "SSSS",
		"actual_right_profile": _profile_to_string(current_chunk.actual_right_profile) if current_chunk != null else "SSSS",
		"actual_bottom_profile": _profile_to_string(current_chunk.actual_bottom_profile) if current_chunk != null else "SSSS",
		"actual_left_profile": _profile_to_string(current_chunk.actual_left_profile) if current_chunk != null else "SSSS",
		"seam_repairs": current_chunk.seam_repair_count if current_chunk != null else 0,
		"seam_expected_broken": int(seam_debug.get("expected_broken", 0)),
		"seam_neighbor_broken": int(seam_debug.get("neighbor_broken", 0)),
		"seam_neighbor_exact": int(seam_debug.get("neighbor_exact", 0)),
		"seam_neighbor_compatible": int(seam_debug.get("neighbor_compatible", 0)),
		"exact_matches": _loaded_regular_piece_count(),
		"compatible_matches": _loaded_open_socket_count(),
		"fallback_count": _loaded_glue_count(),
		"air_tiles": _loaded_air_unit_count(),
		"air_pockets": _loaded_piece_count(),
		"chamber_carve_air": _loaded_special_piece_count(),
		"chamber_carve_open": _loaded_chamber_piece_count(),
		"connectivity_path_tiles": _loaded_open_socket_count(),
		"connected_open_sides": current_chunk.connected_open_sides if current_chunk != null else 0,
		"current_chamber": _current_chamber_debug(current_chunk),
		"connectivity_adjusted": _loaded_connectivity_adjusted_count(),
		"special_info": special_info,
		"structure_tags": current_chunk.structure_tag_string() if current_chunk != null else (world_structure.tag_string_for(center) if world_structure != null else "fallback"),
		"structure_source": current_chunk.structure_source if current_chunk != null else ("structure_v1" if world_structure != null and world_structure.has_node(center) else "fallback"),
		"intended_connections": current_chunk.intended_connection_count if current_chunk != null else 0,
		"piece_count": current_chunk.piece_count if current_chunk != null else 0,
		"glue_count": current_chunk.used_glue_count if current_chunk != null else 0,
	}

func biome_map_name(coord: Vector2i) -> StringName:
	if generator != null and generator.biome_map != null:
		return generator.biome_map.get_biome(coord)
	return &"unknown"

func _loaded_air_unit_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.air_tile_count
	return total

func _loaded_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.piece_count
	return total

func _loaded_regular_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.regular_piece_count
	return total

func _loaded_glue_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.used_glue_count
	return total

func _loaded_open_socket_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.compatible_match_tiles
	return total

func _loaded_special_piece_count() -> int:
	if special_chunk_manager == null:
		return 0
	return special_chunk_manager.loaded_chunks.size()

func _loaded_chamber_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null and chunk_data.chunk_type == BiomeMap.ChunkType.CHAMBER:
			total += 1
	return total

func _current_chamber_debug(chunk_data: PieceChunkData) -> String:
	if chunk_data == null or chunk_data.chamber_id == &"":
		return ""
	return "%s %s@%s pieces %d/glue %d" % [
		str(chunk_data.chamber_id),
		str(chunk_data.chamber_size),
		str(chunk_data.chamber_origin),
		chunk_data.piece_count,
		chunk_data.used_glue_count,
	]

func _loaded_connectivity_adjusted_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null and chunk_data.connectivity_adjusted:
			total += 1
	return total

func _profile_to_string(profile: Array[PieceSocket.Socket]) -> String:
	var result: String = ""
	for socket: PieceSocket.Socket in profile:
		result += PieceSocket.to_debug_char(PieceSocket.from_value(socket))
	return result

func _regenerate_world(advance_seed: bool) -> void:
	if advance_seed:
		world_seed += 1
		if active_config != null:
			active_config.world_seed = world_seed
	for coord: Vector2i in chunk_renderers.keys():
		var renderer: Node = chunk_renderers.get(coord, null) as Node
		if renderer != null:
			renderer.queue_free()
	loaded_chunks.clear()
	chunk_renderers.clear()
	if special_chunks_parent != null:
		for child: Node in special_chunks_parent.get_children():
			child.queue_free()
	if library != null:
		library.prepare()
	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map, world_structure)
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, special_chunks_parent)
	generator = PieceChunkGenerator.new(world_seed, library, active_config, special_chunk_planner, world_structure)
	_update_loaded_chunks(true)

func world_pos_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK_SIZE)), floori(pos.y / float(CHUNK_SIZE)))

func _update_loaded_chunks(force: bool) -> void:
	if generator == null:
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
	var data: PieceChunkData = generator.generate_chunk(coord)
	var renderer: PieceChunkRenderer = PieceChunkRenderer.new()
	chunk_renderers_parent.add_child(renderer)
	renderer.setup(data)
	chunk_renderers[coord] = renderer
	loaded_chunks[coord] = data

func _unload_chunk(coord: Vector2i) -> void:
	var renderer: Node = chunk_renderers.get(coord, null) as Node
	if renderer != null:
		renderer.queue_free()
	chunk_renderers.erase(coord)
	loaded_chunks.erase(coord)
