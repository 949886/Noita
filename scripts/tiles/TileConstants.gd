class_name TileConstants
extends RefCounted

const TILE_SIZE: int = 64
const TILES_PER_CHUNK: int = 8
const CHUNK_SIZE: int = TILE_SIZE * TILES_PER_CHUNK

# Atlas layout: each row is one edge signature, each column is a visual variant.
const VARIANTS_PER_SIGNATURE: int = 8
const GENERATED_VARIANTS_PER_SIGNATURE: int = 2
const ATLAS_COLUMNS: int = VARIANTS_PER_SIGNATURE
const SIGNATURE_ROW_COUNT: int = 16
const FALLBACK_ROW: int = SIGNATURE_ROW_COUNT
const ATLAS_ROWS: int = SIGNATURE_ROW_COUNT + 1

# SpecialChunk atlas uses category rows rather than Wang edge signature rows.
# Rows 7-10 contain direction-aware transition tiles used to soften the seam
# between authored SpecialChunks and neighboring Wang chunks.
const SOURCE_SPECIAL_CHUNK: int = 10
const SPECIAL_ATLAS_COLUMNS: int = 8
const SPECIAL_TRANSITION_TOP_ROW: int = 7
const SPECIAL_TRANSITION_RIGHT_ROW: int = 8
const SPECIAL_TRANSITION_BOTTOM_ROW: int = 9
const SPECIAL_TRANSITION_LEFT_ROW: int = 10
const SPECIAL_DEBUG_ROW: int = 11
const SPECIAL_ATLAS_ROWS: int = 12

static func biome_ids() -> Array[StringName]:
	return [&"mine", &"snow", &"deep"]

static func source_id_for_biome(biome_id: StringName) -> int:
	match biome_id:
		&"mine": return 0
		&"snow": return 1
		&"deep": return 2
		_: return 0

static func display_name_for_biome(biome_id: StringName) -> String:
	match biome_id:
		&"mine": return "Mine"
		&"snow": return "Snow"
		&"deep": return "Deep"
		_: return str(biome_id).capitalize()

static func signature_order() -> Array[String]:
	return [
		"SSSS", "SSSO", "SSOS", "SSOO",
		"SOSS", "SOSO", "SOOS", "SOOO",
		"OSSS", "OSSO", "OSOS", "OSOO",
		"OOSS", "OOSO", "OOOS", "OOOO"
	]

static func special_chunk_categories() -> Array[StringName]:
	return [
		&"wall",
		&"floor",
		&"platform",
		&"door",
		&"pillar",
		&"background",
		&"decoration",
		&"transition_top",
		&"transition_right",
		&"transition_bottom",
		&"transition_left",
		&"debug",
	]

static func atlas_coords_for_signature_variant(signature_index: int, variant: int) -> Vector2i:
	return Vector2i(variant, signature_index)

static func fallback_atlas_coords() -> Vector2i:
	return Vector2i(0, FALLBACK_ROW)

static func special_coords_for_category_variant(category_index: int, variant: int) -> Vector2i:
	return Vector2i(variant, category_index)
