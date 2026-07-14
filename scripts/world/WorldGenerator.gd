class_name WorldGenerator
extends RefCounted

const MODULES_PER_CHUNK: int = 8
const MIN_AIR_POCKET_SIZE: int = 1
const AIR_POCKET_ATTEMPTS: int = 16

var world_seed: int = 12345
var biome_map: BiomeMap
var edge_profile: EdgeProfile
var tile_library: TileLibrary
var config: WorldGenConfig
var special_chunk_planner: SpecialChunkPlanner
var world_structure: WorldStructure

func _init(p_world_seed: int, p_tile_library: TileLibrary, p_config: WorldGenConfig = null, p_special_chunk_planner: SpecialChunkPlanner = null, p_world_structure: WorldStructure = null) -> void:
	world_seed = p_world_seed
	tile_library = p_tile_library
	config = p_config
	special_chunk_planner = p_special_chunk_planner
	world_structure = p_world_structure
	biome_map = BiomeMap.new(world_seed, config)
	biome_map.world_structure = world_structure
	biome_map.special_chunk_planner = special_chunk_planner
	edge_profile = EdgeProfile.new(world_seed, biome_map, special_chunk_planner)

func generate_chunk(coord: Vector2i) -> ChunkData:
	var data: ChunkData = ChunkData.new(coord)
	data.biome_id = biome_map.get_biome(coord)
	data.chunk_type = biome_map.get_chunk_type(coord)
	data.structure_tags = biome_map.get_structure_tags(coord)
	var structure_node: WorldStructureNode = biome_map.get_structure_node(coord)
	if structure_node != null:
		data.chamber_id = structure_node.chamber_id
		data.chamber_origin = structure_node.chamber_origin
		data.chamber_size = structure_node.chamber_size
		data.special_chunk_id = structure_node.special_chunk_id
		data.special_chunk_origin = structure_node.special_chunk_origin
		data.special_chunk_size = structure_node.special_chunk_size
		data.special_chunk_gateway_side = structure_node.special_chunk_gateway_side
	data.structure_source = "structure_v1" if world_structure != null and world_structure.has_node(coord) else "fallback"
	data.intended_connection_count = _count_intended_connections(coord)
	var profiles: Dictionary = edge_profile.get_profiles_for_chunk(coord)
	data.top_profile = profiles["top"]
	data.bottom_profile = profiles["bottom"]
	data.left_profile = profiles["left"]
	data.right_profile = profiles["right"]
	var before_fallbacks: int = tile_library.fallback_count
	var before_compatible: int = tile_library.compatible_match_count
	data.tiles = generate_tile_grid(data)
	data.fallback_tiles = tile_library.fallback_count - before_fallbacks
	data.compatible_match_tiles = tile_library.compatible_match_count - before_compatible
	data.exact_match_tiles = maxi(0, data.tiles.size() - data.compatible_match_tiles - data.fallback_tiles)
	data.open_side_count = _count_open_sides(data)
	var min_open_sides: int = 0
	if data.chunk_type == BiomeMap.ChunkType.MAIN_PATH or data.chunk_type == BiomeMap.ChunkType.CHAMBER:
		min_open_sides = 3
	elif data.chunk_type == BiomeMap.ChunkType.CAVE or data.chunk_type == BiomeMap.ChunkType.BRANCH:
		min_open_sides = 2
	data.connectivity_adjusted = data.intended_connection_count > 0 or data.open_side_count >= min_open_sides
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
	var chamber_stats: Dictionary = _apply_chamber_carve_pass(grid, data, rng)
	data.chamber_carve_air_tiles = int(chamber_stats.get("air", 0))
	data.chamber_carve_open_tiles = int(chamber_stats.get("open", 0))
	var connectivity_stats: Dictionary = _apply_chunk_connectivity_carve_pass(grid, data, rng)
	data.connectivity_path_tiles = int(connectivity_stats.get("path_tiles", 0))
	data.connected_open_sides = int(connectivity_stats.get("open_sides", 0))
	var pocket_air_tiles: int = _apply_air_pocket_pass(grid, data, rng)
	data.air_tile_count = data.chamber_carve_air_tiles + pocket_air_tiles
	return grid

