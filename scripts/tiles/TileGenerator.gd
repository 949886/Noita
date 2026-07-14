class_name TileGenerator
extends RefCounted

# Editor/demo atlas generator. It creates placeholder biome atlases and the SpecialChunk atlas;
# real projects can keep these Resource formats and replace the PNG art.

const TILE_SIZE: int = TileConstants.TILE_SIZE

static func generate_atlas_def(
	biome_id: StringName,
	variants_per_signature: int = TileConstants.VARIANTS_PER_SIGNATURE
) -> TileAtlasDef:
	var atlas_def: TileAtlasDef = TileAtlasDef.new()
	atlas_def.id = StringName("%s_atlas" % str(biome_id))
	atlas_def.biome_id = biome_id
	atlas_def.source_id = TileConstants.source_id_for_biome(biome_id)
	atlas_def.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas_def.atlas_columns = TileConstants.ATLAS_COLUMNS
	atlas_def.variants_per_signature = variants_per_signature
	atlas_def.fallback_row = TileConstants.FALLBACK_ROW
	atlas_def.layout_mode = TileAtlasDef.LayoutMode.SIGNATURE_ROWS
	atlas_def.signature_rows.clear()
	for signature: String in TileConstants.signature_order():
		atlas_def.signature_rows.append(StringName(signature))

	var atlas_image: Image = build_atlas_image(biome_id, variants_per_signature, atlas_def)
	atlas_def.atlas_texture = ImageTexture.create_from_image(atlas_image)
	return atlas_def

static func build_atlas_image(
	biome_id: StringName,
	variants_per_signature: int,
	atlas_def: TileAtlasDef
) -> Image:
	var atlas_image: Image = Image.create(
		TileConstants.ATLAS_COLUMNS * TILE_SIZE,
		TileConstants.ATLAS_ROWS * TILE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	atlas_image.fill(Color(0, 0, 0, 0))

	atlas_def.tiles.clear()
	atlas_def.atlas_columns = TileConstants.ATLAS_COLUMNS
	atlas_def.variants_per_signature = variants_per_signature
	atlas_def.fallback_row = TileConstants.FALLBACK_ROW
	atlas_def.layout_mode = TileAtlasDef.LayoutMode.SIGNATURE_ROWS
	atlas_def.signature_rows.clear()
	var signatures: Array[String] = TileConstants.signature_order()
	for signature: String in signatures:
		atlas_def.signature_rows.append(StringName(signature))

	for signature_index: int in range(signatures.size()):
		var signature: String = signatures[signature_index]
		var edges: Array[int] = TileDef.signature_to_edges(signature)
		var top: int = edges[0]
		var right: int = edges[1]
		var bottom: int = edges[2]
		var left: int = edges[3]
		for variant: int in range(variants_per_signature):
			var coords: Vector2i = TileConstants.atlas_coords_for_signature_variant(signature_index, variant)
			var id: StringName = StringName("%s_%s_%02d" % [str(biome_id), signature, variant + 1])
			var image: Image
			var weight: float = 1.0
			if variant < TileConstants.GENERATED_VARIANTS_PER_SIGNATURE:
				image = make_image(biome_id, top, right, bottom, left, variant)
			else:
				image = make_reserved_variant_image(signature, variant)
				weight = 0.0
			var tile: TileDef = TileDef.new(id, top, right, bottom, left, weight)
			tile.collision_rects = make_collision_rects(top, right, bottom, left)
			tile.atlas_coords = coords
			tile.alternative_tile = 0
			tile.texture = ImageTexture.create_from_image(image)
			atlas_def.tiles.append(tile)
			atlas_image.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), coords * TILE_SIZE)

	var fallback_image: Image = make_debug_image("fallback")
	var fallback_coords: Vector2i = TileConstants.fallback_atlas_coords()
	atlas_image.blit_rect(fallback_image, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), fallback_coords * TILE_SIZE)
	var fallback_tile: TileDef = TileDef.new(StringName("%s_fallback" % str(biome_id)), TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, 1.0)
	fallback_tile.atlas_coords = fallback_coords
	fallback_tile.is_fallback = true
	fallback_tile.texture = ImageTexture.create_from_image(fallback_image)
	fallback_tile.collision_rects = [Rect2i(0, 0, TILE_SIZE, TILE_SIZE)]
	atlas_def.fallback_tile = fallback_tile
	return atlas_image

