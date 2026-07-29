class_name BiomeConfig
extends Resource

@export var id: StringName = &"mine"
@export var display_name: String = "Mine"

@export_range(0.0, 1.0) var open_chance_main_path: float = 0.82
@export_range(0.0, 1.0) var open_chance_special: float = 0.64
@export_range(0.0, 1.0) var open_chance_cave: float = 0.62
@export_range(0.0, 1.0) var open_chance_solid: float = 0.28

@export var depth_min: int = 0
@export var depth_max: int = 999