func _apply_chamber_carve_pass(grid: Array, data: ChunkData, rng: RandomNumberGenerator) -> Dictionary:
	# ChamberCarvePass turns a chamber-tagged chunk into a visibly large room.
	# AirPocketPass only adds random pockets; this pass defines the chamber's main silhouette.
	var result: Dictionary = {"air": 0, "open": 0}
	if data.chunk_type != BiomeMap.ChunkType.CHAMBER and not data.structure_tags.has(&"chamber"):
		return result
	var air_tile: TileDef = _pick_air_tile(data.biome_id, rng)
	var open_tile: TileDef = _pick_open_tile(data.biome_id, rng)
	if air_tile == null or open_tile == null:
		return result

	var chamber_origin: Vector2i = data.chamber_origin
	var chamber_size: Vector2i = data.chamber_size
	if data.chamber_id == &"":
		chamber_origin = data.coord
		chamber_size = Vector2i.ONE
	var local_chunk: Vector2i = data.coord - chamber_origin
	var total_tiles: Vector2i = chamber_size * MODULES_PER_CHUNK
	var chunk_tile_origin: Vector2i = local_chunk * MODULES_PER_CHUNK

	for y: int in range(MODULES_PER_CHUNK):
		for x: int in range(MODULES_PER_CHUNK):
			var global_tile := chunk_tile_origin + Vector2i(x, y)
			if _is_chamber_outer_border(global_tile, total_tiles):
				# The outer border remains under EdgeProfile control so entrances and
				# outside seams still match neighboring chunks and SpecialChunks.
				continue
			var index: int = y * MODULES_PER_CHUNK + x
			if _is_chamber_inner_ring(global_tile, total_tiles):
				# Open ring around the chamber gives the room a continuous readable edge.
				if rng.randf() < 0.84:
					grid[index] = open_tile
					result["open"] = int(result["open"]) + 1
				continue
			# Core: mostly AIR, with some OOOO left as natural pillars/platform mass.
			var air_chance: float = 0.78
			if data.biome_id == &"snow":
				air_chance = 0.86
			elif data.biome_id == &"deep":
				air_chance = 0.72
			if rng.randf() < air_chance:
				grid[index] = air_tile
				result["air"] = int(result["air"]) + 1
			else:
				grid[index] = open_tile
				result["open"] = int(result["open"]) + 1
	return result

func _is_chamber_outer_border(global_tile: Vector2i, total_tiles: Vector2i) -> bool:
	return global_tile.x == 0 or global_tile.y == 0 or global_tile.x == total_tiles.x - 1 or global_tile.y == total_tiles.y - 1

func _is_chamber_inner_ring(global_tile: Vector2i, total_tiles: Vector2i) -> bool:
	return global_tile.x <= 1 or global_tile.y <= 1 or global_tile.x >= total_tiles.x - 2 or global_tile.y >= total_tiles.y - 2

func _pick_open_tile(biome_id: StringName, rng: RandomNumberGenerator) -> TileDef:
	var constraints: Dictionary = {}
	constraints[&"top"] = TileDef.Edge.OPEN
	constraints[&"right"] = TileDef.Edge.OPEN
	constraints[&"bottom"] = TileDef.Edge.OPEN
	constraints[&"left"] = TileDef.Edge.OPEN
	return tile_library.pick_matching_tile(biome_id, constraints, rng)

