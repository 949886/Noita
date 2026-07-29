class_name SpecialChunkPlanner
extends RefCounted

# Plans all special chunks up front from the world seed.
# This keeps chunk streaming deterministic: loading from the left or from the right
# will still produce the same special structures in the same places.
var world_seed: int = 12345
var config: WorldGenConfig
var biome_map: BiomeMap
var world_structure: WorldStructure
var placements: Array[SpecialChunkPlacement] = []
var placement_by_chunk: Dictionary = {}

func _init(p_world_seed: int, p_config: WorldGenConfig, p_biome_map: BiomeMap, p_world_structure: WorldStructure = null) -> void:
	world_seed = p_world_seed
	config = p_config
	biome_map = p_biome_map
	world_structure = p_world_structure
	_plan_chunks()
	if world_structure != null:
		for placement: SpecialChunkPlacement in placements:
			world_structure.mark_special_chunk_placement(placement)

func get_chunk_at(coord: Vector2i) -> SpecialChunkPlacement:
	return placement_by_chunk.get(coord, null) as SpecialChunkPlacement

func is_chunk_inside_special_chunk(coord: Vector2i) -> bool:
	return placement_by_chunk.has(coord)

func _plan_chunks() -> void:
	placements.clear()
	placement_by_chunk.clear()
	if config == null:
		return
	for chunk_def: SpecialChunkDef in config.special_chunk_defs:
		if chunk_def == null:
			continue
		var count: int = maxi(1, chunk_def.target_count)
		if chunk_def.unique_per_world:
			count = 1
		for index: int in range(count):
			_try_place_chunk(chunk_def, index)

func _try_place_chunk(chunk_def: SpecialChunkDef, index: int) -> void:
	var rng: RandomNumberGenerator = SeedUtil.rng(world_seed, "special_chunk_%s_%d" % [str(chunk_def.id), index])
	var candidates: Array = []
	for attempt: int in range(220):
		var y: int = rng.randi_range(chunk_def.min_depth, chunk_def.max_depth)
		var main_x: int = biome_map.get_main_path_x(y)
		var search_radius: int = 7 if world_structure != null else 4
		var x: int = main_x + rng.randi_range(-search_radius, search_radius)
		var origin: Vector2i = Vector2i(x, y)
		if not _can_place(chunk_def, origin):
			continue
		var score: float = _score_candidate(chunk_def, origin)
		if score > 0.0:
			candidates.append({"origin": origin, "score": score})
	if candidates.is_empty():
		return
	var total: float = 0.0
	for candidate: Dictionary in candidates:
		total += float(candidate.get("score", 0.0))
	var roll: float = rng.randf() * total
	for candidate: Dictionary in candidates:
		roll -= float(candidate.get("score", 0.0))
		if roll <= 0.0:
			var chosen_origin: Vector2i = candidate.get("origin", Vector2i.ZERO)
			_place(chunk_def, chosen_origin, index)
			return
	var fallback_origin: Vector2i = (candidates[candidates.size() - 1] as Dictionary).get("origin", Vector2i.ZERO)
	_place(chunk_def, fallback_origin, index)

func _can_place(chunk_def: SpecialChunkDef, origin: Vector2i) -> bool:
	if chunk_def.size_in_chunks.x < 1 or chunk_def.size_in_chunks.y < 1:
		return false
	for yy: int in range(origin.y, origin.y + chunk_def.size_in_chunks.y):
		for xx: int in range(origin.x, origin.x + chunk_def.size_in_chunks.x):
			var coord: Vector2i = Vector2i(xx, yy)
			if placement_by_chunk.has(coord):
				return false
			var biome_id: StringName = biome_map.get_biome(coord)
			if not chunk_def.allowed_biomes.is_empty() and not chunk_def.allowed_biomes.has(biome_id):
				return false
			if not chunk_def.can_overlap_main_path and biome_map.is_on_main_path(coord):
				return false
			if chunk_def.require_near_main_path and absi(coord.x - biome_map.get_main_path_x(coord.y)) > 7:
				return false
			var node: WorldStructureNode = world_structure.get_node(coord) if world_structure != null else null
			if node != null:
				if node.has_tag(&"special_chunk_occupied"):
					return false
				if chunk_def.avoid_chamber_interior and node.has_tag(&"chamber_interior"):
					return false
	# Keep a one-chunk gap so two hand-authored structures do not fight over the same border.
	for placement: SpecialChunkPlacement in placements:
		var expanded_origin: Vector2i = placement.origin_chunk - Vector2i.ONE
		var expanded_size: Vector2i = placement.size_in_chunks + Vector2i(2, 2)
		if origin.x < expanded_origin.x + expanded_size.x \
			and origin.x + chunk_def.size_in_chunks.x > expanded_origin.x \
			and origin.y < expanded_origin.y + expanded_size.y \
			and origin.y + chunk_def.size_in_chunks.y > expanded_origin.y:
			return false
	return true

