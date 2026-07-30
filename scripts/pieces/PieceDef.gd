class_name PieceDef
extends Resource

# A large prefab-like world piece. Unlike TileMap cells, pieces are pasted into a chunk image.
enum PieceKind {
	CAVE,
	ROOM,
	STRUCTURE,
	GLUE,
	SPECIAL,
}

const DEFAULT_TARGET_FORMAT: Image.Format = Image.FORMAT_RGBA8

@export var id: StringName = &""
@export_enum("Cave", "Room", "Structure", "Glue", "Special") var kind: int = PieceKind.CAVE
@export var texture: Texture2D
@export var material_texture: Texture2D
@export var size_px: Vector2i = Vector2i(128, 128)
@export var size_units: Vector2i = Vector2i.ONE
@export var allowed_biomes: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var weight: float = 1.0
@export var top_slots: Array[PieceSocket.Socket] = []
@export var right_slots: Array[PieceSocket.Socket] = []
@export var bottom_slots: Array[PieceSocket.Socket] = []
@export var left_slots: Array[PieceSocket.Socket] = []

# Runtime-only image caches. These are filled on the main thread by
# PieceLibrary.prepare() so background chunk workers never need to call
# Texture2D.get_image(), decompress, convert, or resize during generation.
var cached_visual_image: Image
var cached_material_image: Image
var image_cache_ready: bool = false

func allows_biome(biome_id: StringName) -> bool:
	return allowed_biomes.is_empty() or allowed_biomes.has(biome_id)

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

func slot_count_for_side(side: StringName) -> int:
	match side:
		&"top", &"bottom":
			return size_units.x
		&"left", &"right":
			return size_units.y
		_:
			return 0

func normalized_slots(side: StringName) -> Array[PieceSocket.Socket]:
	var source: Array[PieceSocket.Socket] = []
	match side:
		&"top": source = top_slots
		&"right": source = right_slots
		&"bottom": source = bottom_slots
		&"left": source = left_slots
	var required: int = slot_count_for_side(side)
	var result: Array[PieceSocket.Socket] = []
	for i: int in range(required):
		if i < source.size():
			result.append(PieceSocket.from_value(source[i]))
		else:
			result.append(PieceSocket.SOLID)
	return result

func target_pixel_size() -> Vector2i:
	var unit_size: int = PieceWorldConstants.UNIT_SIZE
	var result: Vector2i = size_units * unit_size
	if result.x <= 0 or result.y <= 0:
		return size_px
	return result

func prepare_image_cache(target_format: Image.Format = DEFAULT_TARGET_FORMAT) -> void:
	var target_size: Vector2i = target_pixel_size()
	cached_visual_image = _texture_to_cached_image(texture, target_size, target_format)
	var material_source: Texture2D = material_texture if material_texture != null else texture
	cached_material_image = _texture_to_cached_image(material_source, target_size, target_format)
	image_cache_ready = cached_visual_image != null and not cached_visual_image.is_empty()

func _texture_to_cached_image(source_texture: Texture2D, target_size: Vector2i, target_format: Image.Format) -> Image:
	if source_texture == null:
		return null
	var img: Image = source_texture.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate()
	if img.is_compressed():
		var err: Error = img.decompress()
		if err != OK:
			push_warning("PieceDef %s could not decompress cached image." % str(id))
			return null
	if img.get_format() != target_format:
		img.convert(target_format)
	if img.get_size() != target_size:
		img.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	if img.get_format() != target_format:
		img.convert(target_format)
	return img
