class_name SpecialChunkImageWorker
extends RefCounted

# Background worker for CPU-heavy special chunk image construction.
# The main thread still creates Nodes and ImageTextures.

var thread: Thread
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var stop_requested: bool = false
var running: bool = false
var requests: Array[SpecialChunkPlacement] = []
var request_lookup: Dictionary = {}
var results: Array[Dictionary] = []
var completed_count: int = 0

func start() -> bool:
	stop()
	stop_requested = false
	requests.clear()
	request_lookup.clear()
	results.clear()
	completed_count = 0
	thread = Thread.new()
	var err: Error = thread.start(Callable(self, "_thread_loop"))
	running = err == OK
	if not running:
		thread = null
	return running

func stop() -> void:
	if thread == null:
		running = false
		return
	mutex.lock()
	stop_requested = true
	requests.clear()
	request_lookup.clear()
	mutex.unlock()
	semaphore.post()
	thread.wait_to_finish()
	thread = null
	running = false
	stop_requested = false

func enqueue(placement: SpecialChunkPlacement) -> bool:
	if not running or placement == null:
		return false
	var id: StringName = placement.id
	var should_post: bool = false
	mutex.lock()
	if not request_lookup.has(id):
		request_lookup[id] = true
		requests.append(placement)
		should_post = true
	mutex.unlock()
	if should_post:
		semaphore.post()
	return should_post

func prune_requests(allowed_ids: Dictionary) -> void:
	mutex.lock()
	var kept: Array[SpecialChunkPlacement] = []
	request_lookup.clear()
	for placement: SpecialChunkPlacement in requests:
		if placement != null and allowed_ids.has(placement.id):
			kept.append(placement)
			request_lookup[placement.id] = true
	requests = kept
	mutex.unlock()

func collect_results(max_results: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	mutex.lock()
	var count: int = maxi(1, max_results)
	while count > 0 and not results.is_empty():
		out.append(results.pop_front())
		count -= 1
	mutex.unlock()
	return out

func queued_count() -> int:
	mutex.lock()
	var count: int = requests.size()
	mutex.unlock()
	return count

func result_count() -> int:
	mutex.lock()
	var count: int = results.size()
	mutex.unlock()
	return count

func clear_pending() -> void:
	mutex.lock()
	requests.clear()
	request_lookup.clear()
	mutex.unlock()

func _thread_loop() -> void:
	while true:
		semaphore.wait()
		var placement: SpecialChunkPlacement = null
		var has_request: bool = false
		mutex.lock()
		if stop_requested:
			mutex.unlock()
			break
		if not requests.is_empty():
			placement = requests.pop_front()
			request_lookup.erase(placement.id)
			has_request = true
		mutex.unlock()
		if not has_request or placement == null:
			continue
		var started_ms: int = Time.get_ticks_msec()
		var img: Image = SpecialPieceImageBuilder.build(placement)
		var elapsed_ms: int = Time.get_ticks_msec() - started_ms
		mutex.lock()
		completed_count += 1
		results.append({
			"id": placement.id,
			"placement": placement,
			"image": img,
			"elapsed_ms": elapsed_ms,
		})
		mutex.unlock()
