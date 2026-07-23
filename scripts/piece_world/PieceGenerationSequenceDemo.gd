class_name PieceGenerationSequenceDemo
extends Node2D

@export var piece_library: PieceLibrary
@export var world_seed: int = 12345
@export var chunk_coord: Vector2i = Vector2i.ZERO
@export var step_delay: float = 0.22
@export var auto_play: bool = true
@export var loop_demo: bool = true

var library: PieceLibrary
var generator: PieceChunkGenerator
var planned_data: PieceChunkData
var display_image: Image
var display_texture: ImageTexture
var sprite: Sprite2D
var info_label: Label
var elapsed: float = 0.0
var next_index: int = 0
var placed: Array[PiecePlacement] = []
var paused: bool = false
var r_was_down: bool = false
var f3_was_down: bool = false
var f4_was_down: bool = false

func _ready() -> void:
	_setup_nodes()
	_restart_demo()

func _process(delta: float) -> void:
	_handle_input()
	if paused or not auto_play or planned_data == null:
		return
	elapsed += delta
	if elapsed >= step_delay:
		elapsed = 0.0
		_step_once()

func _setup_nodes() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.centered = false
		add_child(sprite)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		add_child(layer)
	info_label = layer.get_node_or_null("InfoLabel") as Label
	if info_label == null:
		info_label = Label.new()
		info_label.name = "InfoLabel"
		info_label.position = Vector2(12, 12)
		info_label.size = Vector2(780, 180)
		layer.add_child(info_label)
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.position = Vector2(PieceWorldConstants.CHUNK_SIZE / 2, PieceWorldConstants.CHUNK_SIZE / 2)
		cam.zoom = Vector2(1.15, 1.15)
		cam.enabled = true
		add_child(cam)

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		paused = not paused
		_update_label()
	if Input.is_action_just_pressed("ui_right"):
		_step_once()
	var r_down: bool = Input.is_key_pressed(KEY_R)
	var f3_down: bool = Input.is_key_pressed(KEY_F3)
	var f4_down: bool = Input.is_key_pressed(KEY_F4)
	if r_down and not r_was_down:
		_restart_demo()
	if f3_down and not f3_was_down:
		_restart_demo()
	if f4_down and not f4_was_down:
		world_seed += 1
		_restart_demo()
	r_was_down = r_down
	f3_was_down = f3_down
	f4_was_down = f4_down

func _restart_demo() -> void:
	if piece_library == null:
		push_error("PieceGenerationSequenceDemo has no PieceLibrary assigned.")
		return
	library = piece_library.duplicate(false) as PieceLibrary
	library.prepare()
	generator = PieceChunkGenerator.new(world_seed, library)
	planned_data = generator.generate_chunk(chunk_coord)
	display_image = Image.create_empty(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	display_image.fill(Color.TRANSPARENT)
	display_texture = ImageTexture.create_from_image(display_image)
	sprite.texture = display_texture
	placed.clear()
	next_index = 0
	elapsed = 0.0
	paused = false
	_update_label()
	queue_redraw()

func _step_once() -> void:
	if planned_data == null:
		return
	if next_index >= planned_data.placements.size():
		if loop_demo:
			_restart_demo()
		return
	var placement: PiecePlacement = planned_data.placements[next_index]
	_paste_placement(placement)
	placed.append(placement)
	next_index += 1
	display_texture = ImageTexture.create_from_image(display_image)
	sprite.texture = display_texture
	_update_label()
	queue_redraw()

func _paste_placement(placement: PiecePlacement) -> void:
	var dst_rect: Rect2i = placement.pixel_rect(PieceWorldConstants.UNIT_SIZE)
	if placement.is_glue:
		var glue_img: Image = placement.generated_image
		if glue_img == null or glue_img.is_empty():
			return
		_paste_image(display_image, glue_img, dst_rect)
		return
	if placement.piece_def == null:
		return
	_paste_texture(display_image, placement.piece_def.texture, dst_rect)

func _paste_texture(target: Image, tex: Texture2D, dst_rect: Rect2i) -> void:
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	_paste_image(target, img, dst_rect)

func _paste_image(target: Image, src: Image, dst_rect: Rect2i) -> void:
	var img: Image = src.duplicate()
	if img.is_compressed():
		var err: Error = img.decompress()
		if err != OK:
			return
	if img.get_format() != target.get_format():
		img.convert(target.get_format())
	if img.get_size() != dst_rect.size:
		img.resize(dst_rect.size.x, dst_rect.size.y, Image.INTERPOLATE_NEAREST)
	if img.get_format() != target.get_format():
		img.convert(target.get_format())
	target.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), dst_rect.position)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE)), Color(0.25, 0.9, 1.0, 0.65), false, 2.0)
	for placement: PiecePlacement in placed:
		var rect: Rect2i = placement.pixel_rect(PieceWorldConstants.UNIT_SIZE)
		var color: Color = _phase_color(placement.phase)
		draw_rect(Rect2(Vector2(rect.position), Vector2(rect.size)), color, false, 2.0)
	if next_index < _total_steps():
		var upcoming: PiecePlacement = planned_data.placements[next_index]
		var r: Rect2i = upcoming.pixel_rect(PieceWorldConstants.UNIT_SIZE)
		draw_rect(Rect2(Vector2(r.position), Vector2(r.size)), Color(1.0, 1.0, 1.0, 0.95), false, 3.0)

func _phase_color(phase: StringName) -> Color:
	match phase:
		&"anchor": return Color(1.0, 0.25, 0.25, 0.85)
		&"regular": return Color(0.35, 1.0, 0.45, 0.78)
		&"glue": return Color(1.0, 0.55, 0.05, 0.8)
		_: return Color(0.8, 0.8, 0.8, 0.7)

func _total_steps() -> int:
	if planned_data == null:
		return 0
	return planned_data.placements.size()

func _phase_counts() -> Dictionary:
	var counts: Dictionary = {&"anchor": 0, &"regular": 0, &"glue": 0}
	for placement: PiecePlacement in placed:
		var phase: StringName = placement.phase
		counts[phase] = int(counts.get(phase, 0)) + 1
	return counts

func _update_label() -> void:
	if info_label == null:
		return
	var counts: Dictionary = _phase_counts()
	var current_text: String = "done"
	if planned_data != null and next_index < planned_data.placements.size():
		var p: PiecePlacement = planned_data.placements[next_index]
		current_text = "%s  %s  units=%s" % [str(p.phase), str(p.id), str(p.size_units)]
	var pause_text: String = "paused" if paused else "playing"
	var biome_text: String = ""
	var type_text: String = ""
	if planned_data != null:
		biome_text = str(planned_data.biome_id)
		type_text = str(planned_data.chunk_type)
	info_label.text = "Piece Generation Sequence Demo\nseed=%d  chunk=%s  biome=%s  type=%s  %s\nstep=%d/%d  next=%s\nanchor=%d  regular=%d  glue=%d\nSPACE pause/play | Right step | R/F3 restart | F4 seed+1" % [world_seed, str(chunk_coord), biome_text, type_text, pause_text, next_index, _total_steps(), current_text, int(counts.get(&"anchor", 0)), int(counts.get(&"regular", 0)), int(counts.get(&"glue", 0))]
