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
		var piece: PieceDef = library.weighted_pick(candidates, rng)
		if piece == null:
			continue
		var pos: Vector2i = _find_empty_spot(occupied, piece.size_units, rng)
		if pos.x < 0:
			continue
		_add_piece(data, occupied, piece, pos)

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
	if tex == null: return
	var img: Image = tex.get_image()
	if img == null: return
	if img.get_size() != dst_rect.size:
		img = img.duplicate()
		img.resize(dst_rect.size.x, dst_rect.size.y, Image.INTERPOLATE_NEAREST)
	target.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), dst_rect.position)

func _fill_glue(data: PieceChunkData, occupied: Array, rng: RandomNumberGenerator) -> void:
	for y: int in range(PieceWorldConstants.CHUNK_UNITS):
		for x: int in range(PieceWorldConstants.CHUNK_UNITS):
			if occupied[y * PieceWorldConstants.CHUNK_UNITS + x]: continue
			var sockets: Dictionary = _glue_sockets_for(data, Vector2i(x, y), rng)
			var glue: Image = GluePieceGenerator.generate(data.biome_id, sockets[&"top"], sockets[&"right"], sockets[&"bottom"], sockets[&"left"], int(_chunk_seed(data.coord) + x * 77 + y * 313))
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
	d[&"top"] = _edge_socket(data.coord, pos, &"top", open_chance)
	d[&"right"] = _edge_socket(data.coord, pos, &"right", open_chance)
	d[&"bottom"] = _edge_socket(data.coord, pos, &"bottom", open_chance)
	d[&"left"] = _edge_socket(data.coord, pos, &"left", open_chance)
	return d

func _edge_socket(chunk_coord: Vector2i, unit_pos: Vector2i, side: StringName, chance: float) -> StringName:
	var global_a: Vector2i = chunk_coord * PieceWorldConstants.CHUNK_UNITS + unit_pos
	var key_x: int = global_a.x * 19349663 + global_a.y * 83492791 + world_seed
	match side:
		&"right": key_x += 17
		&"bottom": key_x += 31
		&"left": key_x += -17
		&"top": key_x += -31
	var v: float = float(abs(key_x % 10000)) / 10000.0
	if v < chance * 0.30: return &"open_large"
	if v < chance * 0.75: return &"open_medium"
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
