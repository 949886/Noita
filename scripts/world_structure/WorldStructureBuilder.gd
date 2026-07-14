class_name WorldStructureBuilder
extends RefCounted

# Builds a deterministic chunk-level plan: a continuous main path, side branches,
# and natural chamber regions. This layer gives the local Wang generator a goal
# instead of letting every chunk decide its role independently.

const STRUCTURE_MIN_X: int = -16
const STRUCTURE_MAX_X: int = 16
const STRUCTURE_MIN_Y: int = 0
const STRUCTURE_MAX_Y: int = 96

var world_seed: int = 12345
var config: WorldGenConfig
var rng: RandomNumberGenerator
var structure: WorldStructure
var chamber_counter: int = 0

func _init(p_world_seed: int, p_config: WorldGenConfig = null) -> void:
	world_seed = p_world_seed
	config = p_config
	rng = SeedUtil.rng(world_seed, "world_structure_v1")

func build() -> WorldStructure:
	structure = WorldStructure.new()
	structure.min_x = STRUCTURE_MIN_X
	structure.max_x = STRUCTURE_MAX_X
	structure.min_y = STRUCTURE_MIN_Y
	structure.max_y = STRUCTURE_MAX_Y
	_fill_default_nodes()
	_build_main_path()
	_build_side_branches()
	_place_chambers()
	return structure

func _fill_default_nodes() -> void:
	for y: int in range(STRUCTURE_MIN_Y, STRUCTURE_MAX_Y + 1):
		for x: int in range(STRUCTURE_MIN_X, STRUCTURE_MAX_X + 1):
			var coord := Vector2i(x, y)
			var node := WorldStructureNode.new(coord, _biome_for_y(y), BiomeMap.ChunkType.SOLID)
			node.add_tag(&"structure_v1")
			structure.set_node(node)

func _build_main_path() -> void:
	var x: int = 0
	var previous_coord := Vector2i(x, STRUCTURE_MIN_Y)
	_mark_main_path(previous_coord)
	structure.set_main_path_x(STRUCTURE_MIN_Y, x)
	for y: int in range(STRUCTURE_MIN_Y + 1, STRUCTURE_MAX_Y + 1):
		# Move vertically first, then optionally carve a same-row horizontal kink.
		var vertical_coord := Vector2i(x, y)
		_mark_main_path(vertical_coord)
		_connect(previous_coord, vertical_coord)
		previous_coord = vertical_coord
		if rng.randf() < _main_path_wander_chance(y):
			var old_x: int = x
			x = clampi(x + rng.randi_range(-1, 1), -6, 6)
			if x != old_x:
				var kink_coord := Vector2i(x, y)
				_mark_main_path(kink_coord)
				_connect(previous_coord, kink_coord)
				previous_coord = kink_coord
		structure.set_main_path_x(y, x)
		_mark_path_shoulders(Vector2i(x, y))

func _main_path_wander_chance(y: int) -> float:
	var biome_id: StringName = _biome_for_y(y)
	match biome_id:
		&"snow": return 0.42
		&"deep": return 0.28
		_: return 0.34

func _mark_main_path(coord: Vector2i) -> void:
	var node := _node(coord)
	if node == null:
		return
	node.chunk_type = BiomeMap.ChunkType.MAIN_PATH
	node.add_tag(&"main_path")
	node.add_tag(&"path_core")

func _mark_path_shoulders(coord: Vector2i) -> void:
	for dx: int in [-1, 1]:
		if rng.randf() > 0.72:
			continue
		var shoulder_coord := coord + Vector2i(dx, 0)
		var node := _node(shoulder_coord)
		if node == null or node.chunk_type == BiomeMap.ChunkType.MAIN_PATH:
			continue
		node.chunk_type = BiomeMap.ChunkType.CAVE
		node.add_tag(&"path_shoulder")
		_connect(coord, shoulder_coord)

func _build_side_branches() -> void:
	var y: int = STRUCTURE_MIN_Y + 2
	while y <= STRUCTURE_MAX_Y - 3:
		var biome_id: StringName = _biome_for_y(y)
		var branch_chance: float = 0.68 if biome_id == &"snow" else 0.56 if biome_id == &"mine" else 0.46
		if rng.randf() < branch_chance:
			var start := Vector2i(structure.get_main_path_x(y), y)
			var dir: int = -1 if rng.randf() < 0.5 else 1
			var length: int = rng.randi_range(2, 5 if biome_id != &"deep" else 4)
			_build_branch(start, dir, length, rng.randf() < (0.32 if biome_id != &"deep" else 0.18))
		y += rng.randi_range(2, 4)

func _build_branch(start: Vector2i, dir: int, length: int, make_loop: bool) -> void:
	var current := start
	var previous := start
	for i: int in range(1, length + 1):
		var step_y: int = 1 if i > 1 and rng.randf() < 0.30 else 0
		var next := current + Vector2i(dir, step_y)
		if not _inside(next):
			break
		var node := _node(next)
		if node == null:
			break
		if node.chunk_type != BiomeMap.ChunkType.MAIN_PATH and node.chunk_type != BiomeMap.ChunkType.CHAMBER:
			node.chunk_type = BiomeMap.ChunkType.BRANCH
		node.add_tag(&"branch")
		if make_loop:
			node.add_tag(&"loop_branch")
		_connect(current, next)
		previous = current
		current = next
	if make_loop:
		var target_y: int = clampi(current.y + rng.randi_range(1, 3), STRUCTURE_MIN_Y, STRUCTURE_MAX_Y)
		var target := Vector2i(structure.get_main_path_x(target_y), target_y)
		_carve_corridor(current, target, &"loop_branch")
	else:
		var end_node := _node(current)
		if end_node != null and current != start:
			end_node.add_tag(&"branch_end")

