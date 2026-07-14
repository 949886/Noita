class_name TileLibrary
extends RefCounted

var tiles_by_biome: Dictionary = {}
var atlas_by_biome: Dictionary = {}
var atlas_by_id: Dictionary = {}
var biome_configs: Dictionary = {}
var fallback_count: int = 0
var compatible_match_count: int = 0

func load_from_config(config: WorldGenConfig) -> void:
	tiles_by_biome.clear()
	atlas_by_biome.clear()
	atlas_by_id.clear()
	biome_configs.clear()
	fallback_count = 0
	compatible_match_count = 0
	for biome_config: BiomeConfig in config.biome_configs:
		if biome_config == null or biome_config.tile_atlas == null:
			continue
		var biome_id: StringName = biome_config.id
		biome_configs[biome_id] = biome_config
		atlas_by_biome[biome_id] = biome_config.tile_atlas
		atlas_by_id[biome_config.tile_atlas.id] = biome_config.tile_atlas
		var wang_tiles: Array[TileDef] = []
		for item in biome_config.tile_atlas.tiles:
			var tile: TileDef = item as TileDef
			if tile != null and tile.tile_role == TileDef.TileRole.WANG:
				wang_tiles.append(tile)
		tiles_by_biome[biome_id] = wang_tiles
	for atlas_def: TileAtlasDef in config.extra_tile_atlases:
		if atlas_def != null:
			atlas_by_id[atlas_def.id] = atlas_def

func build_demo_library() -> WorldGenConfig:
	var config: WorldGenConfig = WorldGenConfig.new()
	config.world_seed = 20260706
	config.tile_size = Vector2i(TileConstants.TILE_SIZE, TileConstants.TILE_SIZE)
	config.tiles_per_chunk = TileConstants.TILES_PER_CHUNK
	config.load_radius = 2
	for biome_id: StringName in TileConstants.biome_ids():
		var atlas_def: TileAtlasDef = TileGenerator.generate_atlas_def(biome_id)
		var biome_config: BiomeConfig = BiomeConfig.new()
		biome_config.id = biome_id
		biome_config.display_name = TileConstants.display_name_for_biome(biome_id)
		biome_config.tile_atlas = atlas_def
		config.biome_configs.append(biome_config)
	config.extra_tile_atlases.append(TileGenerator.generate_special_chunk_atlas_def())
	config.tile_set = TileSetBuilder.build_from_config(config, false)
	load_from_config(config)
	return config

func get_tiles_for_biome(biome_id: StringName) -> Array:
	return tiles_by_biome.get(biome_id, tiles_by_biome.get(&"mine", []))

func get_atlas_for_biome(biome_id: StringName) -> TileAtlasDef:
	return atlas_by_biome.get(biome_id, atlas_by_biome.get(&"mine", null)) as TileAtlasDef

func get_atlas_by_id(atlas_id: StringName) -> TileAtlasDef:
	return atlas_by_id.get(atlas_id, null) as TileAtlasDef

func get_source_id_for_biome(biome_id: StringName) -> int:
	var atlas_def: TileAtlasDef = get_atlas_for_biome(biome_id)
	if atlas_def == null:
		return 0
	return atlas_def.source_id

func get_source_id_for_atlas(atlas_id: StringName) -> int:
	var atlas_def: TileAtlasDef = get_atlas_by_id(atlas_id)
	if atlas_def == null:
		return 0
	return atlas_def.source_id

func get_biome_config(biome_id: StringName) -> BiomeConfig:
	return biome_configs.get(biome_id, biome_configs.get(&"mine", null)) as BiomeConfig

func find_exact_candidates(biome_id: StringName, constraints: Dictionary) -> Array[TileDef]:
	return _find_candidates_internal(biome_id, constraints, true)

func find_compatible_candidates(biome_id: StringName, constraints: Dictionary) -> Array[TileDef]:
	return _find_candidates_internal(biome_id, constraints, false)

func find_candidates(biome_id: StringName, constraints: Dictionary) -> Array[TileDef]:
	# Public helper kept for older debug code. Runtime selection uses exact first, then compatible fallback.
	return find_compatible_candidates(biome_id, constraints)

func _find_candidates_internal(biome_id: StringName, constraints: Dictionary, exact_only: bool) -> Array[TileDef]:
	var result: Array[TileDef] = []
	var source: Array = get_tiles_for_biome(biome_id)
	for item in source:
		var tile: TileDef = item as TileDef
		if tile == null or tile.is_fallback or tile.tile_role != TileDef.TileRole.WANG:
			continue
		if tile.weight <= 0.0:
			continue
		var ok: bool = true
		for side in constraints.keys():
			var side_name: StringName = StringName(str(side))
			var needed_edge: int = int(constraints[side])
			var tile_edge: int = tile.edge(side_name)
			if exact_only:
				if tile_edge != needed_edge:
					ok = false
					break
			elif not TileDef.edge_compatible(tile_edge, needed_edge):
				ok = false
				break
		if ok:
			result.append(tile)
	return result

func pick_matching_tile(biome_id: StringName, constraints: Dictionary, rng: RandomNumberGenerator) -> TileDef:
	# AIR uses exact-first selection so AAAA is chosen whenever it is actually available.
	# Compatible fallback is only used when an atlas is missing an exact signature.
	var exact_candidates: Array[TileDef] = find_exact_candidates(biome_id, constraints)
	if not exact_candidates.is_empty():
		return WeightedPicker.pick(exact_candidates, rng) as TileDef
	var compatible_candidates: Array[TileDef] = find_compatible_candidates(biome_id, constraints)
	if not compatible_candidates.is_empty():
		compatible_match_count += 1
		return WeightedPicker.pick(compatible_candidates, rng) as TileDef
	fallback_count += 1
	return get_fallback_tile(biome_id)

func get_fallback_tile(biome_id: StringName) -> TileDef:
	var atlas_def: TileAtlasDef = get_atlas_for_biome(biome_id)
	if atlas_def != null and atlas_def.fallback_tile != null:
		return atlas_def.fallback_tile
	var fallback: TileDef = TileDef.new(&"runtime_fallback", TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, TileDef.Edge.SOLID, 1.0)
	fallback.is_fallback = true
	fallback.tile_role = TileDef.TileRole.DEBUG
	fallback.atlas_coords = TileConstants.fallback_atlas_coords()
	return fallback
