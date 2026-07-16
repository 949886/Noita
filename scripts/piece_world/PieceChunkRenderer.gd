class_name PieceChunkRenderer
extends Node2D

var sprite: Sprite2D
var data: PieceChunkData
var show_debug: bool = true

func _ready() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	z_index = 0

func setup(p_data: PieceChunkData) -> void:
	data = p_data
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	position = Vector2(data.coord * PieceWorldConstants.CHUNK_SIZE)
	sprite.texture = data.texture
	queue_redraw()

func _draw() -> void:
	if not show_debug or data == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE)), Color(0.3, 0.9, 1.0, 0.45), false, 2.0)
	for placement: PiecePlacement in data.placements:
		var r: Rect2i = placement.pixel_rect(PieceWorldConstants.UNIT_SIZE)
		var c: Color = Color(1.0, 0.45, 0.0, 0.65) if placement.is_glue else Color(0.4, 1.0, 0.5, 0.65)
		draw_rect(Rect2(Vector2(r.position), Vector2(r.size)), c, false, 1.0)
