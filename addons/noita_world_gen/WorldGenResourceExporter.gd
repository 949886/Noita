@tool
class_name WorldGenResourceExporter
extends RefCounted

const ATLAS_DIR: String = "res://resources/tilesets/atlases"
const TILE_ATLAS_DEF_DIR: String = "res://resources/tile_atlases"
const BIOME_DIR: String = "res://resources/biomes"
const WORLD_GEN_DIR: String = "res://resources/world_gen"
const TILESET_DIR: String = "res://resources/tilesets"
const SPECIAL_CHUNK_DIR: String = "res://resources/special_chunks"

func generate_all(editor_interface: EditorInterface = null) -> Array[String]:
	var messages: Array[String] = []
	_ensure_dir(ATLAS_DIR)
	_ensure_dir(TILE_ATLAS_DEF_DIR)
	_ensure_dir(BIOME_DIR)
	_ensure_dir(WORLD_GEN_DIR)
	_ensure_dir(TILESET_DIR)
	_ensure_dir(SPECIAL_CHUNK_DIR)

	var config: WorldGenConfig = WorldGenConfig.new()
	config.world_seed = 20260706
	config.tile_size = Vector2i(TileConstants.TILE_SIZE, TileConstants.TILE_SIZE)
	config.tiles_per_chunk = TileConstants.TILES_PER_CHUNK
	config.load_radius = 2

	for biome_id: StringName in TileConstants.biome_ids():
		var atlas_def: TileAtlasDef = TileAtlasDef.new()
		atlas_def.id = StringName("%s_atlas" % str(biome_id))
		atlas_def.biome_id = biome_id
		atlas_def.source_id = TileConstants.source_id_for_biome(biome_id)
		atlas_def.tile_size = config.tile_size
		atlas_def.atlas_columns = TileConstants.ATLAS_COLUMNS
		var atlas_image: Image = TileGenerator.build_atlas_image(biome_id, TileConstants.VARIANTS_PER_SIGNATURE, atlas_def)
		var atlas_path: String = "%s/%s_atlas.png" % [ATLAS_DIR, str(biome_id)]
		var png_error: Error = atlas_image.save_png(atlas_path)
		if png_error != OK:
			messages.append("Failed to save atlas: %s" % atlas_path)
			continue
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		var texture: Texture2D = ResourceLoader.load(atlas_path) as Texture2D
		if texture == null:
			texture = ImageTexture.create_from_image(atlas_image)
		atlas_def.atlas_texture = texture
		var atlas_def_path: String = "%s/%s_atlas_def.tres" % [TILE_ATLAS_DEF_DIR, str(biome_id)]
		ResourceSaver.save(atlas_def, atlas_def_path)

		var biome_config: BiomeConfig = BiomeConfig.new()
		biome_config.id = biome_id
		biome_config.display_name = TileConstants.display_name_for_biome(biome_id)
		biome_config.tile_atlas = atlas_def
		_apply_default_biome_depths_and_chances(biome_config)
		var biome_path: String = "%s/%s.tres" % [BIOME_DIR, str(biome_id)]
		ResourceSaver.save(biome_config, biome_path)
		config.biome_configs.append(biome_config)
		messages.append("Generated atlas and TileAtlasDef for biome: %s" % str(biome_id))

	var special_atlas_def: TileAtlasDef = TileGenerator.generate_special_chunk_atlas_def()
	var special_atlas_image: Image = TileGenerator.build_special_chunk_atlas_image(special_atlas_def)
	var special_atlas_path: String = "%s/special_chunk_atlas.png" % ATLAS_DIR
	var special_png_error: Error = special_atlas_image.save_png(special_atlas_path)
	if special_png_error == OK:
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		var special_texture: Texture2D = ResourceLoader.load(special_atlas_path) as Texture2D
		if special_texture == null:
			special_texture = ImageTexture.create_from_image(special_atlas_image)
		special_atlas_def.atlas_texture = special_texture
		ResourceSaver.save(special_atlas_def, "%s/special_chunk_atlas_def.tres" % TILE_ATLAS_DEF_DIR)
		config.extra_tile_atlases.append(special_atlas_def)
		messages.append("Generated special-chunk atlas and TileAtlasDef.")
	else:
		messages.append("Failed to save special-chunk atlas: %s" % special_atlas_path)

	# Dedicated test atlas for CrystalGrottoChunk. It uses the same category-row
	# contract as the default SpecialChunk atlas but lives in its own TileSet source.
	var crystal_atlas_def: TileAtlasDef = TileGenerator.generate_special_chunk_atlas_def()
	crystal_atlas_def.id = &"crystal_grotto_atlas"
	crystal_atlas_def.source_id = 11
	var crystal_atlas_path: String = "%s/crystal_grotto_atlas.png" % ATLAS_DIR
	# Always rebuild the test atlas so category-edge and transparency changes are
	# reflected when the resource generation tool is run.
	var crystal_image: Image = TileGenerator.build_special_chunk_atlas_image(crystal_atlas_def)
	var crystal_png_error: Error = crystal_image.save_png(crystal_atlas_path)
	if crystal_png_error == OK:
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		var crystal_texture: Texture2D = ResourceLoader.load(crystal_atlas_path) as Texture2D
		if crystal_texture == null:
			crystal_texture = ImageTexture.create_from_image(crystal_image)
		crystal_atlas_def.atlas_texture = crystal_texture
		ResourceSaver.save(crystal_atlas_def, "%s/crystal_grotto_atlas_def.tres" % TILE_ATLAS_DEF_DIR)
		config.extra_tile_atlases.append(crystal_atlas_def)
		messages.append("Generated crystal-grotto test atlas and TileAtlasDef.")
	else:
		messages.append("Failed to save crystal-grotto atlas: %s" % crystal_atlas_path)

	# Common atlas for cross-biome authoring helpers such as common_air.
	# common_air is used by SpecialChunk scenes to mark continuous room interior
	# space that ENVIRONMENT_WANG_FILL must not overwrite.
	var common_atlas_def: TileAtlasDef = TileGenerator.generate_common_atlas_def()
	var common_atlas_image: Image = TileGenerator.build_common_atlas_image(common_atlas_def)
	var common_atlas_path: String = "%s/common_atlas.png" % ATLAS_DIR
	var common_png_error: Error = common_atlas_image.save_png(common_atlas_path)
	if common_png_error == OK:
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		var common_texture: Texture2D = ResourceLoader.load(common_atlas_path) as Texture2D
		if common_texture == null:
			common_texture = ImageTexture.create_from_image(common_atlas_image)
		common_atlas_def.atlas_texture = common_texture
		ResourceSaver.save(common_atlas_def, "%s/common_atlas_def.tres" % TILE_ATLAS_DEF_DIR)
		config.extra_tile_atlases.append(common_atlas_def)
		messages.append("Generated common helper atlas and TileAtlasDef.")
	else:
		messages.append("Failed to save common atlas: %s" % common_atlas_path)

	# These resources reference the included editable example scenes.
	var treasure_chunk: SpecialChunkDef = _make_default_special_chunk(
		&"mine_treasure_chunk",
		"Mine Treasure Chunk",
		SpecialChunkDef.ChunkKind.TREASURE,
		"res://scenes/special_chunks/MineTreasureChunk.tscn",
		[&"mine"],
		Vector2i.ONE,
		2,
		0,
		4,
		SpecialChunkDef.TransitionStyle.ROCK
	)
	ResourceSaver.save(treasure_chunk, "%s/mine_treasure_chunk.tres" % SPECIAL_CHUNK_DIR)
	config.special_chunk_defs.append(treasure_chunk)
	var hall_chunk: SpecialChunkDef = _make_default_special_chunk(
		&"ancient_hall_2x1_chunk",
		"Ancient Hall 2x1 Chunk",
		SpecialChunkDef.ChunkKind.HALL,
		"res://scenes/special_chunks/AncientHall2x1Chunk.tscn",
		[&"mine", &"deep"],
		Vector2i(2, 1),
		1,
		1,
		7,
		SpecialChunkDef.TransitionStyle.RUINS
	)
	ResourceSaver.save(hall_chunk, "%s/ancient_hall_2x1_chunk.tres" % SPECIAL_CHUNK_DIR)
	config.special_chunk_defs.append(hall_chunk)
	var snow_shrine_chunk: SpecialChunkDef = _make_default_special_chunk(
		&"snow_shrine_chunk",
		"Snow Shrine Chunk",
		SpecialChunkDef.ChunkKind.SHRINE,
		"res://scenes/special_chunks/SnowShrineChunk.tscn",
		[&"snow"],
		Vector2i.ONE,
		2,
		5,
		9,
		SpecialChunkDef.TransitionStyle.SNOW
	)
	ResourceSaver.save(snow_shrine_chunk, "%s/snow_shrine_chunk.tres" % SPECIAL_CHUNK_DIR)
	config.special_chunk_defs.append(snow_shrine_chunk)
	var crystal_chunk: SpecialChunkDef = _make_default_special_chunk(
		&"crystal_grotto_chunk",
		"Crystal Grotto Chunk",
		SpecialChunkDef.ChunkKind.DECORATIVE,
		"res://scenes/special_chunks/CrystalGrottoChunk.tscn",
		[&"snow", &"deep"],
		Vector2i.ONE,
		2,
		6,
		14,
		SpecialChunkDef.TransitionStyle.DEEP
	)
	crystal_chunk.tags.append(&"crystal")
	crystal_chunk.tags.append(&"grotto")
	crystal_chunk.prefer_chamber_edge = true
	crystal_chunk.prefer_branch_end = true
	crystal_chunk.prefer_structure_tags.clear()
	crystal_chunk.prefer_structure_tags.append(&"chamber_edge")
	crystal_chunk.prefer_structure_tags.append(&"branch_end")
	crystal_chunk.placement_weight = 1.4
	crystal_chunk.fill_mode = SpecialChunkDef.FillMode.ENVIRONMENT_WANG_FILL
	crystal_chunk.auto_fill_transition_border = false
	ResourceSaver.save(crystal_chunk, "%s/crystal_grotto_chunk.tres" % SPECIAL_CHUNK_DIR)
	config.special_chunk_defs.append(crystal_chunk)
	messages.append("Generated default SpecialChunkDef resources.")

	config.tile_set = TileSetBuilder.build_from_config(config, false)
	ResourceSaver.save(config.tile_set, "%s/generated_tileset.tres" % TILESET_DIR)
	ResourceSaver.save(config, "%s/default_world_gen_config.tres" % WORLD_GEN_DIR)
	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()
	messages.append("Generated TileSet and WorldGenConfig.")
	return messages

