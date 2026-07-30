class_name SocketProfilePlanner
extends RefCounted

# Socket-based chunk seam planner. This replaces the legacy eight 64px
# edge-point profile with four 128px piece sockets per chunk edge.
const SLOTS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS

var world_seed: int
var biome_map: BiomeMap
var special_chunk_planner: SpecialChunkPlanner

func _init(p_world_seed: int, p_biome_map: BiomeMap, p_special_chunk_planner: SpecialChunkPlanner = null) -> void:
	world_seed = p_world_seed
	biome_map = p_biome_map
	special_chunk_planner = p_special_chunk_planner

func get_profiles_for_chunk(coord: Vector2i) -> Dictionary:
	return {
		"top": get_horizontal_profile(coord.x, coord.y),
		"bottom": get_horizontal_profile(coord.x, coord.y + 1),
		"left": get_vertical_profile(coord.x, coord.y),
		"right": get_vertical_profile(coord.x + 1, coord.y),
	}

func get_vertical_profile(edge_x: int, chunk_y: int) -> Array[PieceSocket.Socket]:
	if special_chunk_planner != null:
		var override: Array[PieceSocket.Socket] = special_chunk_planner.get_vertical_profile_override(edge_x, chunk_y, SLOTS_PER_CHUNK)
		if not override.is_empty():
			return override
	if biome_map.is_vertical_chamber_internal_edge(edge_x, chunk_y):
		return make_chamber_internal_profile()
	var left_coord: Vector2i = Vector2i(edge_x - 1, chunk_y)
	var right_coord: Vector2i = Vector2i(edge_x, chunk_y)
	var openness: float = biome_map.openness_between(
		biome_map.get_chunk_type(left_coord),
		biome_map.get_chunk_type(right_coord),
		biome_map.get_biome(left_coord),
		biome_map.get_biome(right_coord)
	)
	var seed: int = SeedUtil.vertical_edge_seed(world_seed, edge_x, chunk_y)
	var required_connection: bool = biome_map.is_vertical_connection_required(edge_x, chunk_y)
	return make_segmented_profile(seed, openness, required_connection)

func get_horizontal_profile(chunk_x: int, edge_y: int) -> Array[PieceSocket.Socket]:
	if special_chunk_planner != null:
		var override: Array[PieceSocket.Socket] = special_chunk_planner.get_horizontal_profile_override(chunk_x, edge_y, SLOTS_PER_CHUNK)
		if not override.is_empty():
			return override
	if biome_map.is_horizontal_chamber_internal_edge(chunk_x, edge_y):
		return make_chamber_internal_profile()
	var up_coord: Vector2i = Vector2i(chunk_x, edge_y - 1)
	var down_coord: Vector2i = Vector2i(chunk_x, edge_y)
	var openness: float = biome_map.openness_between(
		biome_map.get_chunk_type(up_coord),
		biome_map.get_chunk_type(down_coord),
		biome_map.get_biome(up_coord),
		biome_map.get_biome(down_coord)
	)
	var seed: int = SeedUtil.horizontal_edge_seed(world_seed, chunk_x, edge_y)
	var required_connection: bool = biome_map.is_horizontal_connection_required(chunk_x, edge_y)
	return make_segmented_profile(seed, openness, required_connection)

func make_chamber_internal_profile() -> Array[PieceSocket.Socket]:
	var profile: Array[PieceSocket.Socket] = []
	profile.append(PieceSocket.OPEN_LARGE)
	profile.append(PieceSocket.OPEN_LARGE)
	profile.append(PieceSocket.OPEN_LARGE)
	profile.append(PieceSocket.OPEN_LARGE)
	return profile

func make_segmented_profile(seed_value: int, openness: float, required_connection: bool = false) -> Array[PieceSocket.Socket]:
	var rng: RandomNumberGenerator = SeedUtil.rng_from_seed(seed_value)
	var profile: Array[PieceSocket.Socket] = []
	for i: int in range(SLOTS_PER_CHUNK):
		if rng.randf() < openness:
			profile.append(_pick_open_socket(rng, openness))
		else:
			profile.append(PieceSocket.SOLID)
	profile = smooth_profile(profile)
	_enforce_opening_for_connectivity(profile, openness, rng, required_connection)
	return profile

func smooth_profile(profile: Array[PieceSocket.Socket]) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = profile.duplicate()
	for i: int in range(1, result.size() - 1):
		if result[i - 1] == result[i + 1]:
			result[i] = result[i - 1]
	return result

func _pick_open_socket(rng: RandomNumberGenerator, openness: float) -> PieceSocket.Socket:
	var roll: float = rng.randf()
	if roll < 0.14 * openness:
		return PieceSocket.OPEN_LARGE
	if roll < 0.46:
		return PieceSocket.OPEN_MEDIUM
	if roll < 0.68:
		return PieceSocket.DOUBLE_OPEN_SMALL
	return PieceSocket.OPEN_SMALL

func _enforce_opening_for_connectivity(profile: Array[PieceSocket.Socket], openness: float, rng: RandomNumberGenerator, required_connection: bool = false) -> void:
	if profile.is_empty():
		return
	if required_connection and not _has_open_run(profile, 1):
		profile[rng.randi_range(0, profile.size() - 1)] = PieceSocket.OPEN_LARGE if openness >= 0.72 else PieceSocket.OPEN_MEDIUM
		return
	if openness >= 0.50 and not _has_open_run(profile, 1):
		profile[rng.randi_range(0, profile.size() - 1)] = PieceSocket.OPEN_MEDIUM
	elif openness >= 0.78 and rng.randf() < 0.45:
		profile[rng.randi_range(0, profile.size() - 1)] = PieceSocket.OPEN_LARGE

func _has_open_run(profile: Array[PieceSocket.Socket], minimum_width: int) -> bool:
	var run: int = 0
	for socket: PieceSocket.Socket in profile:
		if PieceSocket.is_open(socket):
			run += 1
			if run >= minimum_width:
				return true
		else:
			run = 0
	return false
