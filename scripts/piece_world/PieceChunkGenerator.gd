class_name PieceChunkGenerator
extends RefCounted

var world_seed: int = 12345
var library: PieceLibrary

func _init(p_seed: int, p_library: PieceLibrary) -> void:
	world_seed = p_seed
	library = p_library

func generate_chunk(coord: Vector2i) -> PieceChunkData:
	var data: PieceChunkData = PieceChunkData.new()
	data.coord = coord
	data.biome_id = _biome_for(coord)
	data.chunk_type = _chunk_type_for(coord)
	data.structure_tags = _tags_for(data.chunk_type)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _chunk_seed(coord)
	var occupied: Array = []
	occupied.resize(PieceWorldConstants.CHUNK_UNITS * PieceWorldConstants.CHUNK_UNITS)
	for i: int in range(occupied.size()): occupied[i] = false
	data.visual_image = Image.create_empty(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	data.visual_image.fill(Color.TRANSPARENT)
	data.material_image = Image.create_empty(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	data.material_image.fill(Color.TRANSPARENT)
	_place_prefabs(data, occupied, rng)
	_fill_glue(data, occupied, rng)
	data.texture = ImageTexture.create_from_image(data.visual_image)
	data.piece_count = data.placements.size()
	return data

func _place_prefabs(data: PieceChunkData, occupied: Array, rng: RandomNumberGenerator) -> void:
	var desired_tags: Array[StringName] = []
	match data.chunk_type:
		&"chamber": desired_tags = [&"room", &"cave_room", &"symbol"]
		&"main_path": desired_tags = [&"room", &"lab", &"horizontal"]
		&"branch": desired_tags = [&"tank", &"vertical", &"room"]
		_: desired_tags = [&"cave_room"]
	var attempts: int = 5 if data.chunk_type != &"solid" else 2
	for i: int in range(attempts):
		var max_size: Vector2i = Vector2i(2, 2)
		var candidates: Array[PieceDef] = library.candidates_for(data.biome_id, desired_tags, max_size)
		if candidates.is_empty():
			return
		var best_piece: PieceDef = null
		var best_pos: Vector2i = Vector2i(-1, -1)
		var best_score: int = -1
		for trial: int in range(28):
			var piece: PieceDef = library.weighted_pick(candidates, rng)
			if piece == null:
				continue
			var pos: Vector2i = _find_empty_spot(occupied, piece.size_units, rng)
			if pos.x < 0:
				continue
			var score: int = _placement_match_score(data, occupied, piece, pos)
			if score < 0:
				continue
			if score > best_score:
				best_score = score
				best_piece = piece
				best_pos = pos
				if score >= 400:
					break
		if best_piece != null and best_pos.x >= 0:
			_add_piece(data, occupied, best_piece, best_pos)

func _find_empty_spot(occupied: Array, size_units: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var possible: Array[Vector2i] = []
	for y: int in range(PieceWorldConstants.CHUNK_UNITS - size_units.y + 1):
		for x: int in range(PieceWorldConstants.CHUNK_UNITS - size_units.x + 1):
			var ok: bool = true
			for yy: int in range(size_units.y):
				for xx: int in range(size_units.x):
					if occupied[(y + yy) * PieceWorldConstants.CHUNK_UNITS + (x + xx)]: ok = false
			if ok: possible.append(Vector2i(x, y))
	if possible.is_empty():
		return Vector2i(-1, -1)
	return possible[rng.randi_range(0, possible.size() - 1)]

func _placement_match_score(data: PieceChunkData, occupied: Array, piece: PieceDef, unit_pos: Vector2i) -> int:
	var total: int = 0
	var checked: int = 0
	for y: int in range(piece.size_units.y):
		for x: int in range(piece.size_units.x):
			var cell: Vector2i = unit_pos + Vector2i(x, y)
			var sides: Array[StringName] = [&"top", &"right", &"bottom", &"left"]
			for side: StringName in sides:
				if not _is_outer_piece_side(piece, Vector2i(x, y), side):
					continue
				var neighbor_pos: Vector2i = cell + _side_dir(side)
				if not _unit_in_chunk(neighbor_pos):
					continue
				if not occupied[neighbor_pos.y * PieceWorldConstants.CHUNK_UNITS + neighbor_pos.x]:
					continue
				var socket_a: StringName = _piece_socket_for_local_side(piece, Vector2i(x, y), side)
				var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
				if neighbor == null:
					continue
				var socket_b: StringName = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
				var score: int = PieceSocket.compatibility_score(socket_a, socket_b)
				if score < 60:
					return -1
				total += score
				checked += 1
	if checked == 0:
		return 10
	return total

func _unit_in_chunk(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < PieceWorldConstants.CHUNK_UNITS and pos.y < PieceWorldConstants.CHUNK_UNITS

func _side_dir(side: StringName) -> Vector2i:
	match side:
		&"top": return Vector2i(0, -1)
		&"right": return Vector2i(1, 0)
		&"bottom": return Vector2i(0, 1)
		&"left": return Vector2i(-1, 0)
	return Vector2i.ZERO

func _opposite_side(side: StringName) -> StringName:
	match side:
		&"top": return &"bottom"
		&"right": return &"left"
		&"bottom": return &"top"
		&"left": return &"right"
	return &""

func _is_outer_piece_side(piece: PieceDef, local: Vector2i, side: StringName) -> bool:
	match side:
		&"top": return local.y == 0
		&"right": return local.x == piece.size_units.x - 1
		&"bottom": return local.y == piece.size_units.y - 1
		&"left": return local.x == 0
	return false

func _piece_socket_for_local_side(piece: PieceDef, local: Vector2i, side: StringName) -> StringName:
	var slots: Array[StringName] = piece.normalized_slots(side)
	var slot_index: int = local.x if (side == &"top" or side == &"bottom") else local.y
	if slot_index >= 0 and slot_index < slots.size():
		return slots[slot_index]
	return &"solid"

func _placement_at_unit(data: PieceChunkData, unit: Vector2i) -> PiecePlacement:
	for placement: PiecePlacement in data.placements:
		var rect: Rect2i = Rect2i(placement.unit_pos, placement.size_units)
		if rect.has_point(unit):
			return placement
	return null

func _placement_socket_for_unit_side(placement: PiecePlacement, unit: Vector2i, side: StringName) -> StringName:
	if placement.is_glue:
		var socket_value: Variant = placement.sockets.get(side, &"solid")
		return StringName(str(socket_value))
	if placement.piece_def == null:
		return &"solid"
	var local: Vector2i = unit - placement.unit_pos
	if not _is_outer_piece_side(placement.piece_def, local, side):
		return &"solid"
	return _piece_socket_for_local_side(placement.piece_def, local, side)

func _add_piece(data: PieceChunkData, occupied: Array, piece: PieceDef, unit_pos: Vector2i) -> void:
	var placement: PiecePlacement = PiecePlacement.new()
	placement.piece_def = piece
	placement.id = piece.id
	placement.unit_pos = unit_pos
	placement.size_units = piece.size_units
	placement.is_glue = false
	data.placements.append(placement)
	for y: int in range(piece.size_units.y):
		for x: int in range(piece.size_units.x):
			occupied[(unit_pos.y + y) * PieceWorldConstants.CHUNK_UNITS + (unit_pos.x + x)] = true
	_paste_piece_texture(data.visual_image, piece.texture, placement.pixel_rect(PieceWorldConstants.UNIT_SIZE))
	_paste_piece_texture(data.material_image, piece.material_texture if piece.material_texture != null else piece.texture, placement.pixel_rect(PieceWorldConstants.UNIT_SIZE))

func _paste_piece_texture(target: Image, tex: Texture2D, dst_rect: Rect2i) -> void:
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	img = img.duplicate()
	if img.is_compressed():
		var err: Error = img.decompress()
		if err != OK:
			push_warning("Could not decompress piece texture image before blit.")
			return
	if img.get_format() != target.get_format():
		img.convert(target.get_format())
	if img.get_size() != dst_rect.size:
		img.resize(dst_rect.size.x, dst_rect.size.y, Image.INTERPOLATE_NEAREST)
	if img.get_format() != target.get_format():
		img.convert(target.get_format())
	target.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), dst_rect.position)

func _fill_glue(data: PieceChunkData, occupied: Array, rng: RandomNumberGenerator) -> void:
	for y: int in range(PieceWorldConstants.CHUNK_UNITS):
		for x: int in range(PieceWorldConstants.CHUNK_UNITS):
			if occupied[y * PieceWorldConstants.CHUNK_UNITS + x]: continue
			var sockets: Dictionary = _glue_sockets_for(data, Vector2i(x, y), rng)
			var top_socket: StringName = StringName(str(sockets[&"top"]))
			var right_socket: StringName = StringName(str(sockets[&"right"]))
			var bottom_socket: StringName = StringName(str(sockets[&"bottom"]))
			var left_socket: StringName = StringName(str(sockets[&"left"]))
			var glue: Image = GluePieceGenerator.generate(data.biome_id, top_socket, right_socket, bottom_socket, left_socket, int(_chunk_seed(data.coord) + x * 77 + y * 313))
			var rect: Rect2i = Rect2i(Vector2i(x, y) * PieceWorldConstants.UNIT_SIZE, Vector2i.ONE * PieceWorldConstants.UNIT_SIZE)
			data.visual_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
			data.material_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
			var placement: PiecePlacement = PiecePlacement.new()
			placement.id = &"generated_glue"
			placement.unit_pos = Vector2i(x, y)
			placement.size_units = Vector2i.ONE
			placement.is_glue = true
			placement.generated_image = glue
			placement.sockets = sockets
			data.placements.append(placement)
			data.used_glue_count += 1

func _glue_sockets_for(data: PieceChunkData, pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var open_chance: float = 0.38
	match data.chunk_type:
		&"main_path": open_chance = 0.72
		&"chamber": open_chance = 0.62
		&"branch": open_chance = 0.52
		&"solid": open_chance = 0.18
	var d: Dictionary = {}
	var sides: Array[StringName] = [&"top", &"right", &"bottom", &"left"]
	for side: StringName in sides:
		var neighbor_pos: Vector2i = pos + _side_dir(side)
		var socket: StringName = &"solid"
		if _unit_in_chunk(neighbor_pos):
			var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
			if neighbor != null:
				socket = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
			else:
				socket = _edge_socket(data.coord, pos, side, open_chance)
		else:
			socket = _edge_socket(data.coord, pos, side, open_chance)
		d[side] = socket
	return d

func _edge_socket(chunk_coord: Vector2i, unit_pos: Vector2i, side: StringName, chance: float) -> StringName:
	var global_cell: Vector2i = chunk_coord * PieceWorldConstants.CHUNK_UNITS + unit_pos
	var edge_pos: Vector2i = global_cell
	var orientation: int = 0
	match side:
		&"right":
			edge_pos.x += 1
			orientation = 0
		&"left":
			orientation = 0
		&"bottom":
			edge_pos.y += 1
			orientation = 1
		&"top":
			orientation = 1
	var key_x: int = edge_pos.x * 19349663 + edge_pos.y * 83492791 + orientation * 265443576 + world_seed
	var v: float = float(abs(key_x % 10000)) / 10000.0
	if v < chance * 0.20: return &"open_large"
	if v < chance * 0.52: return &"open_medium"
	if v < chance * 0.76: return &"double_open_small"
	if v < chance: return &"open_small"
	return &"solid"

func _biome_for(coord: Vector2i) -> StringName:
	if coord.y < -1: return &"snow"
	if coord.y > 4: return &"deep"
	return &"mine"

func _chunk_type_for(coord: Vector2i) -> StringName:
	var path_x: int = int(round(sin(float(coord.y) * 0.55 + float(world_seed % 100) * 0.01) * 2.0))
	if coord.x == path_x: return &"main_path"
	if abs(coord.x - path_x) == 1: return &"branch"
	var h: int = abs((coord.x * 928371 + coord.y * 12377 + world_seed) % 100)
	if h < 18: return &"chamber"
	if h < 45: return &"cave"
	return &"solid"

func _tags_for(chunk_type: StringName) -> Array[StringName]:
	match chunk_type:
		&"main_path": return [&"structure_v2", &"main_path"]
		&"branch": return [&"structure_v2", &"branch"]
		&"chamber": return [&"structure_v2", &"chamber"]
		&"solid": return [&"structure_v2", &"solid"]
		_: return [&"structure_v2", &"cave"]

func _chunk_seed(coord: Vector2i) -> int:
	return int(world_seed + coord.x * 73856093 + coord.y * 19349663)
