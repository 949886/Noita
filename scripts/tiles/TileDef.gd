class_name TileDef
extends Resource

# Metadata for one tile inside a TileAtlasDef.
# Wang tiles use the Edge fields for procedural matching; SpecialChunk tiles use category/role and are hand-painted in scenes.
# Edge v2 deliberately keeps only three states:
# SOLID = blocked material, OPEN = normal cave opening, AIR = full empty-space tile.
# AIR is only authored as AAAA in the biome atlases; it is not used as a one-sided chunk seam profile.

enum Edge {
	SOLID,
	OPEN,
	AIR,
}

enum TileRole {
	WANG,
	SPECIAL_CHUNK,
	DECORATION,
	DEBUG,
}

@export var id: StringName = &""
@export_enum("Solid", "Open", "Air") var top: int = Edge.SOLID
@export_enum("Solid", "Open", "Air") var right: int = Edge.SOLID
@export_enum("Solid", "Open", "Air") var bottom: int = Edge.SOLID
@export_enum("Solid", "Open", "Air") var left: int = Edge.SOLID
@export var weight: float = 1.0
@export var tags: Array[StringName] = []
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0
@export var collision_rects: Array[Rect2i] = []
@export var is_fallback: bool = false
@export_enum("Wang", "Special Chunk", "Decoration", "Debug") var tile_role: int = TileRole.WANG
@export var category: StringName = &""

# Kept only for the legacy Sprite2D renderer / debugging fallback.
var texture: Texture2D

func _init(
	p_id: StringName = &"",
	p_top: int = Edge.SOLID,
	p_right: int = Edge.SOLID,
	p_bottom: int = Edge.SOLID,
	p_left: int = Edge.SOLID,
	p_weight: float = 1.0
) -> void:
	id = p_id
	top = p_top
	right = p_right
	bottom = p_bottom
	left = p_left
	weight = p_weight

func edge(side: StringName) -> int:
	match side:
		&"top": return top
		&"right": return right
		&"bottom": return bottom
		&"left": return left
		_: return Edge.SOLID

func signature() -> String:
	return edges_to_signature(top, right, bottom, left)

static func edges_to_signature(p_top: int, p_right: int, p_bottom: int, p_left: int) -> String:
	return edge_to_char(p_top) + edge_to_char(p_right) + edge_to_char(p_bottom) + edge_to_char(p_left)

static func edge_to_char(edge_value: int) -> String:
	match edge_value:
		Edge.SOLID:
			return "S"
		Edge.OPEN:
			return "O"
		Edge.AIR:
			return "A"
		_:
			return "?"

static func char_to_edge(edge_char: String) -> int:
	match edge_char:
		"S":
			return Edge.SOLID
		"O":
			return Edge.OPEN
		"A":
			return Edge.AIR
		_:
			return Edge.SOLID

static func signature_to_edges(signature: String) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(signature.length()):
		result.append(char_to_edge(signature.substr(i, 1)))
	return result

static func edge_compatible(a: int, b: int) -> bool:
	# SOLID remains strict so walls do not accidentally connect to air.
	# OPEN and AIR are compatible, which lets large air pockets blend with normal cave openings.
	if a == Edge.SOLID or b == Edge.SOLID:
		return a == b
	return true

static func is_air(edge_value: int) -> bool:
	return edge_value == Edge.AIR
