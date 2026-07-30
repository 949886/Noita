extends Node2D

# Runtime streaming coordinator for the migrated piece world.
# TileMap generation has been removed from the main runtime path; chunks are
# generated as 4 x 4 piece-unit images where each unit is 128px.
#
# Threading model:
# - Background worker: PieceChunkData + visual/material Image composition.
# - Main thread: scene-tree changes, ImageTexture upload, debug UI updates.

const DEFAULT_CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"
const PC_RUNTIME_PROFILE_PATH: String = "res://resources/runtime_profiles/pc_runtime_profile.tres"
const MOBILE_RUNTIME_PROFILE_PATH: String = "res://resources/runtime_profiles/mobile_runtime_profile.tres"
const PROFILE_AUTO: int = 0
const PROFILE_PC: int = 1
const PROFILE_MOBILE: int = 2
const PROFILE_CUSTOM: int = 3
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

@export var world_gen_config: WorldGenConfig
@export var piece_library: PieceLibrary
@export var override_seed: bool = false
@export var world_seed: int = 20260706
@export var use_runtime_generated_fallback: bool = false
@export_enum("Auto", "PC", "Mobile", "Custom") var runtime_profile_mode: int = PROFILE_AUTO
@export var pc_runtime_profile: WorldRuntimeProfile
@export var mobile_runtime_profile: WorldRuntimeProfile
@export var custom_runtime_profile: WorldRuntimeProfile

var runtime_profile: WorldRuntimeProfile
var use_threaded_chunk_generation: bool = true
var use_threaded_special_generation: bool = true
var main_thread_upload_budget_per_frame: int = 2
var keep_cpu_visual_images: bool = true
var visual_texture_downscale_factor: int = 1
var chunk_renderer_pool_limit: int = 64
var debug_update_interval: float = 0.20

var library: PieceLibrary
var generator: PieceChunkGenerator
var chunk_worker: ChunkGenerationWorker
var loaded_chunks: Dictionary = {}
var chunk_renderers: Dictionary = {}
var chunk_renderer_pool: Array[PieceChunkRenderer] = []
var pending_chunks: Dictionary = {}
var wanted_chunks: Dictionary = {}
var player: Node2D
var debug_overlay: CanvasLayer
var world_debug_drawer: WorldDebugDrawer
var debug_world_visible: bool = false
var active_config: WorldGenConfig
var load_radius: int = 2
var special_chunk_planner: SpecialChunkPlanner
var special_chunk_manager: SpecialChunkManager
var special_chunks_parent: Node2D
var chunk_renderers_parent: Node2D
var world_structure: WorldStructure
var debug_update_accum: float = 999.0
var cached_seam_debug: Dictionary = {}
var seam_debug_dirty: bool = true
var last_chunk_generation_ms: int = 0
var last_chunk_upload_count: int = 0

func _ready() -> void:
	active_config = _load_config()
	if active_config == null:
		push_error("WorldManager: Unable to load WorldGenConfig.")
		return
	if override_seed:
		active_config.world_seed = world_seed
	world_seed = active_config.world_seed
	runtime_profile = _resolve_runtime_profile()
	_apply_runtime_profile()
	library = _load_piece_library()
	if library == null:
		push_error("WorldManager: Unable to load PieceLibrary.")
		return
	# Important: this caches Texture2D -> Image on the main thread before any
	# background workers start.
	library.prepare()

	chunk_renderers_parent = get_node_or_null("ChunkRenderers") as Node2D
	if chunk_renderers_parent == null:
		chunk_renderers_parent = Node2D.new()
		chunk_renderers_parent.name = "ChunkRenderers"
		add_child(chunk_renderers_parent)

	_build_world_runtime()
	player = get_node_or_null("Player") as Node2D
	debug_overlay = get_node_or_null("DebugOverlay") as CanvasLayer
	world_debug_drawer = get_node_or_null("WorldDebugDrawer") as WorldDebugDrawer
	if world_debug_drawer != null:
		world_debug_drawer.world_manager = self
	_apply_runtime_profile_to_debug_nodes()
	if player == null:
		push_warning("WorldManager: Player node not found. Chunks will load around origin.")
	_update_loaded_chunks(true)

func _exit_tree() -> void:
	_stop_workers()

