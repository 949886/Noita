class_name BiomeConfig
extends Resource

@export var id: StringName = &"mine"
@export var display_name: String = "Mine"
@export var tile_atlas: TileAtlasDef

@export_range(0.0, 1.0) var open_chance_main_path: float = 0.68
@export_range(0.0, 1.0) var open_chance_special: float = 0.52
@export_range(0.0, 1.0) var open_chance_cave: float = 0.42
@export_range(0.0, 1.0) var open_chance_solid: float = 0.16

@export var depth_min: int = 0
@export var depth_max: int = 999
