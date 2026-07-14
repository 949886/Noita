class_name WorldGenerator
extends RefCounted

const MODULES_PER_CHUNK: int = 8

var world_seed: int = 12345
var biome_map: BiomeMap
var edge_profile: EdgeProfile
var tile_library: TileLibrary
var config: WorldGenConfig
var special_chunk_planner: SpecialChunkPlanner

func _init(p_world_seed: int, p_tile_library: TileLibrary, p_config: WorldGenConfig = null, p_special_chunk_planner: SpecialChunkPlanner = null) -> void:
	world_seed = p_world_seed
	tile_library = p_tile_library
	config = p_config
	special_chunk_planner = p_special_chunk_planner
	biome_map = BiomeMap.new(world_seed, config)
	biome_map.special_chunk_planner = special_chunk_planner
	edge_profile = EdgeProfile.new(world_seed, biome_map, special_chunk_planner)

func generate_chunk(coord: Vector2i) -> ChunkData:
	var data: ChunkData = ChunkData.new(coord)
	data.biome_id = biome_map.get_biome(coord)
	data.chunk_type = biome_map.get_chunk_type(coord)
	var profiles: Dictionary = edge_profile.get_profiles_for_chunk(coord)
	data.top_profile = profiles["top"]
	data.bottom_profile = profiles["bottom"]
	data.left_profile = profiles["left"]
	data.right_profile = profiles["right"]
	var before_fallbacks: int = tile_library.fallback_count
	data.tiles = generate_tile_grid(data)
	data.fallback_tiles = tile_library.fallback_count - before_fallbacks
	return data

func generate_tile_grid(data: ChunkData) -> Array:
	var grid: Array = []
	grid.resize(MODULES_PER_CHUNK * MODULES_PER_CHUNK)
	var rng: RandomNumberGenerator = SeedUtil.rng_from_seed(SeedUtil.chunk_seed(world_seed, data.coord))
	for y: int in range(MODULES_PER_CHUNK):
		for x: int in range(MODULES_PER_CHUNK):
			var constraints: Dictionary = {}
			if x == 0:
				constraints[&"left"] = data.left_profile[y]
			else:
				constraints[&"left"] = (grid[y * MODULES_PER_CHUNK + x - 1] as TileDef).right
			if y == 0:
				constraints[&"top"] = data.top_profile[x]
			else:
				constraints[&"top"] = (grid[(y - 1) * MODULES_PER_CHUNK + x] as TileDef).bottom
			if x == MODULES_PER_CHUNK - 1:
				constraints[&"right"] = data.right_profile[y]
			if y == MODULES_PER_CHUNK - 1:
				constraints[&"bottom"] = data.bottom_profile[x]
			var tile: TileDef = tile_library.pick_matching_tile(data.biome_id, constraints, rng)
			grid[y * MODULES_PER_CHUNK + x] = tile
	return grid
