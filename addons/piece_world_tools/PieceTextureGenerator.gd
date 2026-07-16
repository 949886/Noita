@tool
extends RefCounted

# Generates placeholder piece textures and PieceDef resources for the piece-world prototype.
# The important rule is slot correctness: each open slot is carved at that slot's own 128px region,
# not at the center of the entire edge. This keeps PieceDef socket metadata aligned with the image.

const UNIT_SIZE: int = 128
const TEXTURE_DIR: String = "res://resources/generated_pieces/textures"
const DEF_DIR: String = "res://resources/generated_pieces/defs"

func generate_default_library() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEF_DIR))
	_clear_generated_dir(TEXTURE_DIR)
	_clear_generated_dir(DEF_DIR)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260716
	var count: int = 0
	for biome: StringName in [&"mine", &"snow", &"deep"]:
		for i: int in range(8):
			var size_units: Vector2i = _cave_size_for_index(i)
			_generate_cave_piece(biome, size_units, i, rng)
			count += 1
		for i: int in range(4):
			_generate_lab_piece(biome, i, rng)
			_generate_tank_piece(biome, i, rng)
			count += 2
		for i: int in range(3):
			_generate_symbol_piece(biome, i, rng)
			count += 1
	print("PieceTextureGenerator wrote open-small-double placeholder pieces: ", count)

func _clear_generated_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if not dir.current_is_dir() and (name.ends_with(".png") or name.ends_with(".tres") or name.ends_with(".res")):
			dir.remove(name)
	dir.list_dir_end()

func _cave_size_for_index(index: int) -> Vector2i:
	match index:
		0, 1: return Vector2i(2, 1)
		2, 5: return Vector2i(1, 2)
		3: return Vector2i(2, 2)
		_: return Vector2i(1, 1)

func _generate_cave_piece(biome: StringName, size_units: Vector2i, index: int, rng: RandomNumberGenerator) -> void:
	var id: StringName = StringName("gen_%s_cave_%dx%d_%02d" % [str(biome), size_units.x, size_units.y, index])
	var img: Image = Image.create_empty(size_units.x * UNIT_SIZE, size_units.y * UNIT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_rock_color(biome))
	_add_noise(img, rng, _dark_color(biome), 1200 * size_units.x * size_units.y)
	var top: Array[StringName] = _random_slots(size_units.x, rng, 0.35)
	var bottom: Array[StringName] = _random_slots(size_units.x, rng, 0.40)
	var left: Array[StringName] = _random_slots(size_units.y, rng, 0.45)
	var right: Array[StringName] = _random_slots(size_units.y, rng, 0.45)
	# Stable regression sample from feedback: two right-side slots must carve two separate right openings.
	if biome == &"snow" and size_units == Vector2i(1, 2) and index == 5:
		top = [&"solid"]
		bottom = [&"solid"]
		left = [&"open_small", &"solid"]
		right = [&"open_medium", &"open_small_double"]
	_carve_cave_cavity(img, rng)
	_carve_all_open_slots(img, top, right, bottom, left, rng)
	_add_noise(img, rng, _dark_color(biome), 500 * size_units.x * size_units.y)
	_save_piece(id, img, "CAVE", size_units, [biome], [&"generated", &"cave_room"], top, right, bottom, left, 1.0)

