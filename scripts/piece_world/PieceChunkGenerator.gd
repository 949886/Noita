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
	_place_anchor_pieces(data, occupied, rng)
	_fill_with_regular_pieces(data, occupied, rng)
	_fill_glue(data, occupied, rng)
	data.texture = ImageTexture.create_from_image(data.visual_image)
	data.piece_count = data.placements.size()
	data.regular_piece_count = maxi(0, data.piece_count - data.used_glue_count)
	return data

func _place_anchor_pieces(data: PieceChunkData, occupied: Array, rng: RandomNumberGenerator) -> void:
	var desired_tags: Array[StringName] = _desired_tags_for(data.chunk_type)
	var attempts: int = 4 if data.chunk_type != &"solid" else 1
	for i: int in range(attempts):
		var max_size: Vector2i = Vector2i(2, 2)
		var candidates: Array[PieceDef] = library.candidates_for(data.biome_id, desired_tags, max_size)
		if candidates.is_empty():
			return
		var best_piece: PieceDef = null
		var best_pos: Vector2i = Vector2i(-1, -1)
		var best_score: int = -999999
		for trial: int in range(36):
			var piece: PieceDef = library.weighted_pick(candidates, rng)
			if piece == null:
				continue
			var pos: Vector2i = _find_empty_spot(occupied, piece.size_units, rng)
			if pos.x < 0:
				continue
			var score: int = _placement_total_score(data, occupied, piece, pos, rng, true)
			if score < 0:
				continue
			if score > best_score:
				best_score = score
				best_piece = piece
				best_pos = pos
				if score >= 520:
					break
		if best_piece != null and best_pos.x >= 0:
			_add_piece(data, occupied, best_piece, best_pos, &"anchor")

# Regular fill is intentionally a global best-first loop. Glue is not considered here.
# This gives 2x1, 1x2, and 2x2 pieces time to occupy valid space before 1x1 glue fills gaps.
func _fill_with_regular_pieces(data: PieceChunkData, occupied: Array, rng: RandomNumberGenerator) -> void:
	var desired_tags: Array[StringName] = _desired_tags_for(data.chunk_type)
	var max_size: Vector2i = Vector2i(2, 2)
	var candidates: Array[PieceDef] = library.candidates_for(data.biome_id, desired_tags, max_size)
	if candidates.is_empty():
		return
	var guard: int = PieceWorldConstants.CHUNK_UNITS * PieceWorldConstants.CHUNK_UNITS
	while guard > 0:
		guard -= 1
		var best: Dictionary = _find_best_regular_placement(data, occupied, candidates, rng)
		if best.is_empty():
			break
		var best_piece: PieceDef = best.get(&"piece", null) as PieceDef
		var best_pos: Vector2i = best.get(&"unit_pos", Vector2i(-1, -1))
		if best_piece == null:
			break
		_add_piece(data, occupied, best_piece, best_pos, &"regular")

func _find_best_regular_placement(data: PieceChunkData, occupied: Array, candidates: Array[PieceDef], rng: RandomNumberGenerator) -> Dictionary:
	var best_score: int = -999999
	var best_piece: PieceDef = null
	var best_pos: Vector2i = Vector2i(-1, -1)
	for piece: PieceDef in candidates:
		if piece.kind == PieceDef.PieceKind.GLUE:
			continue
		for y: int in range(PieceWorldConstants.CHUNK_UNITS - piece.size_units.y + 1):
			for x: int in range(PieceWorldConstants.CHUNK_UNITS - piece.size_units.x + 1):
				var pos: Vector2i = Vector2i(x, y)
				if not _fits_empty_area(occupied, pos, piece.size_units):
					continue
				var score: int = _placement_total_score(data, occupied, piece, pos, rng, false)
				if score < 0:
					continue
				if score > best_score:
					best_score = score
					best_piece = piece
					best_pos = pos
	if best_piece == null:
		return {}
	return {&"piece": best_piece, &"unit_pos": best_pos, &"score": best_score}

func _placement_total_score(data: PieceChunkData, occupied: Array, piece: PieceDef, unit_pos: Vector2i, rng: RandomNumberGenerator, anchor_mode: bool) -> int:
	var match_score: int = _placement_match_score(data, occupied, piece, unit_pos)
	if match_score < 0:
		return -1
	var score: int = match_score
	# User request: 2x1, 1x2, and 2x2 pieces share the same size bonus.
	var area: int = piece.size_units.x * piece.size_units.y
	if area > 1:
		score += 90
	match piece.kind:
		PieceDef.PieceKind.ROOM:
			score += 26
		PieceDef.PieceKind.STRUCTURE:
			score += 22
		PieceDef.PieceKind.SPECIAL:
			score += 18
		PieceDef.PieceKind.CAVE:
			score += 8
		_:
			score += 0
	var desired_tags: Array[StringName] = _desired_tags_for(data.chunk_type)
	for tag: StringName in desired_tags:
		if piece.has_tag(tag):
			score += 10
	# Prefer anchors a little, but do not change the shared multi-unit size tier.
	if anchor_mode:
		score += 18
	# Deterministic small jitter for variety without overpowering socket/size rules.
	score += rng.randi_range(0, 7)
	return score

func _desired_tags_for(chunk_type: StringName) -> Array[StringName]:
	match chunk_type:
		&"chamber": return [&"room", &"cave_room", &"symbol"]
		&"main_path": return [&"room", &"lab", &"horizontal", &"cave_room"]
		&"branch": return [&"tank", &"vertical", &"room", &"cave_room"]
		&"solid": return [&"cave_room"]
		_: return [&"cave_room", &"room"]