func _apply_chunk_connectivity_carve_pass(grid: Array, data: ChunkData, rng: RandomNumberGenerator) -> Dictionary:
	# ChunkConnectivityCarvePass v2.
	# v1 connected every side entrance to one center hub and stamped OOOO, which
	# guaranteed reachability but produced obvious plus/cross structures. v2 builds
	# a small nearest-neighbor spanning tree between side entrances, then carves
	# wandering paths with direction-aware signatures. The result still connects
	# different open sides, but most carved cells become corridors/corners instead
	# of four-way OOOO intersections.
	var result: Dictionary = {"path_tiles": 0, "open_sides": 0}
	var entrances: Array = _collect_open_side_representatives(data)
	result["open_sides"] = entrances.size()
	if entrances.size() < 2:
		return result

	var connection_map: Dictionary = {}
	var touched: Dictionary = {}
	var tree_edges: Array = _build_entrance_mst_edges(entrances, rng)
	for edge: Dictionary in tree_edges:
		var a: Dictionary = edge.get("a", {})
		var b: Dictionary = edge.get("b", {})
		var start: Vector2i = a.get("cell", Vector2i.ZERO)
		var goal: Vector2i = b.get("cell", Vector2i.ZERO)
		_add_boundary_connection(connection_map, start, StringName(str(a.get("side", &""))))
		_add_boundary_connection(connection_map, goal, StringName(str(b.get("side", &""))))
		var path: Array[Vector2i] = _build_wandering_path(start, goal, rng)
		_add_path_connections(connection_map, path)

	result["path_tiles"] = _apply_directional_path_connections(grid, data.biome_id, connection_map, rng, touched)
	return result

func _collect_open_side_representatives(data: ChunkData) -> Array:
	# Pick one representative entrance per open side. The connectivity pass only
	# guarantees that different sides are connected; multiple markers on the same
	# side may remain separate local openings. This avoids over-carving the chunk.
	var entrances: Array = []
	var top_cells: Array = []
	var right_cells: Array = []
	var bottom_cells: Array = []
	var left_cells: Array = []
	for i: int in range(MODULES_PER_CHUNK):
		if i < data.top_profile.size() and _edge_is_open_like(int(data.top_profile[i])):
			top_cells.append(Vector2i(i, 0))
		if i < data.right_profile.size() and _edge_is_open_like(int(data.right_profile[i])):
			right_cells.append(Vector2i(MODULES_PER_CHUNK - 1, i))
		if i < data.bottom_profile.size() and _edge_is_open_like(int(data.bottom_profile[i])):
			bottom_cells.append(Vector2i(i, MODULES_PER_CHUNK - 1))
		if i < data.left_profile.size() and _edge_is_open_like(int(data.left_profile[i])):
			left_cells.append(Vector2i(0, i))
	_add_side_representative(entrances, &"top", top_cells)
	_add_side_representative(entrances, &"right", right_cells)
	_add_side_representative(entrances, &"bottom", bottom_cells)
	_add_side_representative(entrances, &"left", left_cells)
	return entrances

func _add_side_representative(entrances: Array, side: StringName, cells: Array) -> void:
	if cells.is_empty():
		return
	# The middle marker of a contiguous or scattered side opening is usually the
	# best representative entrance for a readable local tunnel.
	var cell: Vector2i = cells[int(cells.size() / 2)]
	entrances.append({"side": side, "cell": cell})

func _edge_is_open_like(edge_value: int) -> bool:
	return edge_value == TileDef.Edge.OPEN or edge_value == TileDef.Edge.AIR

