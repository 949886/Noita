class_name SpecialPieceRenderer
extends Node2D

# Image-based special chunk renderer used after the TileMap migration. It keeps
# SpecialChunkDef placement/planning but renders authored structures as large pieces.
# CPU image construction can be performed by SpecialChunkImageWorker; this Node only
# attaches the image to an ImageTexture on the main thread.
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

var placement: SpecialChunkPlacement
var sprite: Sprite2D
var texture: ImageTexture
var debug_label: Label

func setup(p_placement: SpecialChunkPlacement) -> void:
	setup_with_image(p_placement, SpecialPieceImageBuilder.build(p_placement))

func setup_with_image(p_placement: SpecialChunkPlacement, img: Image) -> void:
	placement = p_placement
	position = Vector2(placement.origin_chunk * CHUNK_SIZE)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	texture = ImageTexture.create_from_image(img)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_debug_label()
	queue_redraw()

func _ensure_debug_label() -> void:
	if debug_label == null:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.position = Vector2(12, 12)
		debug_label.add_theme_font_size_override("font_size", 12)
		debug_label.add_theme_color_override("font_color", Color(1.0, 0.9, 1.0, 0.92))
		add_child(debug_label)
	if placement != null and placement.chunk_def != null:
		debug_label.text = "%s\nPiece special %s" % [placement.chunk_def.display_name, str(placement.size_in_chunks)]