func _score_candidate(chunk_def: SpecialChunkDef, origin: Vector2i) -> float:
	var score: float = maxf(0.05, chunk_def.weight) * maxf(0.05, chunk_def.placement_weight)
	var best_tag_bonus: float = 0.0
	var saw_structure: bool = false
	for yy: int in range(origin.y, origin.y + chunk_def.size_in_chunks.y):
		for xx: int in range(origin.x, origin.x + chunk_def.size_in_chunks.x):
			var coord: Vector2i = Vector2i(xx, yy)
			var node: WorldStructureNode = world_structure.get_node(coord) if world_structure != null else null
			if node == null:
				continue
			saw_structure = true
			if node.has_tag(&"branch_end"):
				best_tag_bonus += 4.0 if chunk_def.prefer_branch_end else 1.0
			if node.has_tag(&"chamber_edge"):
				best_tag_bonus += 3.5 if chunk_def.prefer_chamber_edge else 1.0
			if node.has_tag(&"path_shoulder"):
				best_tag_bonus += 1.4
			if node.has_tag(&"main_path") and not chunk_def.can_overlap_main_path:
				best_tag_bonus -= 2.0
			if node.chunk_type == BiomeMap.ChunkType.SOLID:
				best_tag_bonus -= 0.8
			for tag: StringName in chunk_def.prefer_structure_tags:
				if node.has_tag(tag):
					best_tag_bonus += 2.0
			for tag: StringName in chunk_def.avoid_structure_tags:
				if node.has_tag(tag):
					best_tag_bonus -= 4.0
	# Check one-ring neighbors so a 1x1 SpecialChunk can deliberately sit adjacent
	# to a chamber edge or branch end without occupying that structure node directly.
	if world_structure != null:
		for neighbor: Vector2i in _neighbor_ring(origin, chunk_def.size_in_chunks):
			var neighbor_node: WorldStructureNode = world_structure.get_node(neighbor)
			if neighbor_node == null:
				continue
			if neighbor_node.has_tag(&"branch_end") and chunk_def.prefer_branch_end:
				best_tag_bonus += 1.6
			if neighbor_node.has_tag(&"chamber_edge") and chunk_def.prefer_chamber_edge:
				best_tag_bonus += 2.4
			if neighbor_node.has_tag(&"main_path"):
				best_tag_bonus += 0.6
	if not saw_structure:
		best_tag_bonus += 0.2
	score += best_tag_bonus
	return maxf(score, 0.0)

func _neighbor_ring(origin: Vector2i, size_in_chunks: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x: int in range(origin.x, origin.x + size_in_chunks.x):
		result.append(Vector2i(x, origin.y - 1))
		result.append(Vector2i(x, origin.y + size_in_chunks.y))
	for y: int in range(origin.y, origin.y + size_in_chunks.y):
		result.append(Vector2i(origin.x - 1, y))
		result.append(Vector2i(origin.x + size_in_chunks.x, y))
	return result

func _place(chunk_def: SpecialChunkDef, origin: Vector2i, index: int) -> void:
	var placement: SpecialChunkPlacement = SpecialChunkPlacement.new()
	placement.id = StringName("%s_%d_%d_%d" % [str(chunk_def.id), origin.x, origin.y, index])
	placement.chunk_def = chunk_def
	placement.origin_chunk = origin
	placement.size_in_chunks = chunk_def.size_in_chunks
	placement.biome_id = biome_map.get_biome(origin)
	placement.seed = world_seed
	placements.append(placement)
	for yy: int in range(origin.y, origin.y + placement.size_in_chunks.y):
		for xx: int in range(origin.x, origin.x + placement.size_in_chunks.x):
			placement_by_chunk[Vector2i(xx, yy)] = placement

func get_vertical_profile_override(edge_x: int, chunk_y: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var left_coord: Vector2i = Vector2i(edge_x - 1, chunk_y)
	var right_coord: Vector2i = Vector2i(edge_x, chunk_y)
	var left_chunk: SpecialChunkPlacement = get_chunk_at(left_coord)
	var right_chunk: SpecialChunkPlacement = get_chunk_at(right_coord)
	if left_chunk != null and right_chunk == null:
		if edge_x == left_chunk.origin_chunk.x + left_chunk.size_in_chunks.x:
			return _slice_vertical(left_chunk.chunk_def.right_profile, chunk_y - left_chunk.origin_chunk.y, slots_per_chunk)
	elif right_chunk != null and left_chunk == null:
		if edge_x == right_chunk.origin_chunk.x:
			return _slice_vertical(right_chunk.chunk_def.left_profile, chunk_y - right_chunk.origin_chunk.y, slots_per_chunk)
	var empty: Array[PieceSocket.Socket] = []
	return empty

func get_horizontal_profile_override(chunk_x: int, edge_y: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var up_coord: Vector2i = Vector2i(chunk_x, edge_y - 1)
	var down_coord: Vector2i = Vector2i(chunk_x, edge_y)
	var up_chunk: SpecialChunkPlacement = get_chunk_at(up_coord)
	var down_chunk: SpecialChunkPlacement = get_chunk_at(down_coord)
	if up_chunk != null and down_chunk == null:
		if edge_y == up_chunk.origin_chunk.y + up_chunk.size_in_chunks.y:
			return _slice_horizontal(up_chunk.chunk_def.bottom_profile, chunk_x - up_chunk.origin_chunk.x, slots_per_chunk)
	elif down_chunk != null and up_chunk == null:
		if edge_y == down_chunk.origin_chunk.y:
			return _slice_horizontal(down_chunk.chunk_def.top_profile, chunk_x - down_chunk.origin_chunk.x, slots_per_chunk)
	var empty: Array[PieceSocket.Socket] = []
	return empty

func _slice_horizontal(profile: Array[int], local_chunk_x: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	return _slice_socket_profile(profile, local_chunk_x, slots_per_chunk)

func _slice_vertical(profile: Array[int], local_chunk_y: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	return _slice_socket_profile(profile, local_chunk_y, slots_per_chunk)

func _slice_socket_profile(profile: Array[int], local_chunk_index: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	var start: int = local_chunk_index * slots_per_chunk
	for i: int in range(start, mini(start + slots_per_chunk, profile.size())):
		result.append(PieceSocket.from_value(profile[i]))
	while result.size() < slots_per_chunk:
		result.append(PieceSocket.SOLID)
	return result