func _apply_default_biome_depths_and_chances(config: BiomeConfig) -> void:
	match config.id:
		&"mine":
			config.depth_min = -999
			config.depth_max = 4
			config.open_chance_main_path = 0.82
			config.open_chance_special = 0.64
			config.open_chance_cave = 0.62
			config.open_chance_solid = 0.28
		&"snow":
			config.depth_min = 5
			config.depth_max = 9
			config.open_chance_main_path = 0.86
			config.open_chance_special = 0.68
			config.open_chance_cave = 0.68
			config.open_chance_solid = 0.32
		&"deep":
			config.depth_min = 10
			config.depth_max = 999
			config.open_chance_main_path = 0.78
			config.open_chance_special = 0.60
			config.open_chance_cave = 0.56
			config.open_chance_solid = 0.24

func _ensure_dir(path: String) -> void:
	var absolute_parts: PackedStringArray = path.replace("res://", "").split("/", false)
	var current: String = "res://"
	for part: String in absolute_parts:
		var next_path: String = current.path_join(part)
		if not DirAccess.dir_exists_absolute(next_path):
			DirAccess.make_dir_absolute(next_path)
		current = next_path

func _make_default_special_chunk(
	chunk_id: StringName,
	display_name: String,
	chunk_kind: int,
	scene_path: String,
	allowed_biomes: Array,
	size_in_chunks: Vector2i,
	target_count: int,
	min_depth: int,
	max_depth: int,
	transition_style: int
) -> SpecialChunkDef:
	var chunk: SpecialChunkDef = SpecialChunkDef.new()
	chunk.id = chunk_id
	chunk.display_name = display_name
	chunk.chunk_kind = chunk_kind
	chunk.scene = ResourceLoader.load(scene_path) as PackedScene
	chunk.allowed_biomes.clear()
	for biome_id: StringName in allowed_biomes:
		chunk.allowed_biomes.append(biome_id)
	chunk.size_in_chunks = size_in_chunks
	chunk.target_count = target_count
	chunk.min_depth = min_depth
	chunk.max_depth = max_depth
	chunk.can_overlap_main_path = false
	chunk.require_near_main_path = true
	chunk.transition_style = transition_style
	chunk.fill_mode = SpecialChunkDef.FillMode.ENVIRONMENT_WANG_FILL
	chunk.auto_fill_transition_border = false
	_apply_default_special_chunk_structure_preferences(chunk)
	chunk.top_profile = _solid_profile(size_in_chunks.x * TileConstants.TILES_PER_CHUNK)
	chunk.bottom_profile = _solid_profile(size_in_chunks.x * TileConstants.TILES_PER_CHUNK)
	chunk.left_profile = _side_door_profile(size_in_chunks.y * TileConstants.TILES_PER_CHUNK)
	chunk.right_profile = _side_door_profile(size_in_chunks.y * TileConstants.TILES_PER_CHUNK)
	return chunk

