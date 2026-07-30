class_name PieceGenerationSequenceDemo
extends Node2D

# Step-by-step visualizer for the migrated piece generator.
# This is adapted from project 1's PieceGenerationSequenceDemo, but it uses the
# current project-2 runtime generation stack: WorldGenConfig, WorldStructure,
# SpecialChunkPlanner, WorldSeamRegistry, 128px piece units, 4 socket slots per
# chunk edge, actual/expected seam profiles, and non-destructive seam repair.

const DEFAULT_CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"
const DEFAULT_LIBRARY_PATH: String = "res://resources/pieces/piece_library.tres"
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const SOCKET_MARKER_RING_RADIUS: float = 7.0
const SOCKET_MARKER_DOT_RADIUS: float = 3.2
const SOCKET_MARKER_RING_WIDTH: float = 2.0

@export var piece_library: PieceLibrary
@export var world_gen_config: WorldGenConfig
@export var world_seed: int = 12345
@export var chunk_coord: Vector2i = Vector2i.ZERO
@export var step_delay: float = 0.22
@export var auto_play: bool = true
@export var loop_demo: bool = true
@export var build_world_structure: bool = true
@export var show_socket_markers: bool = true
@export var show_piece_bounds: bool = true
@export var show_unit_grid: bool = true
@export var show_upcoming_piece: bool = true

var library: PieceLibrary
var active_config: WorldGenConfig
var world_structure: WorldStructure
var special_chunk_planner: SpecialChunkPlanner
var generator: PieceChunkGenerator
var planned_data: PieceChunkData
var display_image: Image
var display_texture: ImageTexture
var sprite: Sprite2D
var info_label: Label
var legend_label: Label
var elapsed: float = 0.0
var next_index: int = 0
var visible_placements: Array[PiecePlacement] = []
var paused: bool = false
var r_was_down: bool = false
var f2_was_down: bool = false
var f3_was_down: bool = false
var f4_was_down: bool = false
var f5_was_down: bool = false
var home_was_down: bool = false
var backspace_was_down: bool = false

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
		info_label.size = Vector2(920, 230)
		layer.add_child(info_label)
	legend_label = layer.get_node_or_null("LegendLabel") as Label
	if legend_label == null:
		legend_label = Label.new()
		legend_label.name = "LegendLabel"
		legend_label.position = Vector2(12, 246)
		legend_label.size = Vector2(920, 170)
		layer.add_child(legend_label)
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		add_child(cam)
	cam.position = Vector2(CHUNK_SIZE / 2, CHUNK_SIZE / 2)
	cam.zoom = Vector2(1.15, 1.15)
	cam.enabled = true

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		paused = not paused
		_update_label()
	if Input.is_action_just_pressed("ui_right"):
		_step_once()
	if Input.is_action_just_pressed("ui_left"):
		_step_back_once()
	var r_down: bool = Input.is_key_pressed(KEY_R)
	var f2_down: bool = Input.is_key_pressed(KEY_F2)
	var f3_down: bool = Input.is_key_pressed(KEY_F3)
	var f4_down: bool = Input.is_key_pressed(KEY_F4)
	var f5_down: bool = Input.is_key_pressed(KEY_F5)
	var home_down: bool = Input.is_key_pressed(KEY_HOME)
	var backspace_down: bool = Input.is_key_pressed(KEY_BACKSPACE)
	if r_down and not r_was_down:
		_restart_demo()
	if f2_down and not f2_was_down:
		show_socket_markers = not show_socket_markers
		_update_label()
		queue_redraw()
	if f3_down and not f3_was_down:
		_restart_demo()
	if f4_down and not f4_was_down:
		world_seed += 1
		_restart_demo()
	if f5_down and not f5_was_down:
		world_seed -= 1
		_restart_demo()
	if home_down and not home_was_down:
		_show_all()
	if backspace_down and not backspace_was_down:
		_rebuild_display_to_step(0)
	r_was_down = r_down
	f2_was_down = f2_down
	f3_was_down = f3_down
	f4_was_down = f4_down
	f5_was_down = f5_down
	home_was_down = home_down
	backspace_was_down = backspace_down

