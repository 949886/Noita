class_name PieceWorldManager
extends Node2D

@export var world_seed: int = 12345
@export var load_radius: int = 2
@export var player_path: NodePath
@export var chunk_container_path: NodePath
@export var debug_overlay_path: NodePath

var library: PieceLibrary
var generator: PieceChunkGenerator
var loaded_chunks: Dictionary = {}
var chunk_data_by_coord: Dictionary = {}
var current_player_chunk: Vector2i = Vector2i.ZERO
var debug_draw_enabled: bool = true
var player: Node2D
var chunk_container: Node2D
var f1_down: bool = false
var f3_down: bool = false
var f4_down: bool = false

func _ready() -> void:
	player = get_node_or_null(player_path) as Node2D
	chunk_container = get_node_or_null(chunk_container_path) as Node2D
	if chunk_container == null:
		chunk_container = Node2D.new()
		chunk_container.name = "ChunkRenderers"
		add_child(chunk_container)
	var overlay: PieceDebugOverlay = get_node_or_null(debug_overlay_path) as PieceDebugOverlay
	if overlay != null:
		overlay.manager = self
	_regenerate()

func _process(_delta: float) -> void:
	var f1_now: bool = Input.is_key_pressed(KEY_F1)
	var f3_now: bool = Input.is_key_pressed(KEY_F3)
	var f4_now: bool = Input.is_key_pressed(KEY_F4)
	if f1_now and not f1_down:
		debug_draw_enabled = not debug_draw_enabled
		_update_debug_visibility()
	if f3_now and not f3_down:
		_regenerate()
	if f4_now and not f4_down:
		world_seed += 1
		_regenerate()
	f1_down = f1_now
	f3_down = f3_now
	f4_down = f4_now
	_update_streaming()

func _regenerate() -> void:
	for child: Node in chunk_container.get_children():
		child.queue_free()
	loaded_chunks.clear()
	chunk_data_by_coord.clear()
	library = PieceLibrary.new()
	library.load_from_default_dirs()
	generator = PieceChunkGenerator.new(world_seed, library)
	_update_streaming()

func _update_streaming() -> void:
	if player == null or generator == null:
		return
	current_player_chunk = world_to_chunk(player.global_position)
	var needed: Dictionary = {}
	for y: int in range(current_player_chunk.y - load_radius, current_player_chunk.y + load_radius + 1):
		for x: int in range(current_player_chunk.x - load_radius, current_player_chunk.x + load_radius + 1):
			var coord: Vector2i = Vector2i(x, y)
			needed[coord] = true
			if not loaded_chunks.has(coord):
				_load_chunk(coord)
	var to_remove: Array = []
	for coord: Vector2i in loaded_chunks.keys():
		if not needed.has(coord):
			to_remove.append(coord)
	for coord: Vector2i in to_remove:
		_unload_chunk(coord)

func _load_chunk(coord: Vector2i) -> void:
	var data: PieceChunkData = generator.generate_chunk(coord)
	var renderer: PieceChunkRenderer = PieceChunkRenderer.new()
	chunk_container.add_child(renderer)
	renderer.setup(data)
	renderer.show_debug = debug_draw_enabled
	loaded_chunks[coord] = renderer
	chunk_data_by_coord[coord] = data

func _unload_chunk(coord: Vector2i) -> void:
	var renderer: Node = loaded_chunks.get(coord, null)
	if renderer != null:
		renderer.queue_free()
	loaded_chunks.erase(coord)
	chunk_data_by_coord.erase(coord)

func _update_debug_visibility() -> void:
	for renderer: PieceChunkRenderer in loaded_chunks.values():
		renderer.show_debug = debug_draw_enabled
		renderer.queue_redraw()

func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(PieceWorldConstants.CHUNK_SIZE)), floori(world_pos.y / float(PieceWorldConstants.CHUNK_SIZE)))