func _build_world_runtime() -> void:
	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map, world_structure)
	special_chunks_parent = get_node_or_null("SpecialChunks") as Node2D
	if special_chunks_parent == null:
		special_chunks_parent = Node2D.new()
		special_chunks_parent.name = "SpecialChunks"
		add_child(special_chunks_parent)
	var special_pool_limit: int = runtime_profile.special_renderer_pool_limit if runtime_profile != null else 32
	special_chunk_manager = SpecialChunkManager.new(special_chunk_planner, special_chunks_parent, use_threaded_special_generation, visual_texture_downscale_factor, special_pool_limit)
	generator = PieceChunkGenerator.new(world_seed, library, active_config, special_chunk_planner, world_structure)
	_start_chunk_worker()

func _start_chunk_worker() -> void:
	if not use_threaded_chunk_generation:
		chunk_worker = null
		return
	chunk_worker = ChunkGenerationWorker.new()
	if not chunk_worker.start(generator):
		push_warning("WorldManager: chunk worker failed to start; falling back to synchronous generation.")
		chunk_worker = null
		use_threaded_chunk_generation = false

func _stop_workers() -> void:
	if chunk_worker != null:
		chunk_worker.stop()
		chunk_worker = null
	if special_chunk_manager != null:
		special_chunk_manager.stop()

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


func _resolve_runtime_profile() -> WorldRuntimeProfile:
	var mode: int = runtime_profile_mode
	if mode == PROFILE_AUTO:
		mode = PROFILE_MOBILE if _is_mobile_platform() else PROFILE_PC
	match mode:
		PROFILE_PC:
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)
		PROFILE_MOBILE:
			return _load_runtime_profile(mobile_runtime_profile, MOBILE_RUNTIME_PROFILE_PATH)
		PROFILE_CUSTOM:
			if custom_runtime_profile != null:
				return custom_runtime_profile
			push_warning("WorldManager: Runtime profile mode is Custom, but no custom_runtime_profile is assigned. Falling back to PC profile.")
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)
		_:
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)

func _load_runtime_profile(assigned_profile: WorldRuntimeProfile, fallback_path: String) -> WorldRuntimeProfile:
	if assigned_profile != null:
		return assigned_profile
	var loaded: WorldRuntimeProfile = ResourceLoader.load(fallback_path) as WorldRuntimeProfile
	if loaded != null:
		return loaded
	var fallback: WorldRuntimeProfile = WorldRuntimeProfile.new()
	fallback.display_name = "Fallback"
	return fallback

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.get_name() == "Android" or OS.get_name() == "iOS"

func _apply_runtime_profile() -> void:
	if runtime_profile == null:
		runtime_profile = _resolve_runtime_profile()
	load_radius = runtime_profile.load_radius if runtime_profile != null else active_config.load_radius
	use_threaded_chunk_generation = runtime_profile.use_threaded_chunk_generation if runtime_profile != null else true
	use_threaded_special_generation = runtime_profile.use_threaded_special_generation if runtime_profile != null else true
	main_thread_upload_budget_per_frame = runtime_profile.main_thread_upload_budget_per_frame if runtime_profile != null else 2
	keep_cpu_visual_images = runtime_profile.keep_cpu_visual_images if runtime_profile != null else true
	visual_texture_downscale_factor = runtime_profile.visual_texture_downscale_factor if runtime_profile != null else 1
	chunk_renderer_pool_limit = runtime_profile.chunk_renderer_pool_limit if runtime_profile != null else 64
	debug_update_interval = runtime_profile.debug_update_interval if runtime_profile != null else 0.20
	debug_world_visible = runtime_profile.world_debug_visible_on_start if runtime_profile != null else false

func _apply_runtime_profile_to_debug_nodes() -> void:
	if runtime_profile == null:
		runtime_profile = _resolve_runtime_profile()
	if debug_overlay != null:
		debug_overlay.visible = runtime_profile.debug_overlay_visible_on_start if runtime_profile != null else false
	if world_debug_drawer != null:
		world_debug_drawer.visible = runtime_profile.world_debug_visible_on_start if runtime_profile != null else false
		debug_world_visible = world_debug_drawer.visible
		if runtime_profile != null:
			world_debug_drawer.redraw_interval = runtime_profile.world_debug_redraw_interval
			world_debug_drawer.show_chunk_bounds = runtime_profile.show_world_debug_chunk_bounds
			world_debug_drawer.show_socket_profiles = runtime_profile.show_world_debug_socket_profiles
			world_debug_drawer.show_chunk_labels = runtime_profile.show_world_debug_chunk_labels
			world_debug_drawer.show_piece_bounds = runtime_profile.show_world_debug_piece_bounds