func _restart_demo() -> void:
	active_config = _load_config()
	library = _load_piece_library()
	if library == null:
		push_error("PieceGenerationSequenceDemo: Unable to load PieceLibrary.")
		return
	library.prepare()
	world_structure = null
	special_chunk_planner = null
	if build_world_structure and active_config != null:
		world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
		var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
		planning_biome_map.world_structure = world_structure
		special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map, world_structure)
	generator = PieceChunkGenerator.new(world_seed, library, active_config, special_chunk_planner, world_structure)
	planned_data = generator.generate_chunk(chunk_coord)
	_reset_display_image()
	visible_placements.clear()
	next_index = 0
	elapsed = 0.0
	paused = false
	_update_label()
	queue_redraw()

func _load_config() -> WorldGenConfig:
	if world_gen_config != null:
		return world_gen_config
	var loaded: WorldGenConfig = ResourceLoader.load(DEFAULT_CONFIG_PATH) as WorldGenConfig
	return loaded

func _load_piece_library() -> PieceLibrary:
	if piece_library != null:
		return piece_library.duplicate(false) as PieceLibrary
	if active_config != null and active_config.piece_library != null:
		return active_config.piece_library.duplicate(false) as PieceLibrary
	var loaded: PieceLibrary = ResourceLoader.load(DEFAULT_LIBRARY_PATH) as PieceLibrary
	if loaded != null:
		return loaded.duplicate(false) as PieceLibrary
	return null

func _reset_display_image() -> void:
	display_image = Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	display_image.fill(Color.TRANSPARENT)
	display_texture = ImageTexture.create_from_image(display_image)
	if sprite != null:
		sprite.texture = display_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _step_once() -> void:
	if planned_data == null:
		return
	if next_index >= planned_data.placements.size():
		if loop_demo:
			_restart_demo()
		return
	var placement: PiecePlacement = planned_data.placements[next_index]
	_paste_placement(placement)
	visible_placements.append(placement)
	next_index += 1
	_update_texture()
	_update_label()
	queue_redraw()

func _step_back_once() -> void:
	if planned_data == null:
		return
	_rebuild_display_to_step(maxi(0, next_index - 1))

func _show_all() -> void:
	if planned_data == null:
		return
	_rebuild_display_to_step(planned_data.placements.size())

func _rebuild_display_to_step(step_count: int) -> void:
	if planned_data == null:
		return
	_reset_display_image()
	visible_placements.clear()
	next_index = clampi(step_count, 0, planned_data.placements.size())
	for i: int in range(next_index):
		var placement: PiecePlacement = planned_data.placements[i]
		_paste_placement(placement)
		visible_placements.append(placement)
	_update_texture()
	_update_label()
	queue_redraw()

func _update_texture() -> void:
	display_texture = ImageTexture.create_from_image(display_image)
	if sprite != null:
		sprite.texture = display_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _paste_placement(placement: PiecePlacement) -> void:
	var dst_rect: Rect2i = placement.pixel_rect(UNIT_SIZE)
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
	draw_rect(Rect2(Vector2.ZERO, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.25, 0.9, 1.0, 0.68), false, 2.0)
	if show_unit_grid:
		_draw_unit_grid()
	if show_piece_bounds:
		for placement: PiecePlacement in visible_placements:
			var rect: Rect2i = placement.pixel_rect(UNIT_SIZE)
			var color: Color = _phase_color(placement.phase)
			draw_rect(Rect2(Vector2(rect.position), Vector2(rect.size)), color, false, 2.0)
	if show_upcoming_piece and planned_data != null and next_index < planned_data.placements.size():
		var upcoming: PiecePlacement = planned_data.placements[next_index]
		var r: Rect2i = upcoming.pixel_rect(UNIT_SIZE)
		draw_rect(Rect2(Vector2(r.position), Vector2(r.size)), Color(1.0, 1.0, 1.0, 0.95), false, 3.0)
	if show_socket_markers and planned_data != null:
		_draw_socket_markers(planned_data)

func _draw_unit_grid() -> void:
	for i: int in range(1, UNITS_PER_CHUNK):
		var p: float = i * UNIT_SIZE
		draw_line(Vector2(p, 0), Vector2(p, CHUNK_SIZE), Color(1.0, 1.0, 1.0, 0.13), 1.0)
		draw_line(Vector2(0, p), Vector2(CHUNK_SIZE, p), Color(1.0, 1.0, 1.0, 0.13), 1.0)

