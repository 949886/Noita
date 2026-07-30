class_name SpecialPieceImageBuilder
extends RefCounted

# Thread-safe image builder for image-based special chunks. It mirrors
# SpecialPieceRenderer's old CPU image construction without touching the scene tree
# or creating ImageTexture objects.

const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

static func build(placement: SpecialChunkPlacement) -> Image:
	if placement == null or placement.chunk_def == null:
		return Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	var size_px: Vector2i = placement.size_in_chunks * CHUNK_SIZE
	var img: Image = Image.create_empty(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var biome_id: StringName = placement.biome_id
	var def: SpecialChunkDef = placement.chunk_def
	var rock: Color = _rock_color(biome_id, def.transition_style)
	var dark: Color = _dark_color(biome_id, def.transition_style)
	var accent: Color = _accent_color(def)
	_fill_noise(img, rock, dark, placement)
	_carve_room(img, def)
	_draw_structure_details(img, def, accent, dark)
	return img

static func _fill_noise(img: Image, rock: Color, dark: Color, placement: SpecialChunkPlacement) -> void:
	img.fill(rock)
	var rng: RandomNumberGenerator = SeedUtil.rng(placement.seed, "special_piece_%s" % str(placement.id))
	var pixel_count: int = int(float(img.get_width() * img.get_height()) * 0.018)
	for i: int in range(pixel_count):
		var p: Vector2i = Vector2i(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1))
		img.set_pixelv(p, dark)

static func _carve_room(img: Image, def: SpecialChunkDef) -> void:
	var margin: int = int(UNIT_SIZE / 2)
	var room_rect := Rect2i(Vector2i(margin, margin), img.get_size() - Vector2i(margin * 2, margin * 2))
	_carve_rect(img, room_rect)
	for local_x: int in range(def.size_in_chunks.x):
		var profile: Array[PieceSocket.Socket] = def.socket_profile(&"top", Vector2i(local_x, 0), UNITS_PER_CHUNK)
		_carve_horizontal_profile(img, profile, local_x * CHUNK_SIZE, 0, true)
		profile = def.socket_profile(&"bottom", Vector2i(local_x, 0), UNITS_PER_CHUNK)
		_carve_horizontal_profile(img, profile, local_x * CHUNK_SIZE, img.get_height() - 1, false)
	for local_y: int in range(def.size_in_chunks.y):
		var profile: Array[PieceSocket.Socket] = def.socket_profile(&"left", Vector2i(0, local_y), UNITS_PER_CHUNK)
		_carve_vertical_profile(img, profile, 0, local_y * CHUNK_SIZE, true)
		profile = def.socket_profile(&"right", Vector2i(0, local_y), UNITS_PER_CHUNK)
		_carve_vertical_profile(img, profile, img.get_width() - 1, local_y * CHUNK_SIZE, false)

static func _carve_horizontal_profile(img: Image, profile: Array[PieceSocket.Socket], offset_x: int, edge_y: int, from_top: bool) -> void:
	for i: int in range(profile.size()):
		var socket: PieceSocket.Socket = PieceSocket.from_value(profile[i])
		if not PieceSocket.is_open(socket):
			continue
		for pattern: Vector2i in PieceSocket.open_patterns(socket, UNIT_SIZE):
			var center_x: int = offset_x + i * UNIT_SIZE + pattern.x
			var width: int = pattern.y
			var y: int = 0 if from_top else img.get_height() - UNIT_SIZE
			_carve_rect(img, Rect2i(Vector2i(center_x - int(width / 2), y), Vector2i(width, UNIT_SIZE)))

