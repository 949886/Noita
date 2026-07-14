class_name EdgeProfile
extends RefCounted

# Produces deterministic edge profiles for chunk seams.
# If an edge touches a SpecialChunk, that authored chunk profile wins so neighboring Wang chunks connect cleanly.

const MODULES_PER_CHUNK: int = 8

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

func get_vertical_profile(edge_x: int, chunk_y: int) -> Array[int]:
	if special_chunk_planner != null:
		var override: Array[int] = special_chunk_planner.get_vertical_profile_override(edge_x, chunk_y, MODULES_PER_CHUNK)
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

func get_horizontal_profile(chunk_x: int, edge_y: int) -> Array[int]:
	if special_chunk_planner != null:
		var override: Array[int] = special_chunk_planner.get_horizontal_profile_override(chunk_x, edge_y, MODULES_PER_CHUNK)
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

func make_chamber_internal_profile() -> Array[int]:
	# Wide same-chamber seam: keep just a tiny bit of rock at the corners so a
	# 2x1/2x2 chamber reads as one large natural room, not two tiled mazes.
	return [
		TileDef.Edge.SOLID,
		TileDef.Edge.OPEN,
		TileDef.Edge.OPEN,
		TileDef.Edge.OPEN,
		TileDef.Edge.OPEN,
		TileDef.Edge.OPEN,
		TileDef.Edge.OPEN,
		TileDef.Edge.SOLID,
	]

func make_segmented_profile(seed_value: int, openness: float, required_connection: bool = false) -> Array[int]:
	var rng: RandomNumberGenerator = SeedUtil.rng_from_seed(seed_value)
	var profile: Array[int] = []
	var cursor: int = 0
	while cursor < MODULES_PER_CHUNK:
		# Wider segments create fewer one-tile dead nubs and make cave openings easier to read.
		var segment_len: int = rng.randi_range(2, 4)
		var edge_value: int = TileDef.Edge.OPEN if rng.randf() < openness else TileDef.Edge.SOLID
		for i: int in range(segment_len):
			if cursor >= MODULES_PER_CHUNK:
				break
			profile.append(edge_value)
			cursor += 1
	profile = smooth_profile(profile)
	_enforce_opening_for_connectivity(profile, openness, rng, required_connection)
	return profile

func smooth_profile(profile: Array[int]) -> Array[int]:
	var result: Array[int] = profile.duplicate()
	for i: int in range(1, result.size() - 1):
		if result[i - 1] == result[i + 1]:
			result[i] = result[i - 1]
	return result

func _enforce_opening_for_connectivity(profile: Array[int], openness: float, rng: RandomNumberGenerator, required_connection: bool = false) -> void:
	# This is an edge-level connectivity pass, so both chunks sharing this edge see
	# the same profile. High-openness edges always get at least one readable opening;
	# very open edges get a wider second opening, reducing dead ends without breaking
	# chunk-to-chunk determinism.
	if profile.is_empty():
		return
	if required_connection and not _has_open_run(profile, 3):
		_open_run(profile, rng, 4 if openness >= 0.82 else 3)
		return
	if openness >= 0.50 and not _has_open_run(profile, 2):
		_open_run(profile, rng, 2 if openness < 0.68 else 3)
	elif openness >= 0.68 and not _has_open_run(profile, 3):
		_open_run(profile, rng, 3)
	if openness >= 0.78 and rng.randf() < 0.55:
		_open_run(profile, rng, 2)

func _has_open_run(profile: Array[int], minimum_width: int) -> bool:
	var run: int = 0
	for edge_value: int in profile:
		if edge_value == TileDef.Edge.OPEN:
			run += 1
			if run >= minimum_width:
				return true
		else:
			run = 0
	return false

func _open_run(profile: Array[int], rng: RandomNumberGenerator, width: int) -> void:
	if profile.is_empty():
		return
	var clamped_width: int = clampi(width, 1, profile.size())
	var start: int = rng.randi_range(0, profile.size() - clamped_width)
	for i: int in range(start, start + clamped_width):
		profile[i] = TileDef.Edge.OPEN
