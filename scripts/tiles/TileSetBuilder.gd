class_name TileSetBuilder
extends RefCounted

static func build_from_config(config: WorldGenConfig, enable_physics: bool = false) -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = config.tile_size
	var _physics_enabled: bool = enable_physics
	for biome_config: BiomeConfig in config.biome_configs:
		if biome_config == null or biome_config.tile_atlas == null:
			continue
		_add_atlas_source(tile_set, biome_config.tile_atlas)
	for atlas_def: TileAtlasDef in config.extra_tile_atlases:
		if atlas_def == null:
			continue
		_add_atlas_source(tile_set, atlas_def)
	return tile_set

static func _add_atlas_source(tile_set: TileSet, atlas_def: TileAtlasDef) -> void:
	if atlas_def.atlas_texture == null:
		return
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = atlas_def.atlas_texture
	source.texture_region_size = atlas_def.tile_size
	tile_set.add_source(source, atlas_def.source_id)
	var used: Dictionary = {}
	for tile: TileDef in atlas_def.get_all_tiles_including_fallback():
		if tile == null:
			continue
		var key: String = "%d,%d" % [tile.atlas_coords.x, tile.atlas_coords.y]
		if used.has(key):
			continue
		used[key] = true
		source.create_tile(tile.atlas_coords)