static func make_reserved_variant_image(_signature: String, _variant: int) -> Image:
	var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var guide: Color = Color(1.0, 1.0, 1.0, 0.12)
	for i: int in range(TILE_SIZE):
		image.set_pixel(i, 0, guide)
		image.set_pixel(i, TILE_SIZE - 1, guide)
		image.set_pixel(0, i, guide)
		image.set_pixel(TILE_SIZE - 1, i, guide)
	# Small corner marks make reserved cells visible without becoming usable art.
	var mark: Color = Color(1.0, 1.0, 1.0, 0.22)
	for y: int in range(4):
		for x: int in range(4):
			image.set_pixel(x + 2, y + 2, mark)
			image.set_pixel(TILE_SIZE - 6 + x, y + 2, mark)
	return image

static func make_image(biome_id: StringName, top: int, right: int, bottom: int, left: int, variant: int) -> Image:
	var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var solid_a: Color = Color(0.24, 0.22, 0.22, 1.0)
	var solid_b: Color = Color(0.16, 0.15, 0.16, 1.0)
	var air: Color = Color(0.025, 0.022, 0.033, 1.0)
	var accent: Color = Color(0.42, 0.36, 0.25, 1.0)
	if biome_id == &"snow":
		solid_a = Color(0.72, 0.82, 0.88, 1.0)
		solid_b = Color(0.43, 0.56, 0.66, 1.0)
		air = Color(0.035, 0.045, 0.07, 1.0)
		accent = Color(0.86, 0.95, 1.0, 1.0)
	elif biome_id == &"deep":
		solid_a = Color(0.18, 0.14, 0.20, 1.0)
		solid_b = Color(0.08, 0.07, 0.10, 1.0)
		air = Color(0.018, 0.014, 0.022, 1.0)
		accent = Color(0.43, 0.23, 0.52, 1.0)

	var signature: String = TileDef.edges_to_signature(top, right, bottom, left)
	var local_seed: int = hash("%s_%s_%d" % [str(biome_id), signature, variant])
	if local_seed < 0:
		local_seed = -local_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = local_seed

	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var checker: int = ((x / 4) + (y / 4) + variant) % 2
			var noise: float = rng.randf_range(-0.035, 0.035)
			var c: Color = solid_a.lerp(solid_b, 0.35 + 0.2 * float(checker) + noise)
			image.set_pixel(x, y, c)

	_carve_circle(image, Vector2i(32, 32), 15, air)
	if top == TileDef.Edge.OPEN:
		_carve_rect(image, Rect2i(22, 0, 20, 34), air)
	if right == TileDef.Edge.OPEN:
		_carve_rect(image, Rect2i(30, 22, 34, 20), air)
	if bottom == TileDef.Edge.OPEN:
		_carve_rect(image, Rect2i(22, 30, 20, 34), air)
	if left == TileDef.Edge.OPEN:
		_carve_rect(image, Rect2i(0, 22, 34, 20), air)

	for i: int in range(90):
		var px: int = rng.randi_range(2, TILE_SIZE - 3)
		var py: int = rng.randi_range(2, TILE_SIZE - 3)
		if image.get_pixel(px, py) == air:
			continue
		image.set_pixel(px, py, accent.lerp(solid_a, rng.randf()))

	var border: Color = Color(0, 0, 0, 0.22)
	for i: int in range(TILE_SIZE):
		image.set_pixel(i, 0, image.get_pixel(i, 0).lerp(border, 0.3))
		image.set_pixel(i, TILE_SIZE - 1, image.get_pixel(i, TILE_SIZE - 1).lerp(border, 0.3))
		image.set_pixel(0, i, image.get_pixel(0, i).lerp(border, 0.3))
		image.set_pixel(TILE_SIZE - 1, i, image.get_pixel(TILE_SIZE - 1, i).lerp(border, 0.3))

	return image