func _generate_lab_piece(biome: StringName, index: int, rng: RandomNumberGenerator) -> void:
	var id: StringName = StringName("gen_%s_lab_2x1_%02d" % [str(biome), index])
	var img: Image = Image.create_empty(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_fill_rect(img, Rect2i(14, 18, 228, 26), Color8(22, 24, 30, 255))
	_fill_rect(img, Rect2i(32, 86, 192, 18), Color8(72, 76, 96, 255))
	_fill_rect(img, Rect2i(46, 36, 28, 5), Color8(116, 245, 255, 255))
	_fill_rect(img, Rect2i(182, 36, 28, 5), Color8(116, 245, 255, 255))
	_save_piece(id, img, "STRUCTURE", Vector2i(2, 1), [biome], [&"generated", &"lab", &"room", &"horizontal"], [&"solid", &"solid"], [&"open_medium"], [&"open_small", &"open_small"], [&"open_medium"], 0.8)

func _generate_symbol_piece(biome: StringName, index: int, rng: RandomNumberGenerator) -> void:
	var id: StringName = StringName("gen_%s_symbol_2x1_%02d" % [str(biome), index])
	var img: Image = Image.create_empty(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(_rock_color(biome))
	_add_noise(img, rng, _dark_color(biome), 1600)
	var top: Array[StringName] = [&"solid", &"open_small"]
	var right: Array[StringName] = [&"open_large"]
	var bottom: Array[StringName] = [&"open_small_double", &"solid"]
	var left: Array[StringName] = [&"open_large"]
	_carve_cave_cavity(img, rng)
	_carve_all_open_slots(img, top, right, bottom, left, rng)
	_draw_symbol(img, Vector2i(128, 64), Color8(255, 120, 80, 255))
	_save_piece(id, img, "ROOM", Vector2i(2, 1), [biome], [&"generated", &"symbol", &"room", &"cave_room"], top, right, bottom, left, 0.9)

func _generate_tank_piece(biome: StringName, index: int, rng: RandomNumberGenerator) -> void:
	var id: StringName = StringName("gen_%s_tank_1x2_%02d" % [str(biome), index])
	var img: Image = Image.create_empty(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_fill_rect(img, Rect2i(36, 28, 56, 160), Color8(224, 150, 228, 255))
	_draw_rect_outline(img, Rect2i(36, 28, 56, 160), Color8(75, 65, 88, 255), 5)
	_fill_rect(img, Rect2i(30, 28, 6, 170), Color8(92, 57, 25, 255))
	_fill_rect(img, Rect2i(92, 28, 6, 170), Color8(92, 57, 25, 255))
	_save_piece(id, img, "STRUCTURE", Vector2i(1, 2), [biome], [&"generated", &"tank", &"vertical"], [&"open_small"], [&"solid", &"solid"], [&"open_small"], [&"solid", &"solid"], 0.6)

func _random_slots(count: int, rng: RandomNumberGenerator, open_chance: float) -> Array[StringName]:
	var result: Array[StringName] = []
	for i: int in range(count):
		if rng.randf() > open_chance:
			result.append(&"solid")
		else:
			var roll: float = rng.randf()
			if roll < 0.22: result.append(&"open_small")
			elif roll < 0.42: result.append(&"open_small_double")
			elif roll < 0.78: result.append(&"open_medium")
			else: result.append(&"open_large")
	return result

func _carve_all_open_slots(img: Image, top: Array[StringName], right: Array[StringName], bottom: Array[StringName], left: Array[StringName], rng: RandomNumberGenerator) -> void:
	for i: int in range(top.size()):
		_carve_slot_opening(img, &"top", i, top[i], rng)
	for i: int in range(right.size()):
		_carve_slot_opening(img, &"right", i, right[i], rng)
	for i: int in range(bottom.size()):
		_carve_slot_opening(img, &"bottom", i, bottom[i], rng)
	for i: int in range(left.size()):
		_carve_slot_opening(img, &"left", i, left[i], rng)

func _carve_slot_opening(img: Image, edge: StringName, slot_index: int, socket: StringName, rng: RandomNumberGenerator) -> void:
	if not _socket_is_open(socket):
		return
	var patterns: Array[Vector2i] = _socket_open_patterns(socket)
	for pattern: Vector2i in patterns:
		var center: Vector2i = _opening_center_on_edge(edge, slot_index, pattern.x, img.get_size())
		var width: int = pattern.y
		var depth: int = int(UNIT_SIZE * 0.58)
		match edge:
			&"right":
				_carve_rect(img, Rect2i(Vector2i(img.get_width() - depth, center.y - width / 2), Vector2i(depth, width)))
				_carve_corridor(img, center, Vector2i(img.get_width() / 2, center.y), width)
			&"left":
				_carve_rect(img, Rect2i(Vector2i(0, center.y - width / 2), Vector2i(depth, width)))
				_carve_corridor(img, center, Vector2i(img.get_width() / 2, center.y), width)
			&"top":
				_carve_rect(img, Rect2i(Vector2i(center.x - width / 2, 0), Vector2i(width, depth)))
				_carve_corridor(img, center, Vector2i(center.x, img.get_height() / 2), width)
			&"bottom":
				_carve_rect(img, Rect2i(Vector2i(center.x - width / 2, img.get_height() - depth), Vector2i(width, depth)))
				_carve_corridor(img, center, Vector2i(center.x, img.get_height() / 2), width)

func _opening_center_on_edge(edge: StringName, slot_index: int, offset_px: int, size_px: Vector2i) -> Vector2i:
	match edge:
		&"right": return Vector2i(size_px.x - 1, slot_index * UNIT_SIZE + offset_px)
		&"left": return Vector2i(0, slot_index * UNIT_SIZE + offset_px)
		&"top": return Vector2i(slot_index * UNIT_SIZE + offset_px, 0)
		&"bottom": return Vector2i(slot_index * UNIT_SIZE + offset_px, size_px.y - 1)
	return Vector2i.ZERO

func _socket_open_patterns(socket: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match socket:
		&"open_small":
			result.append(Vector2i(UNIT_SIZE / 2, 34))
		&"open_small_double":
			result.append(Vector2i(UNIT_SIZE / 4, 28))
			result.append(Vector2i(UNIT_SIZE * 3 / 4, 28))
		&"open_medium":
			result.append(Vector2i(UNIT_SIZE / 2, 62))
		&"open_large":
			result.append(Vector2i(UNIT_SIZE / 2, 92))
		&"room":
			result.append(Vector2i(UNIT_SIZE / 2, 86))
		&"shaft":
			result.append(Vector2i(UNIT_SIZE / 2, 42))
		&"any":
			result.append(Vector2i(UNIT_SIZE / 2, 58))
	return result

func _socket_is_open(socket: StringName) -> bool:
	return socket != &"solid" and socket != &""

func _carve_cave_cavity(img: Image, rng: RandomNumberGenerator) -> void:
	var cx: float = img.get_width() * 0.5 + rng.randf_range(-10.0, 10.0)
	var cy: float = img.get_height() * 0.5 + rng.randf_range(-10.0, 10.0)
	var rx: float = img.get_width() * 0.28
	var ry: float = img.get_height() * 0.25
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var dx: float = (float(x) - cx) / rx
			var dy: float = (float(y) - cy) / ry
			var n: float = sin(float(x) * 0.08) * 0.08 + cos(float(y) * 0.06) * 0.08
			if dx * dx + dy * dy + n < 1.0:
				img.set_pixel(x, y, Color.TRANSPARENT)

func _carve_corridor(img: Image, a: Vector2i, b: Vector2i, width: int) -> void:
	var half: int = maxi(4, int(width / 2))
	var steps: int = maxi(maxi(abs(a.x - b.x), abs(a.y - b.y)), 1)
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2i = Vector2i(roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)))
		_carve_rect(img, Rect2i(p - Vector2i(half, half), Vector2i(half * 2, half * 2)))

func _carve_rect(img: Image, rect: Rect2i) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, img.get_height())):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, img.get_width())):
			img.set_pixel(x, y, Color.TRANSPARENT)