func _build_entrance_mst_edges(entrances: Array, rng: RandomNumberGenerator) -> Array:
	# A lightweight Prim-style MST over at most four side representatives. This is
	# enough to avoid the old hub shape while still making all sides mutually reachable.
	var edges: Array = []
	if entrances.size() < 2:
		return edges
	var connected: Array = [0]
	var remaining: Array = []
	for i: int in range(1, entrances.size()):
		remaining.append(i)
	while not remaining.is_empty():
		var best_connected_index: int = int(connected[0])
		var best_remaining_index: int = int(remaining[0])
		var best_score: int = 999999
		for connected_index in connected:
			var a_cell: Vector2i = (entrances[int(connected_index)] as Dictionary).get("cell", Vector2i.ZERO)
			for remaining_index in remaining:
				var b_cell: Vector2i = (entrances[int(remaining_index)] as Dictionary).get("cell", Vector2i.ZERO)
				var score: int = abs(a_cell.x - b_cell.x) + abs(a_cell.y - b_cell.y)
				# Deterministic jitter breaks ties so the same set of sides does not always
				# choose the same geometric chain pattern.
				score = score * 10 + rng.randi_range(0, 3)
				if score < best_score:
					best_score = score
					best_connected_index = int(connected_index)
					best_remaining_index = int(remaining_index)
		edges.append({"a": entrances[best_connected_index], "b": entrances[best_remaining_index]})
		connected.append(best_remaining_index)
		remaining.erase(best_remaining_index)
	return edges