static func make_debug_image(_signature: String) -> Image:
	var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.95, 0.05, 0.75, 1.0))
	var black: Color = Color(0.0, 0.0, 0.0, 1.0)
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			if ((x / 8) + (y / 8)) % 2 == 0:
				image.set_pixel(x, y, Color(1.0, 0.25, 0.95, 1.0))
	for i: int in range(TILE_SIZE):
		image.set_pixel(i, 0, black)
		image.set_pixel(i, TILE_SIZE - 1, black)
		image.set_pixel(0, i, black)
		image.set_pixel(TILE_SIZE - 1, i, black)
	return image

static func make_collision_rects(top: int, right: int, bottom: int, left: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var openings: int = 0
	var edges: Array[int] = [top, right, bottom, left]
	for e: int in edges:
		if e == TileDef.Edge.OPEN:
			openings += 1
	if openings == 0:
		rects.append(Rect2i(0, 0, TILE_SIZE, TILE_SIZE))
		return rects
	var side: int = 22
	if top != TileDef.Edge.OPEN and left != TileDef.Edge.OPEN:
		rects.append(Rect2i(0, 0, side, side))
	if top != TileDef.Edge.OPEN and right != TileDef.Edge.OPEN:
		rects.append(Rect2i(TILE_SIZE - side, 0, side, side))
	if bottom != TileDef.Edge.OPEN and left != TileDef.Edge.OPEN:
		rects.append(Rect2i(0, TILE_SIZE - side, side, side))
	if bottom != TileDef.Edge.OPEN and right != TileDef.Edge.OPEN:
		rects.append(Rect2i(TILE_SIZE - side, TILE_SIZE - side, side, side))
	if top != TileDef.Edge.OPEN:
		rects.append(Rect2i(22, 0, 20, 18))
	if bottom != TileDef.Edge.OPEN:
		rects.append(Rect2i(22, 46, 20, 18))
	if left != TileDef.Edge.OPEN:
		rects.append(Rect2i(0, 22, 18, 20))
	if right != TileDef.Edge.OPEN:
		rects.append(Rect2i(46, 22, 18, 20))
	return rects

static func _carve_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(maxi(0, rect.position.y), mini(TILE_SIZE, rect.end.y)):
		for x: int in range(maxi(0, rect.position.x), mini(TILE_SIZE, rect.end.x)):
			image.set_pixel(x, y, color)

static func _carve_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var r2: int = radius * radius
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= TILE_SIZE or y < 0 or y >= TILE_SIZE:
				continue
			var dx: int = x - center.x
			var dy: int = y - center.y
			if dx * dx + dy * dy <= r2:
				image.set_pixel(x, y, color)

static func generate_special_chunk_atlas_def() -> TileAtlasDef:
	var atlas_def: TileAtlasDef = TileAtlasDef.new()
	atlas_def.id = &"special_chunk_atlas"
	atlas_def.biome_id = &""
	atlas_def.atlas_kind = TileAtlasDef.AtlasKind.SPECIAL_CHUNK
	atlas_def.source_id = TileConstants.SOURCE_SPECIAL_CHUNK
	atlas_def.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas_def.atlas_columns = TileConstants.SPECIAL_ATLAS_COLUMNS
	atlas_def.variants_per_signature = TileConstants.SPECIAL_ATLAS_COLUMNS
	atlas_def.fallback_row = TileConstants.SPECIAL_ATLAS_ROWS - 1
	atlas_def.layout_mode = TileAtlasDef.LayoutMode.CATEGORY_ROWS
	atlas_def.category_rows.clear()
	for category: StringName in TileConstants.special_chunk_categories():
		atlas_def.category_rows.append(category)
	var atlas_image: Image = build_special_chunk_atlas_image(atlas_def)
	atlas_def.atlas_texture = ImageTexture.create_from_image(atlas_image)
	return atlas_def

static func build_special_chunk_atlas_image(atlas_def: TileAtlasDef) -> Image:
	var atlas_image: Image = Image.create(
		TileConstants.SPECIAL_ATLAS_COLUMNS * TILE_SIZE,
		TileConstants.SPECIAL_ATLAS_ROWS * TILE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	atlas_image.fill(Color(0, 0, 0, 0))
	atlas_def.tiles.clear()
	var categories: Array[StringName] = TileConstants.special_chunk_categories()
	for row: int in range(categories.size()):
		var category: StringName = categories[row]
		for variant: int in range(TileConstants.SPECIAL_ATLAS_COLUMNS):
			var coords: Vector2i = TileConstants.special_coords_for_category_variant(row, variant)
			var image: Image = make_special_chunk_tile_image(category, variant)
			atlas_image.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), coords * TILE_SIZE)
			var tile: TileDef = TileDef.new(StringName("special_%s_%02d" % [str(category), variant + 1]), TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, 1.0)
			tile.tile_role = TileDef.TileRole.SPECIAL_CHUNK if category != &"debug" else TileDef.TileRole.DEBUG
			tile.category = category
			tile.atlas_coords = coords
			tile.alternative_tile = 0
			tile.texture = ImageTexture.create_from_image(image)
			var category_string: String = str(category)
			if category == &"wall" or category == &"floor" or category == &"platform" or category == &"pillar" or category == &"door" or category_string.begins_with("transition_"):
				tile.collision_rects = [Rect2i(0, 0, TILE_SIZE, TILE_SIZE)]
			atlas_def.tiles.append(tile)
	var fallback_tile: TileDef = atlas_def.find_first_by_category(&"debug")
	if fallback_tile != null:
		fallback_tile.is_fallback = true
	atlas_def.fallback_tile = fallback_tile
	return atlas_image

