class_name WorldGenConfig
extends Resource

# Top-level generation config loaded by WorldManager.
# It links the TileSet, biome configs, extra atlases, and SpecialChunk definitions used at runtime.

@export var world_seed: int = 20260706
@export var tile_size: Vector2i = Vector2i(64, 64)
@export var tiles_per_chunk: int = 8
@export var load_radius: int = 2
@export var tile_set: TileSet
@export var biome_configs: Array[BiomeConfig] = []
@export var extra_tile_atlases: Array[TileAtlasDef] = []
@export var special_chunk_defs: Array[SpecialChunkDef] = []
@export var enable_tilemap_collision: bool = false

func get_biome_config(biome_id: StringName) -> BiomeConfig:
	for biome_config: BiomeConfig in biome_configs:
		if biome_config.id == biome_id:
			return biome_config
	return null
