class_name SpecialChunkManager
extends RefCounted

# Loads and unloads PackedScene-based special chunks.
# It tracks placements, not individual chunk coordinates, so a 2x1 structure is instantiated once.
var planner: SpecialChunkPlanner
var tile_set: TileSet
var parent_node: Node2D
var loaded_chunks: Dictionary = {}
var tiles_per_chunk: int = TileConstants.TILES_PER_CHUNK
var tile_size: int = TileConstants.TILE_SIZE

func _init(p_planner: SpecialChunkPlanner, p_tile_set: TileSet, p_parent_node: Node2D) -> void:
	planner = p_planner
	tile_set = p_tile_set
	parent_node = p_parent_node

func update_loaded_chunks(needed_chunks: Dictionary) -> void:
	if planner == null or parent_node == null:
		return
	var needed_special_chunks: Dictionary = {}
	for chunk_coord: Vector2i in needed_chunks.keys():
		var placement: SpecialChunkPlacement = planner.get_chunk_at(chunk_coord)
		if placement != null:
			needed_special_chunks[placement.id] = placement
	for key in needed_special_chunks.keys():
		var chunk_id: StringName = StringName(str(key))
		if not loaded_chunks.has(chunk_id):
			_load_chunk(needed_special_chunks[chunk_id] as SpecialChunkPlacement)
	var existing: Array = loaded_chunks.keys()
	for key in existing:
		var existing_id: StringName = StringName(str(key))
		if not needed_special_chunks.has(existing_id):
			_unload_chunk(existing_id)

func _load_chunk(placement: SpecialChunkPlacement) -> void:
	var instance: Node2D = null
	if placement.chunk_def.scene != null:
		instance = placement.chunk_def.scene.instantiate() as Node2D
	if instance == null:
		instance = SpecialChunkNode.new()
	instance.name = str(placement.id)
	instance.position = Vector2(
		placement.origin_chunk.x * tiles_per_chunk * tile_size,
		placement.origin_chunk.y * tiles_per_chunk * tile_size
	)
	parent_node.add_child(instance)
	if instance.has_method("setup_chunk"):
		instance.call("setup_chunk", placement, tile_set)
	loaded_chunks[placement.id] = instance

func _unload_chunk(chunk_id: StringName) -> void:
	var instance: Node = loaded_chunks.get(chunk_id, null) as Node
	if instance != null:
		instance.queue_free()
	loaded_chunks.erase(chunk_id)