func _build_wandering_path(start: Vector2i, goal: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	# Biased random walk: usually step toward the target, sometimes take a small
	# sideways move. This keeps paths organic without sacrificing deterministic reachability.
	var path: Array[Vector2i] = [start]
	var current: Vector2i = start
	var visited: Dictionary = {}
	visited[_cell_key(current)] = true
	var max_steps: int = 32
	for step_index: int in range(max_steps):
		if current == goal:
			break
		var step: Vector2i = _pick_wandering_step(current, goal, rng, visited)
		if step == Vector2i.ZERO:
			break
		current += step
		current.x = clampi(current.x, 0, MODULES_PER_CHUNK - 1)
		current.y = clampi(current.y, 0, MODULES_PER_CHUNK - 1)
		path.append(current)
		visited[_cell_key(current)] = true
	# If the wander did not reach the target quickly enough, finish with a compact
	# randomized Manhattan tail. This preserves the guarantee that the sides connect.
	while current != goal:
		var prefer_x: bool = abs(goal.x - current.x) >= abs(goal.y - current.y)
		if rng.randf() < 0.35:
			prefer_x = not prefer_x
		if prefer_x and current.x != goal.x:
			current.x += 1 if goal.x > current.x else -1
		elif current.y != goal.y:
			current.y += 1 if goal.y > current.y else -1
		elif current.x != goal.x:
			current.x += 1 if goal.x > current.x else -1
		path.append(current)
	return path

func _pick_wandering_step(current: Vector2i, goal: Vector2i, rng: RandomNumberGenerator, visited: Dictionary) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var weights: Array[float] = []
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	var current_dist: int = abs(goal.x - current.x) + abs(goal.y - current.y)
	for dir: Vector2i in dirs:
		var next: Vector2i = current + dir
		if next.x < 0 or next.x >= MODULES_PER_CHUNK or next.y < 0 or next.y >= MODULES_PER_CHUNK:
			continue
		var next_dist: int = abs(goal.x - next.x) + abs(goal.y - next.y)
		var weight: float = 1.0
		if next_dist < current_dist:
			weight = 5.0
		elif next_dist == current_dist:
			weight = 1.3
		else:
			weight = 0.25
		if visited.has(_cell_key(next)):
			weight *= 0.25
		# Avoid hugging the outer border for too long unless this is the target edge.
		if _is_outer_cell(next) and next != goal:
			weight *= 0.35
		if weight <= 0.05:
			continue
		candidates.append(dir)
		weights.append(weight)
	if candidates.is_empty():
		return Vector2i.ZERO
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for i: int in range(candidates.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]

func _add_path_connections(connection_map: Dictionary, path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	for i: int in range(path.size() - 1):
		_add_segment_connection(connection_map, path[i], path[i + 1])

func _add_segment_connection(connection_map: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var delta: Vector2i = b - a
	if delta == Vector2i.RIGHT:
		_add_connection_dir(connection_map, a, &"right")
		_add_connection_dir(connection_map, b, &"left")
	elif delta == Vector2i.LEFT:
		_add_connection_dir(connection_map, a, &"left")
		_add_connection_dir(connection_map, b, &"right")
	elif delta == Vector2i.DOWN:
		_add_connection_dir(connection_map, a, &"bottom")
		_add_connection_dir(connection_map, b, &"top")
	elif delta == Vector2i.UP:
		_add_connection_dir(connection_map, a, &"top")
		_add_connection_dir(connection_map, b, &"bottom")

func _add_boundary_connection(connection_map: Dictionary, cell: Vector2i, side: StringName) -> void:
	match side:
		&"top":
			_add_connection_dir(connection_map, cell, &"top")
		&"right":
			_add_connection_dir(connection_map, cell, &"right")
		&"bottom":
			_add_connection_dir(connection_map, cell, &"bottom")
		&"left":
			_add_connection_dir(connection_map, cell, &"left")

func _add_connection_dir(connection_map: Dictionary, cell: Vector2i, side: StringName) -> void:
	if cell.x < 0 or cell.x >= MODULES_PER_CHUNK or cell.y < 0 or cell.y >= MODULES_PER_CHUNK:
		return
	var key: String = _cell_key(cell)
	var mask: int = int(connection_map.get(key, 0))
	mask |= _dir_bit(side)
	connection_map[key] = mask

func _apply_directional_path_connections(grid: Array, biome_id: StringName, connection_map: Dictionary, rng: RandomNumberGenerator, touched: Dictionary) -> int:
	for key in connection_map.keys():
		var cell: Vector2i = _key_to_cell(str(key))
		if cell.x < 0 or cell.x >= MODULES_PER_CHUNK or cell.y < 0 or cell.y >= MODULES_PER_CHUNK:
			continue
		var index: int = cell.y * MODULES_PER_CHUNK + cell.x
		var existing: TileDef = grid[index] as TileDef
		if existing != null and existing.signature() == TileConstants.AIR_SIGNATURE:
			touched[key] = true
			continue
		var mask: int = int(connection_map[key])
		var constraints: Dictionary = _merged_constraints_from_mask(existing, mask)
		var tile: TileDef = tile_library.pick_matching_tile(biome_id, constraints, rng)
		if tile != null:
			grid[index] = tile
			touched[key] = true
	return touched.size()

func _merged_constraints_from_mask(existing: TileDef, mask: int) -> Dictionary:
	var top_open: bool = (mask & _dir_bit(&"top")) != 0
	var right_open: bool = (mask & _dir_bit(&"right")) != 0
	var bottom_open: bool = (mask & _dir_bit(&"bottom")) != 0
	var left_open: bool = (mask & _dir_bit(&"left")) != 0
	if existing != null:
		top_open = top_open or _edge_is_open_like(existing.top)
		right_open = right_open or _edge_is_open_like(existing.right)
		bottom_open = bottom_open or _edge_is_open_like(existing.bottom)
		left_open = left_open or _edge_is_open_like(existing.left)
	return {
		&"top": TileDef.Edge.OPEN if top_open else TileDef.Edge.SOLID,
		&"right": TileDef.Edge.OPEN if right_open else TileDef.Edge.SOLID,
		&"bottom": TileDef.Edge.OPEN if bottom_open else TileDef.Edge.SOLID,
		&"left": TileDef.Edge.OPEN if left_open else TileDef.Edge.SOLID,
	}

func _dir_bit(side: StringName) -> int:
	match side:
		&"top": return 1
		&"right": return 2
		&"bottom": return 4
		&"left": return 8
		_: return 0

func _cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)

func _key_to_cell(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _is_outer_cell(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.x == MODULES_PER_CHUNK - 1 or cell.y == 0 or cell.y == MODULES_PER_CHUNK - 1

func _apply_air_pocket_pass(grid: Array, data: ChunkData, rng: RandomNumberGenerator) -> int:
	# AIR is an internal empty-space pass. It never edits the outer chunk border,
	# so chunk-to-chunk seams continue to be governed only by SOLID/OPEN EdgeProfile data.
	var chance: float = _air_pocket_chance(data.biome_id, data.chunk_type)
	if rng.randf() > chance:
		return 0
	var pocket_count: int = _pick_air_pocket_count(data.biome_id, data.chunk_type, rng)
	var changed: int = 0
	var placed: int = 0
	for i: int in range(pocket_count):
		var pocket_tiles: int = _try_place_air_pocket(grid, data, rng)
		if pocket_tiles > 0:
			placed += 1
		changed += pocket_tiles
	data.air_pocket_count = placed
	return changed

func _pick_air_pocket_count(biome_id: StringName, chunk_type: int, rng: RandomNumberGenerator) -> int:
	# More connected chunks can support more pockets. Snow intentionally receives
	# the most pockets so it reads as larger ice caves instead of isolated dots.
	var count: int = 1
	match chunk_type:
		BiomeMap.ChunkType.MAIN_PATH:
			count = 1 + rng.randi_range(0, 1)
			if rng.randf() < (0.45 if biome_id == &"snow" else 0.25):
				count += 1
		BiomeMap.ChunkType.CAVE, BiomeMap.ChunkType.BRANCH:
			count = 1
			if rng.randf() < (0.50 if biome_id == &"snow" else 0.30):
				count += 1
		BiomeMap.ChunkType.CHAMBER:
			count = 2 + rng.randi_range(0, 1)
		BiomeMap.ChunkType.SOLID:
			count = 1
		_:
			count = 1
	return count

func _try_place_air_pocket(grid: Array, data: ChunkData, rng: RandomNumberGenerator) -> int:
	var size: Vector2i = _pick_air_pocket_size(data.biome_id, data.chunk_type, rng)
	for attempt: int in range(AIR_POCKET_ATTEMPTS):
		var max_x: int = MODULES_PER_CHUNK - 1 - size.x
		var max_y: int = MODULES_PER_CHUNK - 1 - size.y
		if max_x < 1 or max_y < 1:
			return 0
		var origin: Vector2i = Vector2i(rng.randi_range(1, max_x), rng.randi_range(1, max_y))
		var candidates: Array[Vector2i] = _collect_air_candidates(grid, origin, size, data.biome_id)
		var minimum_cells: int = maxi(MIN_AIR_POCKET_SIZE, int(ceil(float(size.x * size.y) * 0.45)))
		if candidates.size() < minimum_cells:
			continue
		var air_tile: TileDef = _pick_air_tile(data.biome_id, rng)
		if air_tile == null:
			return 0
		for cell: Vector2i in candidates:
			grid[cell.y * MODULES_PER_CHUNK + cell.x] = air_tile
		return candidates.size()
	return 0

func _collect_air_candidates(grid: Array, origin: Vector2i, size: Vector2i, biome_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			# Keep AIR away from the outer edge until a later transition/deco system handles it explicitly.
			if x <= 0 or x >= MODULES_PER_CHUNK - 1 or y <= 0 or y >= MODULES_PER_CHUNK - 1:
				continue
			var tile: TileDef = grid[y * MODULES_PER_CHUNK + x] as TileDef
			if tile == null:
				continue
			if _is_air_candidate(tile, biome_id):
				result.append(Vector2i(x, y))
	return result

func _is_air_candidate(tile: TileDef, biome_id: StringName) -> bool:
	# AIR replaces already-open cave cells. Mine/deep require at least three open
	# sides; snow allows two to make larger ice caves more common.
	if tile.is_fallback or tile.tile_role != TileDef.TileRole.WANG:
		return false
	if tile.signature() == TileConstants.AIR_SIGNATURE:
		return true
	var open_count: int = 0
	var edges: Array[int] = [tile.top, tile.right, tile.bottom, tile.left]
	for edge_value: int in edges:
		if edge_value == TileDef.Edge.OPEN or edge_value == TileDef.Edge.AIR:
			open_count += 1
	var threshold: int = 2 if biome_id == &"snow" else 3
	return open_count >= threshold

func _pick_air_tile(biome_id: StringName, rng: RandomNumberGenerator) -> TileDef:
	var constraints: Dictionary = {}
	constraints[&"top"] = TileDef.Edge.AIR
	constraints[&"right"] = TileDef.Edge.AIR
	constraints[&"bottom"] = TileDef.Edge.AIR
	constraints[&"left"] = TileDef.Edge.AIR
	return tile_library.pick_matching_tile(biome_id, constraints, rng)

func _air_pocket_chance(biome_id: StringName, chunk_type: int) -> float:
	match biome_id:
		&"snow":
			match chunk_type:
				BiomeMap.ChunkType.MAIN_PATH: return 0.70
				BiomeMap.ChunkType.CAVE, BiomeMap.ChunkType.BRANCH: return 0.52
				BiomeMap.ChunkType.CHAMBER: return 0.82
				BiomeMap.ChunkType.SOLID: return 0.16
		&"deep":
			match chunk_type:
				BiomeMap.ChunkType.MAIN_PATH: return 0.42
				BiomeMap.ChunkType.CAVE, BiomeMap.ChunkType.BRANCH: return 0.30
				BiomeMap.ChunkType.CHAMBER: return 0.58
				BiomeMap.ChunkType.SOLID: return 0.08
		_:
			match chunk_type:
				BiomeMap.ChunkType.MAIN_PATH: return 0.48
				BiomeMap.ChunkType.CAVE, BiomeMap.ChunkType.BRANCH: return 0.34
				BiomeMap.ChunkType.CHAMBER: return 0.66
				BiomeMap.ChunkType.SOLID: return 0.10
	return 0.25

func _pick_air_pocket_size(biome_id: StringName, chunk_type: int, rng: RandomNumberGenerator) -> Vector2i:
	var sizes: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2),
	]
	if chunk_type != BiomeMap.ChunkType.SOLID:
		sizes.append(Vector2i(2, 3))
		sizes.append(Vector2i(3, 2))
		sizes.append(Vector2i(1, 3))
		sizes.append(Vector2i(3, 1))
	if chunk_type == BiomeMap.ChunkType.CHAMBER:
		sizes.append(Vector2i(2, 4))
		sizes.append(Vector2i(4, 2))
		sizes.append(Vector2i(3, 3))
		sizes.append(Vector2i(3, 4))
		sizes.append(Vector2i(4, 3))
	elif biome_id == &"snow" and chunk_type != BiomeMap.ChunkType.SOLID:
		sizes.append(Vector2i(2, 4))
		sizes.append(Vector2i(4, 2))
		sizes.append(Vector2i(3, 3))
	elif chunk_type == BiomeMap.ChunkType.MAIN_PATH:
		sizes.append(Vector2i(2, 4))
		sizes.append(Vector2i(4, 2))
	return sizes[rng.randi_range(0, sizes.size() - 1)]

func _count_intended_connections(coord: Vector2i) -> int:
	if world_structure == null:
		return 0
	var node: WorldStructureNode = world_structure.get_node(coord)
	if node == null:
		return 0
	var count: int = 0
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		if node.has_connection(side):
			count += 1
	return count

func _count_open_sides(data: ChunkData) -> int:
	var count: int = 0
	if _profile_has_open(data.top_profile):
		count += 1
	if _profile_has_open(data.right_profile):
		count += 1
	if _profile_has_open(data.bottom_profile):
		count += 1
	if _profile_has_open(data.left_profile):
		count += 1
	return count

func _profile_has_open(profile: Array[int]) -> bool:
	for edge_value: int in profile:
		if edge_value == TileDef.Edge.OPEN or edge_value == TileDef.Edge.AIR:
			return true
	return false