static func _carve_vertical_profile(img: Image, profile: Array[PieceSocket.Socket], edge_x: int, offset_y: int, from_left: bool) -> void:
	for i: int in range(profile.size()):
		var socket: PieceSocket.Socket = PieceSocket.from_value(profile[i])
		if not PieceSocket.is_open(socket):
			continue
		for pattern: Vector2i in PieceSocket.open_patterns(socket, UNIT_SIZE):
			var center_y: int = offset_y + i * UNIT_SIZE + pattern.x
			var width: int = pattern.y
			var x: int = 0 if from_left else img.get_width() - UNIT_SIZE
			_carve_rect(img, Rect2i(Vector2i(x, center_y - int(width / 2)), Vector2i(UNIT_SIZE, width)))

static func _draw_structure_details(img: Image, def: SpecialChunkDef, accent: Color, dark: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	_draw_rect(img, Rect2i(Vector2i(int(w / 4), int(h * 0.72)), Vector2i(int(w / 2), 18)), accent)
	_draw_rect(img, Rect2i(Vector2i(int(w / 3), int(h / 2)), Vector2i(18, int(h / 4))), dark)
	_draw_rect(img, Rect2i(Vector2i(int(w * 2.0 / 3.0), int(h / 2)), Vector2i(18, int(h / 4))), dark)
	match def.chunk_kind:
		SpecialChunkDef.ChunkKind.TREASURE:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 28, int(h / 2) - 18), Vector2i(56, 36)), Color8(214, 154, 58, 255))
		SpecialChunkDef.ChunkKind.SHRINE:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 34, int(h / 2) - 48), Vector2i(68, 96)), Color8(185, 210, 235, 255))
		SpecialChunkDef.ChunkKind.HALL:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 90, int(h / 2) - 12), Vector2i(180, 24)), Color8(118, 98, 74, 255))
		_:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 24, int(h / 2) - 24), Vector2i(48, 48)), accent)

static func _carve_rect(img: Image, rect: Rect2i) -> void:
	var start_x: int = maxi(rect.position.x, 0)
	var start_y: int = maxi(rect.position.y, 0)
	var end_x: int = mini(rect.end.x, img.get_width())
	var end_y: int = mini(rect.end.y, img.get_height())
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			img.set_pixel(x, y, Color.TRANSPARENT)

static func _draw_rect(img: Image, rect: Rect2i, color: Color) -> void:
	var start_x: int = maxi(rect.position.x, 0)
	var start_y: int = maxi(rect.position.y, 0)
	var end_x: int = mini(rect.end.x, img.get_width())
	var end_y: int = mini(rect.end.y, img.get_height())
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			img.set_pixel(x, y, color)

static func _rock_color(biome_id: StringName, style: int) -> Color:
	if style == SpecialChunkDef.TransitionStyle.SNOW or biome_id == &"snow":
		return Color8(170, 190, 214, 255)
	if style == SpecialChunkDef.TransitionStyle.DEEP or biome_id == &"deep":
		return Color8(48, 38, 58, 255)
	if style == SpecialChunkDef.TransitionStyle.RUINS:
		return Color8(82, 70, 58, 255)
	return Color8(54, 50, 45, 255)

static func _dark_color(biome_id: StringName, style: int) -> Color:
	if style == SpecialChunkDef.TransitionStyle.SNOW or biome_id == &"snow":
		return Color8(70, 82, 112, 255)
	if style == SpecialChunkDef.TransitionStyle.DEEP or biome_id == &"deep":
		return Color8(24, 16, 32, 255)
	if style == SpecialChunkDef.TransitionStyle.RUINS:
		return Color8(45, 35, 30, 255)
	return Color8(32, 28, 25, 255)

static func _accent_color(def: SpecialChunkDef) -> Color:
	match def.chunk_kind:
		SpecialChunkDef.ChunkKind.TREASURE:
			return Color8(208, 154, 62, 255)
		SpecialChunkDef.ChunkKind.SHRINE:
			return Color8(148, 190, 230, 255)
		SpecialChunkDef.ChunkKind.HALL:
			return Color8(135, 112, 82, 255)
		_:
			return Color8(132, 180, 210, 255)
