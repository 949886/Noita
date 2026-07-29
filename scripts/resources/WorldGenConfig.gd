class_name WorldGenConfig
extends Resource

# Top-level generation config for the piece-based runtime world.
@export var world_seed: int = 20260706
@export var unit_size: int = 128
@export var units_per_chunk: int = 4
@export var load_radius: int = 2
@export var piece_library: PieceLibrary
@export var biome_configs: Array[BiomeConfig] = []
@export var special_chunk_defs: Array[SpecialChunkDef] = []

func get_biome_config(biome_id: StringName) -> BiomeConfig:
	for biome_config: BiomeConfig in biome_configs:
		if biome_config != null and biome_config.id == biome_id:
			return biome_config
	return null