func _process(delta: float) -> void:
	_update_loaded_chunks(false)
	var remaining_upload_budget: int = maxi(1, main_thread_upload_budget_per_frame)
	var normal_uploads: int = _collect_chunk_results(remaining_upload_budget)
	remaining_upload_budget = maxi(0, remaining_upload_budget - normal_uploads)
	var special_uploads: int = 0
	if special_chunk_manager != null and remaining_upload_budget > 0:
		special_uploads = special_chunk_manager.process_ready(remaining_upload_budget)
	last_chunk_upload_count = normal_uploads + special_uploads
	debug_update_accum += delta
	if debug_update_accum >= debug_update_interval:
		debug_update_accum = 0.0
		_update_debug_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				if debug_overlay != null:
					debug_overlay.visible = not debug_overlay.visible
					debug_update_accum = debug_update_interval
			KEY_F2:
				debug_world_visible = not debug_world_visible
				if world_debug_drawer != null:
					world_debug_drawer.visible = debug_world_visible
					world_debug_drawer.queue_redraw()
			KEY_F3:
				_regenerate_world(false)
			KEY_F4:
				_regenerate_world(true)

func _update_debug_ui() -> void:
	if debug_overlay == null or not debug_overlay.visible or not debug_overlay.has_method("set_debug_snapshot"):
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	debug_overlay.call("set_debug_snapshot", _build_debug_snapshot(center))

func _build_debug_snapshot(center: Vector2i) -> Dictionary:
	var current_chunk: PieceChunkData = loaded_chunks.get(center, null) as PieceChunkData
	if seam_debug_dirty:
		cached_seam_debug = ChunkSeamValidator.validate_loaded_chunks(loaded_chunks)
		seam_debug_dirty = false
	var seam_debug: Dictionary = cached_seam_debug
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
		"runtime_profile": runtime_profile.display_name if runtime_profile != null else "None",
		"center_chunk": center,
		"loaded_count": loaded_chunks.size(),
		"pending_count": pending_chunks.size(),
		"worker_queue": chunk_worker.queued_count() if chunk_worker != null else 0,
		"worker_results": chunk_worker.result_count() if chunk_worker != null else 0,
		"special_pending": special_chunk_manager.queued_count() if special_chunk_manager != null else 0,
		"special_worker_queue": special_chunk_manager.worker_queue_count() if special_chunk_manager != null else 0,
		"threaded_chunks": use_threaded_chunk_generation and chunk_worker != null,
		"threaded_specials": use_threaded_special_generation and special_chunk_manager != null and special_chunk_manager.image_worker != null,
		"last_chunk_ms": last_chunk_generation_ms,
		"last_upload_count": last_chunk_upload_count,
		"load_radius": load_radius,
		"visual_downscale": visual_texture_downscale_factor,
		"renderer_pool": chunk_renderer_pool.size(),
		"renderer": "PieceImage threaded" if use_threaded_chunk_generation and chunk_worker != null else "PieceImage sync",
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
	# Avoid touching the background worker's generator/biome map from the main
	# thread. This lightweight temporary map only performs read-only lookups for HUD
	# fallback text when the current chunk has not arrived yet.
	if active_config == null:
		return &"unknown"
	var map: BiomeMap = BiomeMap.new(world_seed, active_config)
	map.world_structure = world_structure
	map.special_chunk_planner = special_chunk_planner
	return map.get_biome(coord)

func _regenerate_world(advance_seed: bool) -> void:
	_stop_workers()
	if advance_seed:
		world_seed += 1
		if active_config != null:
			active_config.world_seed = world_seed
	for coord: Vector2i in chunk_renderers.keys():
		var renderer: Node = chunk_renderers.get(coord, null) as Node
		if renderer != null:
			renderer.queue_free()
	for pooled: PieceChunkRenderer in chunk_renderer_pool:
		if pooled != null and is_instance_valid(pooled):
			pooled.queue_free()
	chunk_renderer_pool.clear()
	loaded_chunks.clear()
	chunk_renderers.clear()
	pending_chunks.clear()
	wanted_chunks.clear()
	if special_chunks_parent != null:
		for child: Node in special_chunks_parent.get_children():
			child.queue_free()
	runtime_profile = _resolve_runtime_profile()
	_apply_runtime_profile()
	_apply_runtime_profile_to_debug_nodes()
	if library != null:
		library.prepare()
	_build_world_runtime()
	seam_debug_dirty = true
	debug_update_accum = debug_update_interval
	_update_loaded_chunks(true)

func world_pos_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK_SIZE)), floori(pos.y / float(CHUNK_SIZE)))

