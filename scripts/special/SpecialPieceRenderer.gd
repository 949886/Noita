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

func setup(p_placement: SpecialChunkPlacement, visual_downscale_factor: int = 1) -> void:
	setup_with_image(p_placement, SpecialPieceImageBuilder.build(p_placement), visual_downscale_factor)

func setup_with_image(p_placement: SpecialChunkPlacement, img: Image, visual_downscale_factor: int = 1) -> void:
	placement = p_placement
	visible = true
	position = Vector2(placement.origin_chunk * CHUNK_SIZE)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	var downscale: int = maxi(1, visual_downscale_factor)
	sprite.scale = Vector2(downscale, downscale)
	var upload_image: Image = img
	if downscale > 1:
		upload_image = img.duplicate()
		upload_image.resize(maxi(1, int(img.get_width() / downscale)), maxi(1, int(img.get_height() / downscale)), Image.INTERPOLATE_NEAREST)
	texture = ImageTexture.create_from_image(upload_image)
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
	debug_label.visible = true
	if placement != null and placement.chunk_def != null:
		debug_label.text = "%s\nPiece special %s" % [placement.chunk_def.display_name, str(placement.size_in_chunks)]

func recycle_for_pool() -> void:
	placement = null
	texture = null
	visible = false
	if sprite != null:
		sprite.texture = null
		sprite.scale = Vector2.ONE
	if debug_label != null:
		debug_label.visible = false
		debug_label.text = ""
	queue_redraw()
