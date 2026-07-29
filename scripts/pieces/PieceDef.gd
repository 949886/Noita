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