static func make_special_chunk_tile_image(category: StringName, variant: int) -> Image:
	var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.28, 0.20, 0.16, 1.0)
	var dark: Color = Color(0.12, 0.08, 0.07, 1.0)
	var light: Color = Color(0.70, 0.50, 0.30, 1.0)
	match category:
		&"wall":
			base = Color(0.30, 0.22, 0.18, 1.0)
			dark = Color(0.13, 0.09, 0.08, 1.0)
			light = Color(0.52, 0.38, 0.28, 1.0)
		&"floor":
			base = Color(0.38, 0.28, 0.20, 1.0)
			dark = Color(0.18, 0.12, 0.10, 1.0)
			light = Color(0.62, 0.46, 0.30, 1.0)
		&"platform":
			base = Color(0.44, 0.32, 0.20, 1.0)
			dark = Color(0.18, 0.11, 0.07, 1.0)
			light = Color(0.78, 0.56, 0.32, 1.0)
		&"door":
			base = Color(0.18, 0.12, 0.10, 1.0)
			dark = Color(0.06, 0.04, 0.04, 1.0)
			light = Color(0.85, 0.58, 0.25, 1.0)
		&"pillar":
			base = Color(0.34, 0.25, 0.20, 1.0)
			dark = Color(0.12, 0.08, 0.07, 1.0)
			light = Color(0.72, 0.55, 0.34, 1.0)
		&"background":
			base = Color(0.08, 0.055, 0.06, 1.0)
			dark = Color(0.03, 0.022, 0.026, 1.0)
			light = Color(0.18, 0.12, 0.11, 1.0)
		&"decoration":
			base = Color(0.20, 0.12, 0.12, 1.0)
			dark = Color(0.08, 0.04, 0.05, 1.0)
			light = Color(0.90, 0.62, 0.28, 1.0)
		&"transition_top", &"transition_right", &"transition_bottom", &"transition_left":
			# Columns 0-3 are wall transitions: rock/snow/deep/ruins.
			# Columns 4-7 are door transitions with the same style order.
			var style_variant: int = variant % 4
			if style_variant == 1:
				base = Color(0.62, 0.75, 0.82, 1.0)
				dark = Color(0.34, 0.46, 0.55, 1.0)
				light = Color(0.90, 0.98, 1.0, 1.0)
			elif style_variant == 2:
				base = Color(0.18, 0.13, 0.20, 1.0)
				dark = Color(0.07, 0.05, 0.10, 1.0)
				light = Color(0.46, 0.26, 0.58, 1.0)
			elif style_variant == 3:
				base = Color(0.32, 0.25, 0.22, 1.0)
				dark = Color(0.12, 0.08, 0.07, 1.0)
				light = Color(0.70, 0.56, 0.42, 1.0)
			else:
				base = Color(0.24, 0.22, 0.20, 1.0)
				dark = Color(0.12, 0.10, 0.09, 1.0)
				light = Color(0.48, 0.42, 0.34, 1.0)
		&"debug":
			return make_debug_image("special_debug")
	image.fill(base)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(hash("special_%s_%d" % [str(category), variant]))
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var checker: int = ((x / 8) + (y / 8) + variant) % 2
			var c: Color = base.lerp(dark, 0.20 + 0.12 * float(checker))
			if rng.randf() < 0.012:
				c = c.lerp(light, 0.5)
			image.set_pixel(x, y, c)
	if category == &"wall":
		for yy: int in range(0, TILE_SIZE, 16):
			_carve_rect(image, Rect2i(0, yy, TILE_SIZE, 2), dark)
		for xx: int in range((variant % 2) * 16, TILE_SIZE, 32):
			_carve_rect(image, Rect2i(xx, 0, 2, TILE_SIZE), dark)
	elif category == &"floor":
		_carve_rect(image, Rect2i(0, 0, TILE_SIZE, 5), light)
		_carve_rect(image, Rect2i(0, 52, TILE_SIZE, 4), dark)
	elif category == &"platform":
		image.fill(Color(0, 0, 0, 0))
		_carve_rect(image, Rect2i(0, 18, TILE_SIZE, 14), base)
		_carve_rect(image, Rect2i(0, 18, TILE_SIZE, 3), light)
		_carve_rect(image, Rect2i(0, 31, TILE_SIZE, 5), dark)
	elif category == &"door":
		_carve_rect(image, Rect2i(18, 4, 28, 56), dark)
		_carve_rect(image, Rect2i(24, 10, 16, 44), base)
		_carve_rect(image, Rect2i(28, 8, 8, 8), light)
	elif category == &"pillar":
		image.fill(Color(0, 0, 0, 0))
		_carve_rect(image, Rect2i(20, 0, 24, TILE_SIZE), base)
		_carve_rect(image, Rect2i(14, 0, 36, 9), light)
		_carve_rect(image, Rect2i(14, 55, 36, 9), dark)
	elif category == &"decoration":
		image.fill(Color(0, 0, 0, 0))
		_carve_circle(image, Vector2i(32, 32), 14, light)
		_carve_circle(image, Vector2i(32, 32), 9, dark)
	elif str(category).begins_with("transition_"):
		var is_door: bool = variant >= 4
		if is_door:
			_carve_rect(image, Rect2i(18, 0, 28, TILE_SIZE), dark)
			_carve_rect(image, Rect2i(24, 8, 16, TILE_SIZE - 16), base)
		else:
			for i: int in range(0, TILE_SIZE, 8):
				_carve_rect(image, Rect2i(i, 0, 3, TILE_SIZE), dark)
		var category_string_for_marks: String = str(category)
		if category_string_for_marks == "transition_top":
			_carve_rect(image, Rect2i(0, 0, TILE_SIZE, 8), light)
		elif category_string_for_marks == "transition_right":
			_carve_rect(image, Rect2i(TILE_SIZE - 8, 0, 8, TILE_SIZE), light)
		elif category_string_for_marks == "transition_bottom":
			_carve_rect(image, Rect2i(0, TILE_SIZE - 8, TILE_SIZE, 8), light)
		elif category_string_for_marks == "transition_left":
			_carve_rect(image, Rect2i(0, 0, 8, TILE_SIZE), light)
		for i: int in range(60):
			var px: int = rng.randi_range(2, TILE_SIZE - 3)
			var py: int = rng.randi_range(2, TILE_SIZE - 3)
			if rng.randf() < 0.5:
				_carve_circle(image, Vector2i(px, py), rng.randi_range(1, 3), light)
			else:
				_carve_circle(image, Vector2i(px, py), rng.randi_range(1, 3), dark)
	return image
