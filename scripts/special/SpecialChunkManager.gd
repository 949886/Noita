class_name SpecialChunkManager
extends RefCounted

# Loads/unloads special chunks as image-based pieces instead of TileMap scenes.
var planner: SpecialChunkPlanner
var parent_node: Node2D
var loaded_chunks: Dictionary = {}

func _init(p_planner: SpecialChunkPlanner, p_parent_node: Node2D) -> void:
	planner = p_planner
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
	var instance: SpecialPieceRenderer = SpecialPieceRenderer.new()
	instance.name = str(placement.id)
	parent_node.add_child(instance)
	instance.setup(placement)
	loaded_chunks[placement.id] = instance

func _unload_chunk(chunk_id: StringName) -> void:
	var instance: Node = loaded_chunks.get(chunk_id, null) as Node
	if instance != null:
		instance.queue_free()
	loaded_chunks.erase(chunk_id)
