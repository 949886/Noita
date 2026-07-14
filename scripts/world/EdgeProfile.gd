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
	var left_coord: Vector2i = Vector2i(edge_x - 1, chunk_y)
	var right_coord: Vector2i = Vector2i(edge_x, chunk_y)
	var openness: float = biome_map.openness_between(
		biome_map.get_chunk_type(left_coord),
		biome_map.get_chunk_type(right_coord),
		biome_map.get_biome(left_coord),
		biome_map.get_biome(right_coord)
	)
	var seed: int = SeedUtil.vertical_edge_seed(world_seed, edge_x, chunk_y)
	return make_segmented_profile(seed, openness)

func get_horizontal_profile(chunk_x: int, edge_y: int) -> Array[int]:
	if special_chunk_planner != null:
		var override: Array[int] = special_chunk_planner.get_horizontal_profile_override(chunk_x, edge_y, MODULES_PER_CHUNK)
		if not override.is_empty():
			return override
	var up_coord: Vector2i = Vector2i(chunk_x, edge_y - 1)
	var down_coord: Vector2i = Vector2i(chunk_x, edge_y)
	var openness: float = biome_map.openness_between(
		biome_map.get_chunk_type(up_coord),
		biome_map.get_chunk_type(down_coord),
		biome_map.get_biome(up_coord),
		biome_map.get_biome(down_coord)
	)
	var seed: int = SeedUtil.horizontal_edge_seed(world_seed, chunk_x, edge_y)
	return make_segmented_profile(seed, openness)

func make_segmented_profile(seed_value: int, openness: float) -> Array[int]:
	var rng: RandomNumberGenerator = SeedUtil.rng_from_seed(seed_value)
	var profile: Array[int] = []
	var cursor: int = 0
	while cursor < MODULES_PER_CHUNK:
		var segment_len: int = rng.randi_range(1, 3)
		var edge_value: int = TileDef.Edge.OPEN if rng.randf() < openness else TileDef.Edge.SOLID
		for i: int in range(segment_len):
			if cursor >= MODULES_PER_CHUNK:
				break
			profile.append(edge_value)
			cursor += 1
	return smooth_profile(profile)

func smooth_profile(profile: Array[int]) -> Array[int]:
	var result: Array[int] = profile.duplicate()
	for i: int in range(1, result.size() - 1):
		if result[i - 1] == result[i + 1]:
			result[i] = result[i - 1]
	return result
