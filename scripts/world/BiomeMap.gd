class_name BiomeMap
extends RefCounted

# Low-resolution world plan. It maps chunk coordinates to biome and chunk type.
# SpecialChunkPlanner can override chunk type to reserve authored structures.

enum ChunkType {
	MAIN_PATH,
	CAVE,
	SOLID,
	SPECIAL,
	BRANCH,
	CHAMBER,
}

var world_seed: int = 12345
var config: WorldGenConfig
var special_chunk_planner: SpecialChunkPlanner
var world_structure: WorldStructure

func _init(p_world_seed: int = 12345, p_config: WorldGenConfig = null) -> void:
	world_seed = p_world_seed
	config = p_config

func get_biome(coord: Vector2i) -> StringName:
	if world_structure != null:
		var node: WorldStructureNode = world_structure.get_node(coord)
		if node != null:
			return node.biome_id
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
	if world_structure != null:
		return world_structure.get_main_path_x(y, 0)
	var rng: RandomNumberGenerator = SeedUtil.rng(world_seed, "main_path")
	var x: int = 0
	var steps: int = maxi(0, y + 1)
	for i: int in range(steps):
		if rng.randf() < 0.35:
			x += rng.randi_range(-1, 1)
	return clampi(x, -5, 5)

func is_on_main_path(coord: Vector2i) -> bool:
	if world_structure != null:
		var node: WorldStructureNode = world_structure.get_node(coord)
		return node != null and node.has_tag(&"main_path")
	return coord.x == get_main_path_x(coord.y)

func is_special_chunk(coord: Vector2i) -> bool:
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		return true
	return false

func get_chunk_type(coord: Vector2i) -> int:
	if is_special_chunk(coord):
		return ChunkType.SPECIAL
	if world_structure != null:
		var node: WorldStructureNode = world_structure.get_node(coord)
		if node != null:
			return node.chunk_type
	if is_on_main_path(coord):
		return ChunkType.MAIN_PATH
	var distance: int = absi(coord.x - get_main_path_x(coord.y))
	if distance > 6:
		return ChunkType.SOLID
	return ChunkType.CAVE

static func chunk_type_name(chunk_type: int) -> String:
	match chunk_type:
		ChunkType.MAIN_PATH: return "main_path"
		ChunkType.SPECIAL: return "special"
		ChunkType.CAVE: return "cave"
		ChunkType.BRANCH: return "branch"
		ChunkType.CHAMBER: return "chamber"
		ChunkType.SOLID: return "solid"
		_: return "unknown"

func openness_for_chunk_type(chunk_type: int, biome_id: StringName = &"") -> float:
	var biome_config: BiomeConfig = null
	if config != null:
		biome_config = config.get_biome_config(biome_id)
	match chunk_type:
		ChunkType.MAIN_PATH:
			return biome_config.open_chance_main_path if biome_config != null else 0.82
		ChunkType.SPECIAL:
			return biome_config.open_chance_special if biome_config != null else 0.64
		ChunkType.CAVE:
			return biome_config.open_chance_cave if biome_config != null else 0.62
		ChunkType.BRANCH:
			return minf(0.88, (biome_config.open_chance_cave if biome_config != null else 0.62) + 0.10)
		ChunkType.CHAMBER:
			return minf(0.94, (biome_config.open_chance_main_path if biome_config != null else 0.82) + 0.08)
		ChunkType.SOLID:
			return biome_config.open_chance_solid if biome_config != null else 0.28
		_:
			return 0.38

func openness_between(type_a: int, type_b: int, biome_a: StringName = &"", biome_b: StringName = &"") -> float:
	var a: float = openness_for_chunk_type(type_a, biome_a)
	var b: float = openness_for_chunk_type(type_b, biome_b)
	return maxf(a, b) * 0.7 + minf(a, b) * 0.3

func get_structure_node(coord: Vector2i) -> WorldStructureNode:
	return world_structure.get_node(coord) if world_structure != null else null

func get_structure_tags(coord: Vector2i) -> Array[StringName]:
	if world_structure != null:
		return world_structure.tags_for(coord)
	var empty: Array[StringName] = []
	return empty

func structure_tag_string(coord: Vector2i) -> String:
	return world_structure.tag_string_for(coord) if world_structure != null else "fallback"


func is_vertical_chamber_internal_edge(edge_x: int, chunk_y: int) -> bool:
	if world_structure == null:
		return false
	return world_structure.are_same_chamber(Vector2i(edge_x - 1, chunk_y), Vector2i(edge_x, chunk_y))

func is_horizontal_chamber_internal_edge(chunk_x: int, edge_y: int) -> bool:
	if world_structure == null:
		return false
	return world_structure.are_same_chamber(Vector2i(chunk_x, edge_y - 1), Vector2i(chunk_x, edge_y))

func is_vertical_connection_required(edge_x: int, chunk_y: int) -> bool:
	if world_structure == null:
		return false
	var left_coord := Vector2i(edge_x - 1, chunk_y)
	var right_coord := Vector2i(edge_x, chunk_y)
	return world_structure.has_connection(left_coord, &"right") or world_structure.has_connection(right_coord, &"left")

func is_horizontal_connection_required(chunk_x: int, edge_y: int) -> bool:
	if world_structure == null:
		return false
	var up_coord := Vector2i(chunk_x, edge_y - 1)
	var down_coord := Vector2i(chunk_x, edge_y)
	return world_structure.has_connection(up_coord, &"bottom") or world_structure.has_connection(down_coord, &"top")
