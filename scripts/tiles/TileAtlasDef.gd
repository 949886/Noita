class_name TileAtlasDef
extends Resource

# One TileAtlasDef describes one atlas PNG plus all tile metadata inside it.
# Biome atlases provide Wang tiles; special chunk atlases provide hand-authored scene tiles.

enum AtlasKind {
	BIOME,
	SPECIAL_CHUNK,
	DECORATION,
	DEBUG,
}

enum LayoutMode {
	SIGNATURE_ROWS,
	CATEGORY_ROWS,
}

@export var id: StringName = &""
@export var biome_id: StringName = &"mine"
@export_enum("Biome", "Special Chunk", "Decoration", "Debug") var atlas_kind: int = AtlasKind.BIOME
@export var source_id: int = 0
@export var atlas_texture: Texture2D
@export var tile_size: Vector2i = Vector2i(64, 64)
@export var atlas_columns: int = 8
@export var variants_per_signature: int = 8
@export var fallback_row: int = 16
@export_enum("Signature Rows", "Category Rows") var layout_mode: int = LayoutMode.SIGNATURE_ROWS
@export var signature_rows: Array[StringName] = []
@export var category_rows: Array[StringName] = []
@export var tiles: Array[TileDef] = []
@export var fallback_tile: TileDef

func get_all_tiles_including_fallback() -> Array[TileDef]:
	var result: Array[TileDef] = []
	for tile: TileDef in tiles:
		result.append(tile)
	if fallback_tile != null:
		result.append(fallback_tile)
	return result

func find_tile_by_id(tile_id: StringName) -> TileDef:
	for tile: TileDef in tiles:
		if tile.id == tile_id:
			return tile
	if fallback_tile != null and fallback_tile.id == tile_id:
		return fallback_tile
	return null

func find_first_by_category(category_name: StringName) -> TileDef:
	for tile: TileDef in tiles:
		if tile.category == category_name:
			return tile
	return fallback_tile
