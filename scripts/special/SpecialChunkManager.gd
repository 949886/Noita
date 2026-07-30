class_name SpecialChunkManager
extends RefCounted

# Loads/unloads special chunks as image-based pieces instead of TileMap scenes.
# Special image construction can run in a background worker; Node and texture upload
# stay on the main thread.
var planner: SpecialChunkPlanner
var parent_node: Node2D
var loaded_chunks: Dictionary = {}
var pending_chunks: Dictionary = {}
var needed_special_chunks: Dictionary = {}
var use_threaded_generation: bool = true
var image_worker: SpecialChunkImageWorker
var last_result_ms: int = 0

func _init(p_planner: SpecialChunkPlanner, p_parent_node: Node2D, p_use_threaded_generation: bool = true) -> void:
	planner = p_planner
	parent_node = p_parent_node
	use_threaded_generation = p_use_threaded_generation
	if use_threaded_generation:
		image_worker = SpecialChunkImageWorker.new()
		if not image_worker.start():
			push_warning("SpecialChunkManager: special image worker failed to start; falling back to synchronous rendering.")
			image_worker = null
			use_threaded_generation = false

func stop() -> void:
	if image_worker != null:
		image_worker.stop()
		image_worker = null
	pending_chunks.clear()
	needed_special_chunks.clear()

func update_loaded_chunks(needed_chunks: Dictionary) -> void:
	if planner == null or parent_node == null:
		return
	needed_special_chunks.clear()
	for chunk_coord: Vector2i in needed_chunks.keys():
		var placement: SpecialChunkPlacement = planner.get_chunk_at(chunk_coord)
		if placement != null:
			needed_special_chunks[placement.id] = placement
	for key in needed_special_chunks.keys():
		var chunk_id: StringName = StringName(str(key))
		if loaded_chunks.has(chunk_id) or pending_chunks.has(chunk_id):
			continue
		var placement: SpecialChunkPlacement = needed_special_chunks[chunk_id] as SpecialChunkPlacement
		if use_threaded_generation and image_worker != null:
			pending_chunks[chunk_id] = placement
			image_worker.enqueue(placement)
		else:
			_load_chunk_sync(placement)
	var existing: Array = loaded_chunks.keys()
	for key in existing:
		var existing_id: StringName = StringName(str(key))
		if not needed_special_chunks.has(existing_id):
			_unload_chunk(existing_id)
	var pending_existing: Array = pending_chunks.keys()
	for key in pending_existing:
		var pending_id: StringName = StringName(str(key))
		if not needed_special_chunks.has(pending_id):
			pending_chunks.erase(pending_id)
	if image_worker != null:
		image_worker.prune_requests(needed_special_chunks)

func process_ready(upload_budget: int = 1) -> int:
	if image_worker == null:
		return 0
	var attached: int = 0
	var results: Array[Dictionary] = image_worker.collect_results(maxi(1, upload_budget))
	for result: Dictionary in results:
		var id: StringName = StringName(str(result.get("id", &"")))
		if not pending_chunks.has(id) or not needed_special_chunks.has(id):
			pending_chunks.erase(id)
			continue
		var placement: SpecialChunkPlacement = result.get("placement", null) as SpecialChunkPlacement
		var img: Image = result.get("image", null) as Image
		last_result_ms = int(result.get("elapsed_ms", 0))
		if placement != null and img != null and parent_node != null:
			_load_chunk_from_image(placement, img)
			attached += 1
		pending_chunks.erase(id)
	return attached

func _load_chunk_sync(placement: SpecialChunkPlacement) -> void:
	var instance: SpecialPieceRenderer = SpecialPieceRenderer.new()
	instance.name = str(placement.id)
	parent_node.add_child(instance)
	instance.setup(placement)
	loaded_chunks[placement.id] = instance

func _load_chunk_from_image(placement: SpecialChunkPlacement, img: Image) -> void:
	var instance: SpecialPieceRenderer = SpecialPieceRenderer.new()
	instance.name = str(placement.id)
	parent_node.add_child(instance)
	instance.setup_with_image(placement, img)
	loaded_chunks[placement.id] = instance

func _unload_chunk(chunk_id: StringName) -> void:
	var instance: Node = loaded_chunks.get(chunk_id, null) as Node
	if instance != null:
		instance.queue_free()
	loaded_chunks.erase(chunk_id)

func queued_count() -> int:
	return pending_chunks.size()

func worker_queue_count() -> int:
	return image_worker.queued_count() if image_worker != null else 0

func worker_result_count() -> int:
	return image_worker.result_count() if image_worker != null else 0
