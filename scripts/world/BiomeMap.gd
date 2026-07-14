class_name BiomeMap
extends RefCounted

# Low-resolution world plan. It maps chunk coordinates to biome and chunk type.
# SpecialChunkPlanner can override chunk type to reserve authored structures.

enum ChunkType {
	MAIN_PATH,
	CAVE,
	SOLID,
	SPECIAL,
}

var world_seed: int = 12345
var config: WorldGenConfig
var special_chunk_planner: SpecialChunkPlanner

func _init(p_world_seed: int = 12345, p_config: WorldGenConfig = null) -> void:
	world_seed = p_world_seed
	config = p_config

func get_biome(coord: Vector2i) -> StringName:
	if config != null and config.biome_configs.size() > 0:
		for biome_config: BiomeConfig in config.biome_configs:
			if biome_config == null:
				continue
			if coord.y >= biome_config.depth_min and coord.y <= biome_config.depth_max:
				return biome_config.id
	if coord.y < 5:
		return &"mine"
	elif coord.y < 10:
		return &"snow"
	return &"deep"

func get_main_path_x(y: int) -> int:
	var rng: RandomNumberGenerator = SeedUtil.rng(world_seed, "main_path")
	var x: int = 0
	var steps: int = maxi(0, y + 1)
	for i: int in range(steps):
		if rng.randf() < 0.35:
			x += rng.randi_range(-1, 1)
	return clampi(x, -5, 5)

func is_on_main_path(coord: Vector2i) -> bool:
	return coord.x == get_main_path_x(coord.y)

func is_special_chunk(coord: Vector2i) -> bool:
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		return true
	return false

func get_chunk_type(coord: Vector2i) -> int:
	if is_special_chunk(coord):
		return ChunkType.SPECIAL
	if is_on_main_path(coord):
		return ChunkType.MAIN_PATH
	var distance: int = absi(coord.x - get_main_path_x(coord.y))
	if distance > 6:
		return ChunkType.SOLID
	return ChunkType.CAVE

func chunk_type_name(chunk_type: int) -> String:
	match chunk_type:
		ChunkType.MAIN_PATH: return "main_path"
		ChunkType.SPECIAL: return "special"
		ChunkType.CAVE: return "cave"
		ChunkType.SOLID: return "solid"
		_: return "unknown"

func openness_for_chunk_type(chunk_type: int, biome_id: StringName = &"") -> float:
	var biome_config: BiomeConfig = null
	if config != null:
		biome_config = config.get_biome_config(biome_id)
	match chunk_type:
		ChunkType.MAIN_PATH:
			return biome_config.open_chance_main_path if biome_config != null else 0.68
		ChunkType.SPECIAL:
			return biome_config.open_chance_special if biome_config != null else 0.52
		ChunkType.CAVE:
			return biome_config.open_chance_cave if biome_config != null else 0.42
		ChunkType.SOLID:
			return biome_config.open_chance_solid if biome_config != null else 0.16
		_:
			return 0.38

func openness_between(type_a: int, type_b: int, biome_a: StringName = &"", biome_b: StringName = &"") -> float:
	var a: float = openness_for_chunk_type(type_a, biome_a)
	var b: float = openness_for_chunk_type(type_b, biome_b)
	return maxf(a, b) * 0.7 + minf(a, b) * 0.3
