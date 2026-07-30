class_name ChunkGenerationWorker
extends RefCounted

# Single background worker for normal piece chunks.
# It performs CPU-heavy generation and Image composition off the main thread.
# Scene-tree work and ImageTexture upload are intentionally left to WorldManager.

var generator: PieceChunkGenerator
var thread: Thread
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var stop_requested: bool = false
var running: bool = false
var requests: Array[Vector2i] = []
var request_lookup: Dictionary = {}
var results: Array[Dictionary] = []
var completed_count: int = 0
var failed_count: int = 0
var last_error: String = ""

func start(p_generator: PieceChunkGenerator) -> bool:
	stop()
	generator = p_generator
	stop_requested = false
	requests.clear()
	request_lookup.clear()
	results.clear()
	completed_count = 0
	failed_count = 0
	last_error = ""
	thread = Thread.new()
	var err: Error = thread.start(Callable(self, "_thread_loop"))
	running = err == OK
	if not running:
		last_error = "Thread.start failed: %s" % str(err)
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

func enqueue(coord: Vector2i) -> bool:
	if not running or generator == null:
		return false
	var should_post: bool = false
	mutex.lock()
	if not request_lookup.has(coord):
		request_lookup[coord] = true
		requests.append(coord)
		should_post = true
	mutex.unlock()
	if should_post:
		semaphore.post()
	return should_post

func clear_pending() -> void:
	mutex.lock()
	requests.clear()
	request_lookup.clear()
	mutex.unlock()

func prune_requests(allowed_coords: Dictionary) -> void:
	mutex.lock()
	var kept: Array[Vector2i] = []
	request_lookup.clear()
	for coord: Vector2i in requests:
		if allowed_coords.has(coord):
			kept.append(coord)
			request_lookup[coord] = true
	requests = kept
	mutex.unlock()

func collect_results(max_results: int = 2) -> Array[Dictionary]:
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

func is_queued(coord: Vector2i) -> bool:
	mutex.lock()
	var found: bool = request_lookup.has(coord)
	mutex.unlock()
	return found

func _thread_loop() -> void:
	while true:
		semaphore.wait()
		var coord: Vector2i = Vector2i.ZERO
		var has_request: bool = false
		mutex.lock()
		if stop_requested:
			mutex.unlock()
			break
		if not requests.is_empty():
			coord = requests.pop_front()
			request_lookup.erase(coord)
			has_request = true
		mutex.unlock()
		if not has_request:
			continue
		var data: PieceChunkData = null
		var ok: bool = false
		var error_text: String = ""
		var started_ms: int = Time.get_ticks_msec()
		if generator == null:
			error_text = "generator missing"
		else:
			data = generator.generate_chunk(coord, false)
			ok = data != null
			if not ok:
				error_text = "generate_chunk returned null"
		var elapsed_ms: int = Time.get_ticks_msec() - started_ms
		mutex.lock()
		if ok:
			completed_count += 1
			results.append({
				"coord": coord,
				"data": data,
				"elapsed_ms": elapsed_ms,
			})
		else:
			failed_count += 1
			last_error = error_text
			results.append({
				"coord": coord,
				"data": null,
				"elapsed_ms": elapsed_ms,
				"error": error_text,
			})
		mutex.unlock()