func _apply_default_special_chunk_structure_preferences(chunk: SpecialChunkDef) -> void:
	chunk.prefer_structure_tags.clear()
	chunk.avoid_structure_tags.clear()
	chunk.avoid_structure_tags.append(&"chamber_interior")
	chunk.avoid_chamber_interior = true
	chunk.placement_weight = 1.0
	match chunk.chunk_kind:
		SpecialChunkDef.ChunkKind.TREASURE:
			chunk.prefer_branch_end = true
			chunk.prefer_chamber_edge = false
			chunk.prefer_structure_tags.append(&"branch_end")
			chunk.prefer_structure_tags.append(&"path_shoulder")
			chunk.placement_weight = 1.25
		SpecialChunkDef.ChunkKind.SHRINE:
			chunk.prefer_branch_end = true
			chunk.prefer_chamber_edge = true
			chunk.prefer_structure_tags.append(&"branch_end")
			chunk.prefer_structure_tags.append(&"chamber_edge")
			chunk.placement_weight = 1.35
		SpecialChunkDef.ChunkKind.HALL:
			chunk.prefer_branch_end = false
			chunk.prefer_chamber_edge = true
			chunk.prefer_structure_tags.append(&"chamber_edge")
			chunk.prefer_structure_tags.append(&"branch_end")
			chunk.placement_weight = 1.15
		_:
			chunk.prefer_branch_end = true
			chunk.prefer_chamber_edge = false

func _solid_profile(length: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(length):
		result.append(TileDef.Edge.SOLID)
	return result

func _side_door_profile(length: int) -> Array[int]:
	var result: Array[int] = _solid_profile(length)
	var mid: int = floori(float(length) / 2.0)
	if mid - 1 >= 0:
		result[mid - 1] = TileDef.Edge.OPEN
	if mid < result.size():
		result[mid] = TileDef.Edge.OPEN
	return result
