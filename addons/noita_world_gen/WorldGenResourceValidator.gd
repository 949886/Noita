@tool
class_name WorldGenResourceValidator
extends RefCounted

# Lightweight editor-side validation for generated demo resources.
# It focuses on broken references and atlas layout drift, which are the most
# common issues while the world-generation schema is still changing.

const CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"

func validate_all() -> Array[String]:
	var messages: Array[String] = []
	var config: WorldGenConfig = ResourceLoader.load(CONFIG_PATH) as WorldGenConfig
	if config == null:
		messages.append("ERROR: Missing WorldGenConfig at %s" % CONFIG_PATH)
		return messages
	messages.append("OK: WorldGenConfig loaded.")
	_validate_world_config(config, messages)
	_validate_biome_atlases(config, messages)
	_validate_special_chunks(config, messages)
	_validate_tileset(config, messages)
	messages.append("Validation complete.")
	return messages

func _validate_world_config(config: WorldGenConfig, messages: Array[String]) -> void:
	if config.biome_configs.is_empty():
		messages.append("ERROR: No biome configs assigned.")
	else:
		messages.append("OK: %d biome configs." % config.biome_configs.size())
	if config.special_chunk_defs.is_empty():
		messages.append("WARNING: No SpecialChunkDef resources assigned.")
	else:
		messages.append("OK: %d SpecialChunkDefs." % config.special_chunk_defs.size())
	if config.tile_size != Vector2i(TileConstants.TILE_SIZE, TileConstants.TILE_SIZE):
		messages.append("WARNING: Config tile_size differs from TileConstants.")
	if config.tiles_per_chunk != TileConstants.TILES_PER_CHUNK:
		messages.append("WARNING: Config tiles_per_chunk differs from TileConstants.")

func _validate_biome_atlases(config: WorldGenConfig, messages: Array[String]) -> void:
	var expected_rows: int = TileConstants.signature_order().size()
	for biome_config: BiomeConfig in config.biome_configs:
		if biome_config == null:
			messages.append("ERROR: Null BiomeConfig entry.")
			continue
		if biome_config.tile_atlas == null:
			messages.append("ERROR: Biome %s has no TileAtlasDef." % str(biome_config.id))
			continue
		var atlas: TileAtlasDef = biome_config.tile_atlas
		if atlas.signature_rows.size() != expected_rows:
			messages.append("WARNING: Biome %s has %d signature rows; expected %d." % [str(biome_config.id), atlas.signature_rows.size(), expected_rows])
		if not atlas.signature_rows.has(TileConstants.AIR_SIGNATURE):
			messages.append("ERROR: Biome %s missing AAAA AIR signature row." % str(biome_config.id))
		if atlas.fallback_tile == null:
			messages.append("WARNING: Biome %s has no fallback tile." % str(biome_config.id))
		if atlas.atlas_texture == null:
			messages.append("ERROR: Biome %s atlas_texture is missing." % str(biome_config.id))
		else:
			messages.append("OK: Biome %s atlas rows=%d source_id=%d." % [str(biome_config.id), atlas.signature_rows.size(), atlas.source_id])

func _validate_special_chunks(config: WorldGenConfig, messages: Array[String]) -> void:
	for chunk_def: SpecialChunkDef in config.special_chunk_defs:
		if chunk_def == null:
			messages.append("ERROR: Null SpecialChunkDef entry.")
			continue
		if chunk_def.scene == null:
			messages.append("ERROR: SpecialChunk %s has no PackedScene." % str(chunk_def.id))
		if chunk_def.size_in_chunks.x <= 0 or chunk_def.size_in_chunks.y <= 0:
			messages.append("ERROR: SpecialChunk %s has invalid size_in_chunks." % str(chunk_def.id))
		var expected_horizontal: int = chunk_def.size_in_chunks.x * TileConstants.TILES_PER_CHUNK
		var expected_vertical: int = chunk_def.size_in_chunks.y * TileConstants.TILES_PER_CHUNK
		if chunk_def.top_profile.size() != expected_horizontal or chunk_def.bottom_profile.size() != expected_horizontal:
			messages.append("WARNING: SpecialChunk %s horizontal profile length mismatch." % str(chunk_def.id))
		if chunk_def.left_profile.size() != expected_vertical or chunk_def.right_profile.size() != expected_vertical:
			messages.append("WARNING: SpecialChunk %s vertical profile length mismatch." % str(chunk_def.id))
		if chunk_def.allowed_biomes.is_empty():
			messages.append("WARNING: SpecialChunk %s has no allowed_biomes." % str(chunk_def.id))
		if chunk_def.placement_weight <= 0.0:
			messages.append("WARNING: SpecialChunk %s placement_weight should be > 0." % str(chunk_def.id))
		if chunk_def.prefer_structure_tags.is_empty() and not chunk_def.prefer_branch_end and not chunk_def.prefer_chamber_edge:
			messages.append("WARNING: SpecialChunk %s has no structure placement preference." % str(chunk_def.id))
		messages.append("OK: SpecialChunk %s size=%s style=%d prefs=%s." % [str(chunk_def.id), str(chunk_def.size_in_chunks), chunk_def.transition_style, str(chunk_def.prefer_structure_tags)])

func _validate_tileset(config: WorldGenConfig, messages: Array[String]) -> void:
	if config.tile_set == null:
		messages.append("WARNING: Config tile_set is null; runtime will build one if allowed.")
		return
	messages.append("OK: TileSet assigned. Source count: %d." % config.tile_set.get_source_count())
	var required_sources: Array[int] = [0, 1, 2, TileConstants.SOURCE_SPECIAL_CHUNK]
	for source_id: int in required_sources:
		if config.tile_set.has_source(source_id):
			messages.append("OK: TileSet source %d exists." % source_id)
		else:
			messages.append("WARNING: TileSet source %d missing." % source_id)