func _save_piece(id: StringName, img: Image, kind_name: String, size_units: Vector2i, biomes: Array, tags: Array, top: Array, right: Array, bottom: Array, left: Array, weight: float) -> void:
	var texture_path: String = TEXTURE_DIR + "/" + str(id) + ".png"
	img.save_png(texture_path)
	var kind_value: int = {"CAVE":0, "ROOM":1, "STRUCTURE":2, "GLUE":3, "SPECIAL":4}.get(kind_name, 0)
	var text: String = "[gd_resource type=\"Resource\" script_class=\"PieceDef\" load_steps=3 format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://scripts/pieces/PieceDef.gd\" id=\"1\"]\n"
	text += "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"2\"]\n\n" % texture_path
	text += "[resource]\nscript = ExtResource(\"1\")\n"
	text += "id = &\"%s\"\nkind = %d\ntexture = ExtResource(\"2\")\n" % [str(id), kind_value]
	text += "size_px = Vector2i(%d, %d)\nsize_units = Vector2i(%d, %d)\n" % [size_units.x * UNIT_SIZE, size_units.y * UNIT_SIZE, size_units.x, size_units.y]
	text += "allowed_biomes = Array[StringName]([%s])\n" % _string_name_list(biomes)
	text += "tags = Array[StringName]([%s])\n" % _string_name_list(tags)
	text += "weight = %.2f\n" % weight
	text += "top_slots = Array[StringName]([%s])\nright_slots = Array[StringName]([%s])\nbottom_slots = Array[StringName]([%s])\nleft_slots = Array[StringName]([%s])\n" % [_string_name_list(top), _string_name_list(right), _string_name_list(bottom), _string_name_list(left)]
	var f: FileAccess = FileAccess.open(DEF_DIR + "/" + str(id) + ".tres", FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _string_name_list(values: Array) -> String:
	var parts: Array[String] = []
	for v in values:
		parts.append("&\"%s\"" % str(v))
	return ", ".join(parts)

func _rock_color(biome: StringName) -> Color:
	match biome:
		&"snow": return Color8(170, 190, 214, 255)
		&"deep": return Color8(48, 38, 58, 255)
		_: return Color8(54, 50, 45, 255)

func _dark_color(biome: StringName) -> Color:
	match biome:
		&"snow": return Color8(70, 82, 112, 255)
		&"deep": return Color8(24, 16, 32, 255)
		_: return Color8(32, 28, 25, 255)

func _add_noise(img: Image, rng: RandomNumberGenerator, c: Color, count: int) -> void:
	for i: int in range(count):
		var p: Vector2i = Vector2i(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1))
		if img.get_pixelv(p).a > 0.1:
			img.set_pixelv(p, c)

func _draw_symbol(img: Image, center: Vector2i, c: Color) -> void:
	_fill_rect(img, Rect2i(center - Vector2i(16, 2), Vector2i(32, 4)), c)
	_fill_rect(img, Rect2i(center - Vector2i(2, 16), Vector2i(4, 32)), c)

func _fill_rect(img: Image, rect: Rect2i, c: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height(): img.set_pixel(x, y, c)

func _draw_rect_outline(img: Image, rect: Rect2i, c: Color, width: int) -> void:
	_fill_rect(img, Rect2i(rect.position, Vector2i(rect.size.x, width)), c)
	_fill_rect(img, Rect2i(Vector2i(rect.position.x, rect.end.y - width), Vector2i(rect.size.x, width)), c)
	_fill_rect(img, Rect2i(rect.position, Vector2i(width, rect.size.y)), c)
	_fill_rect(img, Rect2i(Vector2i(rect.end.x - width, rect.position.y), Vector2i(width, rect.size.y)), c)