func _find_empty_spot(occupied: Array, size_units: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var possible: Array[Vector2i] = []
	for y: int in range(PieceWorldConstants.CHUNK_UNITS - size_units.y + 1):
		for x: int in range(PieceWorldConstants.CHUNK_UNITS - size_units.x + 1):
			var pos: Vector2i = Vector2i(x, y)
			if _fits_empty_area(occupied, pos, size_units):
				possible.append(pos)
	if possible.is_empty():
		return Vector2i(-1, -1)
	return possible[rng.randi_range(0, possible.size() - 1)]

func _fits_empty_area(occupied: Array, unit_pos: Vector2i, size_units: Vector2i) -> bool:
	if unit_pos.x < 0 or unit_pos.y < 0:
		return false
	if unit_pos.x + size_units.x > PieceWorldConstants.CHUNK_UNITS:
		return false
	if unit_pos.y + size_units.y > PieceWorldConstants.CHUNK_UNITS:
		return false
	for yy: int in range(size_units.y):
		for xx: int in range(size_units.x):
			if occupied[(unit_pos.y + yy) * PieceWorldConstants.CHUNK_UNITS + (unit_pos.x + xx)]:
				return false
	return true

func _placement_match_score(data: PieceChunkData, occupied: Array, piece: PieceDef, unit_pos: Vector2i) -> int:
	var total: int = 0
	var checked: int = 0
	var boundary_chance: float = _open_chance_for(data.chunk_type)
	for y: int in range(piece.size_units.y):
		for x: int in range(piece.size_units.x):
			var cell: Vector2i = unit_pos + Vector2i(x, y)
			var sides: Array[StringName] = [&"top", &"right", &"bottom", &"left"]
			for side: StringName in sides:
				if not _is_outer_piece_side(piece, Vector2i(x, y), side):
					continue
				var socket_a: StringName = _piece_socket_for_local_side(piece, Vector2i(x, y), side)
				var neighbor_pos: Vector2i = cell + _side_dir(side)
				if not _unit_in_chunk(neighbor_pos):
					var seam_socket: StringName = _edge_socket(data.coord, cell, side, boundary_chance)
					var seam_score: int = PieceSocket.compatibility_score(socket_a, seam_socket)
					if seam_score < 60:
						return -1
					total += seam_score
					checked += 1
					continue
				if not occupied[neighbor_pos.y * PieceWorldConstants.CHUNK_UNITS + neighbor_pos.x]:
					continue
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

func _add_piece(data: PieceChunkData, occupied: Array, piece: PieceDef, unit_pos: Vector2i, phase: StringName = &"regular") -> void:
	var placement: PiecePlacement = PiecePlacement.new()
	placement.piece_def = piece
	placement.id = piece.id
	placement.unit_pos = unit_pos
	placement.size_units = piece.size_units
	placement.is_glue = false
	placement.phase = phase
	placement.sequence_index = data.placements.size()
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
			placement.phase = &"glue"
			placement.sequence_index = data.placements.size()
			placement.generated_image = glue
			placement.sockets = sockets
			data.placements.append(placement)
			data.used_glue_count += 1
			occupied[y * PieceWorldConstants.CHUNK_UNITS + x] = true

func _glue_sockets_for(data: PieceChunkData, pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var open_chance: float = _open_chance_for(data.chunk_type)
	var d: Dictionary = {}
	var fixed: Dictionary = {}
	var sides: Array[StringName] = [&"top", &"right", &"bottom", &"left"]
	for side: StringName in sides:
		var neighbor_pos: Vector2i = pos + _side_dir(side)
		var socket: StringName = &"solid"
		var is_fixed: bool = false
		if _unit_in_chunk(neighbor_pos):
			var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
			if neighbor != null:
				socket = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
				is_fixed = true
			else:
				socket = _edge_socket(data.coord, pos, side, open_chance)
		else:
			socket = _edge_socket(data.coord, pos, side, open_chance)
		d[side] = socket
		fixed[side] = is_fixed
	_normalize_glue_socket_mix(d, fixed)
	return d

# Ordinary fallback glue should not become a hidden adapter between double_open_small and normal open sockets.
# If double_open_small appears from a fixed neighbor, non-fixed ordinary opens are closed.
# Fixed conflicting neighbors are left visible so debug makes the unresolved constraint obvious.
func _normalize_glue_socket_mix(sockets: Dictionary, fixed: Dictionary) -> void:
	var has_double: bool = false
	var sides: Array[StringName] = [&"top", &"right", &"bottom", &"left"]
	for side: StringName in sides:
		if StringName(str(sockets.get(side, &"solid"))) == PieceSocket.DOUBLE_OPEN_SMALL:
			has_double = true
			break
	if not has_double:
		return
	for side: StringName in sides:
		var socket: StringName = StringName(str(sockets.get(side, &"solid")))
		var is_fixed: bool = bool(fixed.get(side, false))
		if not is_fixed and PieceSocket.is_open_family(socket) and socket != PieceSocket.DOUBLE_OPEN_SMALL:
			sockets[side] = &"solid"

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

func _open_chance_for(chunk_type: StringName) -> float:
	match chunk_type:
		&"main_path": return 0.72
		&"chamber": return 0.62
		&"branch": return 0.52
		&"solid": return 0.18
		_: return 0.38

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