func _draw_socket_markers(data: PieceChunkData) -> void:
	for i: int in range(UNITS_PER_CHUNK):
		var center_x: float = i * UNIT_SIZE + UNIT_SIZE * 0.5
		var center_y: float = i * UNIT_SIZE + UNIT_SIZE * 0.5
		_draw_profile_marker_pair(Vector2(center_x, 16), _socket_at(data.top_profile, i), _socket_at(data.actual_top_profile, i), Rect2(Vector2(i * UNIT_SIZE, 0), Vector2(UNIT_SIZE, 20)))
		_draw_profile_marker_pair(Vector2(CHUNK_SIZE - 16, center_y), _socket_at(data.right_profile, i), _socket_at(data.actual_right_profile, i), Rect2(Vector2(CHUNK_SIZE - 20, i * UNIT_SIZE), Vector2(20, UNIT_SIZE)))
		_draw_profile_marker_pair(Vector2(center_x, CHUNK_SIZE - 16), _socket_at(data.bottom_profile, i), _socket_at(data.actual_bottom_profile, i), Rect2(Vector2(i * UNIT_SIZE, CHUNK_SIZE - 20), Vector2(UNIT_SIZE, 20)))
		_draw_profile_marker_pair(Vector2(16, center_y), _socket_at(data.left_profile, i), _socket_at(data.actual_left_profile, i), Rect2(Vector2(0, i * UNIT_SIZE), Vector2(20, UNIT_SIZE)))

func _socket_at(profile: Array[PieceSocket.Socket], index: int) -> PieceSocket.Socket:
	if index >= 0 and index < profile.size():
		return PieceSocket.from_value(profile[index])
	return PieceSocket.SOLID

func _draw_profile_marker_pair(marker_pos: Vector2, expected: PieceSocket.Socket, actual: PieceSocket.Socket, edge_rect: Rect2) -> void:
	if actual != expected:
		draw_rect(edge_rect, Color(1.0, 0.05, 0.05, 0.42), true)
	_draw_expected_socket_ring(marker_pos, expected)
	_draw_actual_socket_dot(marker_pos, actual)

func _draw_expected_socket_ring(pos: Vector2, socket_value: int) -> void:
	var color: Color = _socket_color(socket_value)
	draw_arc(pos, SOCKET_MARKER_RING_RADIUS, 0.0, TAU, 32, color, SOCKET_MARKER_RING_WIDTH, true)

func _draw_actual_socket_dot(pos: Vector2, socket_value: int) -> void:
	var color: Color = _socket_color(socket_value)
	draw_circle(pos, SOCKET_MARKER_DOT_RADIUS, color)

func _socket_color(socket_value: int) -> Color:
	var socket: PieceSocket.Socket = PieceSocket.from_value(socket_value)
	match socket:
		PieceSocket.OPEN_SMALL:
			return Color(0.35, 1.0, 0.55, 0.92)
		PieceSocket.DOUBLE_OPEN_SMALL:
			return Color(0.35, 0.8, 1.0, 0.92)
		PieceSocket.OPEN_MEDIUM:
			return Color(0.2, 0.95, 0.75, 0.94)
		PieceSocket.OPEN_LARGE:
			return Color(1.0, 0.75, 0.25, 0.95)
		PieceSocket.ANY:
			return Color(1.0, 1.0, 1.0, 0.68)
		PieceSocket.SOLID:
			return Color(1.0, 1.0, 1.0, 0.30)
	return Color(0.9, 0.9, 0.9, 0.35)

func _phase_color(phase: StringName) -> Color:
	match phase:
		&"anchor":
			return Color(1.0, 0.25, 0.25, 0.85)
		&"regular":
			return Color(0.35, 1.0, 0.45, 0.78)
		&"glue":
			return Color(1.0, 0.55, 0.05, 0.8)
		&"seam_repair":
			return Color(1.0, 0.05, 0.05, 0.88)
		_:
			return Color(0.8, 0.8, 0.8, 0.7)

func _total_steps() -> int:
	if planned_data == null:
		return 0
	return planned_data.placements.size()

func _phase_counts() -> Dictionary:
	var counts: Dictionary = {&"anchor": 0, &"regular": 0, &"glue": 0, &"seam_repair": 0}
	for placement: PiecePlacement in visible_placements:
		var phase: StringName = placement.phase
		counts[phase] = int(counts.get(phase, 0)) + 1
	return counts

