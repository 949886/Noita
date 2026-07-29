class_name GluePieceGenerator
extends RefCounted

const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE

static func generate(biome_id: StringName, top: PieceSocket.Socket, right: PieceSocket.Socket, bottom: PieceSocket.Socket, left: PieceSocket.Socket, seed_value: int) -> Image:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var img: Image = Image.create_empty(UNIT_SIZE, UNIT_SIZE, false, Image.FORMAT_RGBA8)
	var rock: Color = _rock_color(biome_id)
	var dark: Color = _dark_color(biome_id)
	img.fill(rock)
	_add_noise(img, rng, dark)
	var open_sides: Array[StringName] = []
	if PieceSocket.is_open(top): open_sides.append(&"top")
	if PieceSocket.is_open(right): open_sides.append(&"right")
	if PieceSocket.is_open(bottom): open_sides.append(&"bottom")
	if PieceSocket.is_open(left): open_sides.append(&"left")
	if open_sides.size() > 0:
		_carve_to_center(img, top, right, bottom, left)
	return img

static func _rock_color(biome_id: StringName) -> Color:
	match biome_id:
		&"snow": return Color8(170, 190, 214, 255)
		&"deep": return Color8(48, 38, 58, 255)
		_: return Color8(54, 50, 45, 255)

static func _dark_color(biome_id: StringName) -> Color:
	match biome_id:
		&"snow": return Color8(70, 82, 112, 255)
		&"deep": return Color8(24, 16, 32, 255)
		_: return Color8(32, 28, 25, 255)

static func _add_noise(img: Image, rng: RandomNumberGenerator, accent: Color) -> void:
	for i: int in range(900):
		var p: Vector2i = Vector2i(rng.randi_range(0, UNIT_SIZE - 1), rng.randi_range(0, UNIT_SIZE - 1))
		if rng.randf() < 0.18:
			img.set_pixelv(p, accent)

static func _carve_rect(img: Image, rect: Rect2i) -> void:
	var air: Color = Color.TRANSPARENT
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, UNIT_SIZE)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, UNIT_SIZE)):
			img.set_pixel(x, y, air)

static func _carve_to_center(img: Image, top: PieceSocket.Socket, right: PieceSocket.Socket, bottom: PieceSocket.Socket, left: PieceSocket.Socket) -> void:
	var center: Rect2i = Rect2i(int(UNIT_SIZE * 0.34), int(UNIT_SIZE * 0.34), int(UNIT_SIZE * 0.32), int(UNIT_SIZE * 0.32))
	if PieceSocket.is_open(top) or PieceSocket.is_open(right) or PieceSocket.is_open(bottom) or PieceSocket.is_open(left):
		_carve_rect(img, center)
	_carve_socket_patterns(img, &"top", top)
	_carve_socket_patterns(img, &"right", right)
	_carve_socket_patterns(img, &"bottom", bottom)
	_carve_socket_patterns(img, &"left", left)

static func _carve_socket_patterns(img: Image, edge: StringName, socket: PieceSocket.Socket) -> void:
	if not PieceSocket.is_open(socket):
		return
	var patterns: Array[Vector2i] = PieceSocket.open_patterns(socket, UNIT_SIZE)
	var half_unit: int = int(UNIT_SIZE / 2)
	var center_min: int = int(UNIT_SIZE * 0.34)
	var center_max: int = int(UNIT_SIZE * 0.44)
	for pattern: Vector2i in patterns:
		var offset_px: int = pattern.x
		var w: int = pattern.y
		var half_w: int = int(w / 2)
		var quarter_w: int = int(w / 4)
		var bridge_w: int = maxi(10, half_w)
		match edge:
			&"top":
				_carve_rect(img, Rect2i(Vector2i(offset_px - half_w, 0), Vector2i(w, half_unit)))
				_carve_rect(img, Rect2i(Vector2i(offset_px - maxi(5, quarter_w), center_min), Vector2i(bridge_w, 28)))
			&"right":
				_carve_rect(img, Rect2i(Vector2i(half_unit, offset_px - half_w), Vector2i(half_unit, w)))
				_carve_rect(img, Rect2i(Vector2i(center_min, offset_px - maxi(5, quarter_w)), Vector2i(28, bridge_w)))
			&"bottom":
				_carve_rect(img, Rect2i(Vector2i(offset_px - half_w, half_unit), Vector2i(w, half_unit)))
				_carve_rect(img, Rect2i(Vector2i(offset_px - maxi(5, quarter_w), center_max), Vector2i(bridge_w, 28)))
			&"left":
				_carve_rect(img, Rect2i(Vector2i(0, offset_px - half_w), Vector2i(half_unit, w)))
				_carve_rect(img, Rect2i(Vector2i(center_max, offset_px - maxi(5, quarter_w)), Vector2i(28, bridge_w)))