func _place_chambers() -> void:
	for y: int in range(STRUCTURE_MIN_Y + 4, STRUCTURE_MAX_Y - 4, 5):
		var biome_id: StringName = _biome_for_y(y)
		var chance: float = 0.54 if biome_id == &"snow" else 0.38 if biome_id == &"mine" else 0.28
		if rng.randf() > chance:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var offset: int = rng.randi_range(3, 7)
		var size := _pick_chamber_size(biome_id)
		var main := Vector2i(structure.get_main_path_x(y), y)
		var origin := main + Vector2i(side * offset, rng.randi_range(-1, 1))
		origin.x = clampi(origin.x, STRUCTURE_MIN_X + 1, STRUCTURE_MAX_X - size.x - 1)
		origin.y = clampi(origin.y, STRUCTURE_MIN_Y + 1, STRUCTURE_MAX_Y - size.y - 1)
		if not _can_place_chamber(origin, size):
			continue
		_mark_chamber(origin, size)
		var entrance := Vector2i(origin.x if side > 0 else origin.x + size.x - 1, origin.y + int(size.y / 2))
		_carve_corridor(main, entrance, &"chamber_connector")

func _pick_chamber_size(biome_id: StringName) -> Vector2i:
	var sizes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	if biome_id == &"snow":
		sizes.append(Vector2i(2, 2))
		sizes.append(Vector2i(2, 1))
		sizes.append(Vector2i(1, 2))
	elif biome_id == &"mine":
		sizes.append(Vector2i(2, 2))
	return sizes[rng.randi_range(0, sizes.size() - 1)]

func _can_place_chamber(origin: Vector2i, size: Vector2i) -> bool:
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			var node := _node(Vector2i(x, y))
			if node == null:
				return false
			if node.chunk_type == BiomeMap.ChunkType.MAIN_PATH or node.chunk_type == BiomeMap.ChunkType.CHAMBER:
				return false
	return true

func _mark_chamber(origin: Vector2i, size: Vector2i) -> void:
	chamber_counter += 1
	var chamber_id: StringName = StringName("chamber_%03d" % chamber_counter)
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			var coord := Vector2i(x, y)
			var node := _node(coord)
			if node == null:
				continue
			node.chunk_type = BiomeMap.ChunkType.CHAMBER
			node.chamber_id = chamber_id
			node.chamber_origin = origin
			node.chamber_size = size
			node.add_tag(&"chamber")
			if size.x <= 2 and size.y <= 2:
				# Current demo chambers are small; every occupied chunk is useful as a visible edge anchor.
				node.add_tag(&"chamber_edge")
			else:
				var is_edge: bool = x == origin.x or y == origin.y or x == origin.x + size.x - 1 or y == origin.y + size.y - 1
				node.add_tag(&"chamber_edge" if is_edge else &"chamber_interior")
			node.add_tag(StringName("chamber_%dx%d" % [size.x, size.y]))
			var right := coord + Vector2i.RIGHT
			var bottom := coord + Vector2i.DOWN
			if right.x < origin.x + size.x:
				_connect(coord, right)
			if bottom.y < origin.y + size.y:
				_connect(coord, bottom)

func _carve_corridor(from_coord: Vector2i, to_coord: Vector2i, tag: StringName) -> void:
	var current := from_coord
	while current.x != to_coord.x:
		var next := current + Vector2i(1 if to_coord.x > current.x else -1, 0)
		_mark_corridor_node(next, tag)
		_connect(current, next)
		current = next
	while current.y != to_coord.y:
		var next := current + Vector2i(0, 1 if to_coord.y > current.y else -1)
		_mark_corridor_node(next, tag)
		_connect(current, next)
		current = next

func _mark_corridor_node(coord: Vector2i, tag: StringName) -> void:
	var node := _node(coord)
	if node == null:
		return
	if node.chunk_type == BiomeMap.ChunkType.SOLID:
		node.chunk_type = BiomeMap.ChunkType.BRANCH
	node.add_tag(tag)
	if tag == &"chamber_connector":
		node.add_tag(&"branch")

func _connect(a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	var delta := b - a
	if absi(delta.x) + absi(delta.y) != 1:
		return
	var node_a := _node(a)
	var node_b := _node(b)
	if node_a == null or node_b == null:
		return
	if delta == Vector2i.RIGHT:
		node_a.set_connection(&"right")
		node_b.set_connection(&"left")
	elif delta == Vector2i.LEFT:
		node_a.set_connection(&"left")
		node_b.set_connection(&"right")
	elif delta == Vector2i.DOWN:
		node_a.set_connection(&"bottom")
		node_b.set_connection(&"top")
	elif delta == Vector2i.UP:
		node_a.set_connection(&"top")
		node_b.set_connection(&"bottom")

func _node(coord: Vector2i) -> WorldStructureNode:
	return structure.get_node(coord)

func _inside(coord: Vector2i) -> bool:
	return coord.x >= STRUCTURE_MIN_X and coord.x <= STRUCTURE_MAX_X and coord.y >= STRUCTURE_MIN_Y and coord.y <= STRUCTURE_MAX_Y

func _biome_for_y(y: int) -> StringName:
	if config != null and config.biome_configs.size() > 0:
		for biome_config: BiomeConfig in config.biome_configs:
			if biome_config != null and y >= biome_config.depth_min and y <= biome_config.depth_max:
				return biome_config.id
	if y < 5:
		return &"mine"
	elif y < 10:
		return &"snow"
	return &"deep"
