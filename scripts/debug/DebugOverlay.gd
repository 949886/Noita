extends CanvasLayer

@onready var label: Label = $Panel/Label

func set_debug_data(seed_value: int, center_chunk: Vector2i, loaded_count: int, fallback_count: int, renderer_name: String = "Sprite2D") -> void:
	label.text = "Seed: %d\nCenter chunk: (%d, %d)\nLoaded chunks: %d\nFallback tiles: %d\nRenderer: %s\nMove: WASD / Arrows\nZoom: + / -" % [seed_value, center_chunk.x, center_chunk.y, loaded_count, fallback_count, renderer_name]