func _update_loaded_chunks(force: bool) -> void:
	if generator == null:
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	var needed: Dictionary = {}
	var normal_candidates: Array[Vector2i] = []
	for y: int in range(center.y - load_radius, center.y + load_radius + 1):
		for x: int in range(center.x - load_radius, center.x + load_radius + 1):
			var coord: Vector2i = Vector2i(x, y)
			needed[coord] = true
			if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
				if not loaded_chunks.has(coord):
					loaded_chunks[coord] = null
				continue
			if force or (not loaded_chunks.has(coord) and not pending_chunks.has(coord)):
				normal_candidates.append(coord)
	normal_candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center)
	)
	for coord: Vector2i in normal_candidates:
		if not loaded_chunks.has(coord) and not pending_chunks.has(coord):
			_request_chunk(coord)
	wanted_chunks = needed
	if chunk_worker != null:
		chunk_worker.prune_requests(needed)
	if special_chunk_manager != null:
		special_chunk_manager.update_loaded_chunks(needed)
	var existing: Array = loaded_chunks.keys()
	for coord_to_check: Vector2i in existing:
		if not needed.has(coord_to_check):
			_unload_chunk(coord_to_check)
	var pending_existing: Array = pending_chunks.keys()
	for pending_coord: Vector2i in pending_existing:
		if not needed.has(pending_coord):
			pending_chunks.erase(pending_coord)

func _request_chunk(coord: Vector2i) -> void:
	if loaded_chunks.has(coord) or pending_chunks.has(coord):
		return
	if use_threaded_chunk_generation and chunk_worker != null:
		pending_chunks[coord] = true
		chunk_worker.enqueue(coord)
	else:
		_load_chunk_sync(coord)

func _collect_chunk_results(upload_budget: int) -> int:
	if chunk_worker == null or upload_budget <= 0:
		return 0
	var uploaded: int = 0
	var results: Array[Dictionary] = chunk_worker.collect_results(upload_budget)
	for result: Dictionary in results:
		var coord: Vector2i = result.get("coord", Vector2i.ZERO)
		pending_chunks.erase(coord)
		last_chunk_generation_ms = int(result.get("elapsed_ms", 0))
		var data: PieceChunkData = result.get("data", null) as PieceChunkData
		if data == null:
			push_warning("WorldManager: async chunk %s failed: %s" % [str(coord), str(result.get("error", "unknown"))])
			continue
		if not _chunk_is_currently_needed(coord):
			continue
		_attach_chunk_renderer(data)
		uploaded += 1
	return uploaded

func _chunk_is_currently_needed(coord: Vector2i) -> bool:
	if not wanted_chunks.has(coord):
		return false
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		return false
	return true

func _load_chunk_sync(coord: Vector2i) -> void:
	if loaded_chunks.has(coord):
		return
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		loaded_chunks[coord] = null
		return
	var data: PieceChunkData = generator.generate_chunk(coord, true)
	_attach_chunk_renderer(data)

func _obtain_chunk_renderer() -> PieceChunkRenderer:
	var renderer: PieceChunkRenderer = null
	while not chunk_renderer_pool.is_empty() and renderer == null:
		renderer = chunk_renderer_pool.pop_back() as PieceChunkRenderer
		if renderer == null or not is_instance_valid(renderer):
			renderer = null
	if renderer == null:
		renderer = PieceChunkRenderer.new()
		chunk_renderers_parent.add_child(renderer)
	renderer.visible = true
	return renderer

func _attach_chunk_renderer(data: PieceChunkData) -> void:
	if data == null or loaded_chunks.has(data.coord):
		return
	var renderer: PieceChunkRenderer = _obtain_chunk_renderer()
	renderer.setup(data, not keep_cpu_visual_images, visual_texture_downscale_factor)
	chunk_renderers[data.coord] = renderer
	loaded_chunks[data.coord] = data
	seam_debug_dirty = true
	if world_debug_drawer != null and world_debug_drawer.visible:
		world_debug_drawer.queue_redraw()

func _unload_chunk(coord: Vector2i) -> void:
	var renderer: PieceChunkRenderer = chunk_renderers.get(coord, null) as PieceChunkRenderer
	if renderer != null:
		if chunk_renderer_pool.size() < chunk_renderer_pool_limit:
			renderer.recycle_for_pool()
			chunk_renderer_pool.append(renderer)
		else:
			renderer.queue_free()
	chunk_renderers.erase(coord)
	loaded_chunks.erase(coord)
	pending_chunks.erase(coord)
	seam_debug_dirty = true
	if world_debug_drawer != null and world_debug_drawer.visible:
		world_debug_drawer.queue_redraw()

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