func _planned_phase_counts() -> Dictionary:
	var counts: Dictionary = {&"anchor": 0, &"regular": 0, &"glue": 0, &"seam_repair": 0}
	if planned_data == null:
		return counts
	for placement: PiecePlacement in planned_data.placements:
		var phase: StringName = placement.phase
		counts[phase] = int(counts.get(phase, 0)) + 1
	return counts

func _profile_to_string(profile: Array[PieceSocket.Socket]) -> String:
	var parts: Array[String] = []
	for socket_value in profile:
		parts.append(PieceSocket.to_debug_char(PieceSocket.from_value(socket_value)))
	return "".join(parts)

func _current_step_text() -> String:
	if planned_data == null:
		return "no data"
	if next_index >= planned_data.placements.size():
		return "done"
	var p: PiecePlacement = planned_data.placements[next_index]
	return "%s  %s  pos=%s  units=%s" % [str(p.phase), str(p.id), str(p.unit_pos), str(p.size_units)]

func _update_label() -> void:
	if info_label == null:
		return
	var counts: Dictionary = _phase_counts()
	var planned_counts: Dictionary = _planned_phase_counts()
	var pause_text: String = "paused" if paused else "playing"
	var biome_text: String = ""
	var type_text: String = ""
	var structure_text: String = ""
	var expected_text: String = "T/R/B/L: SSSS / SSSS / SSSS / SSSS"
	var actual_text: String = "T/R/B/L: SSSS / SSSS / SSSS / SSSS"
	var seam_text: String = "repairs=0 exact=0 compatible=0 broken=0 issues=0"
	if planned_data != null:
		biome_text = str(planned_data.biome_id)
		type_text = BiomeMap.chunk_type_name(planned_data.chunk_type)
		structure_text = planned_data.structure_tag_string()
		expected_text = "T/R/B/L: %s / %s / %s / %s" % [_profile_to_string(planned_data.top_profile), _profile_to_string(planned_data.right_profile), _profile_to_string(planned_data.bottom_profile), _profile_to_string(planned_data.left_profile)]
		actual_text = "T/R/B/L: %s / %s / %s / %s" % [_profile_to_string(planned_data.actual_top_profile), _profile_to_string(planned_data.actual_right_profile), _profile_to_string(planned_data.actual_bottom_profile), _profile_to_string(planned_data.actual_left_profile)]
		seam_text = "repairs=%d exact=%d compatible=%d broken=%d issues=%d" % [planned_data.seam_repair_count, planned_data.seam_exact_count, planned_data.seam_compatible_count, planned_data.seam_broken_count, planned_data.seam_issue_count]
	info_label.text = "Piece Generation Sequence Demo\nseed=%d  chunk=%s  biome=%s  type=%s  %s\nstructure=%s\nstep=%d/%d  next=%s\nvisible anchor=%d regular=%d glue=%d seam_repair=%d\nplanned anchor=%d regular=%d glue=%d seam_repair=%d\nExpected %s\nActual   %s\nSeam %s" % [world_seed, str(chunk_coord), biome_text, type_text, pause_text, structure_text, next_index, _total_steps(), _current_step_text(), int(counts.get(&"anchor", 0)), int(counts.get(&"regular", 0)), int(counts.get(&"glue", 0)), int(counts.get(&"seam_repair", 0)), int(planned_counts.get(&"anchor", 0)), int(planned_counts.get(&"regular", 0)), int(planned_counts.get(&"glue", 0)), int(planned_counts.get(&"seam_repair", 0)), expected_text, actual_text, seam_text]
	_update_legend_label()

func _update_legend_label() -> void:
	if legend_label == null:
		return
	legend_label.text = "Controls: SPACE pause/play | Right step | Left back | Home show all | Backspace clear | R/F3 restart | F4 seed+1 | F5 seed-1 | F2 sockets\nPiece bounds: red=anchor, green=regular, orange=glue, bright red=seam_repair. White outline marks next placement.\nSocket marker: outer ring=Expected/Canonical seam, inner dot=Actual generated edge; red edge strip means mismatch.\nSocket colors: gray/white=S solid, green=s open_small, blue=d double_open_small, teal=m open_medium, yellow=L open_large, white=? any."
