class_name SeedUtil
extends RefCounted

static func hash_seed(base_seed: int, salt: String) -> int:
	var value: int = hash(str(base_seed) + "::" + salt)
	if value < 0:
		value = -value
	return value

static func rng_from_seed(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

static func rng(base_seed: int, salt: String) -> RandomNumberGenerator:
	return rng_from_seed(hash_seed(base_seed, salt))

static func chunk_seed(world_seed: int, coord: Vector2i) -> int:
	return hash_seed(world_seed, "chunk_%d_%d" % [coord.x, coord.y])

static func vertical_edge_seed(world_seed: int, edge_x: int, chunk_y: int) -> int:
	return hash_seed(world_seed, "v_edge_%d_%d" % [edge_x, chunk_y])

static func horizontal_edge_seed(world_seed: int, chunk_x: int, edge_y: int) -> int:
	return hash_seed(world_seed, "h_edge_%d_%d" % [chunk_x, edge_y])
