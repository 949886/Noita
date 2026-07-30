class_name PieceChunkRenderer
extends Node2D

# Runtime image renderer for generated piece chunks. Debug visualization is handled
# by the second project's WorldDebugDrawer, so this renderer only owns display data.
var sprite: Sprite2D
var data: PieceChunkData
var show_debug: bool = false

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
	position = Vector2(data.coord * PieceWorldConstants.CHUNK_SIZE).round()
	if data.texture == null and data.visual_image != null and not data.visual_image.is_empty():
		# Texture upload must stay on the main thread. Background workers only build Images.
		data.texture = ImageTexture.create_from_image(data.visual_image)
	sprite.texture = data.texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if not show_debug or data == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE)), Color(0.1, 0.9, 1.0, 0.95), false, 2.0)
	for placement: PiecePlacement in data.placements:
		var r: Rect2i = placement.pixel_rect(PieceWorldConstants.UNIT_SIZE)
		draw_rect(Rect2(Vector2(r.position), Vector2(r.size)), _phase_color(placement.phase), false, 2.0)

func _phase_color(phase: StringName) -> Color:
	match phase:
		&"anchor":
			return Color(1.0, 0.25, 0.25, 1.0)
		&"regular":
			return Color(0.2, 1.0, 0.35, 1.0)
		&"glue":
			return Color(1.0, 0.65, 0.1, 1.0)
		_:
			return Color(0.9, 0.9, 0.9, 1.0)
