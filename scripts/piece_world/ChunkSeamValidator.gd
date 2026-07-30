class_name ChunkSeamValidator
extends RefCounted

# Validates expected-vs-actual socket profiles and loaded neighbor seams.
# This is debug/diagnostic only; PieceChunkGenerator performs local repair before
# returning each chunk.

const SLOTS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS

static func validate_chunk(data: PieceChunkData) -> Dictionary:
	var result: Dictionary = {
		"expected_exact": 0,
		"expected_compatible": 0,
		"expected_broken": 0,
		"issues": [],
	}
	if data == null:
		return result
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		var expected: Array[PieceSocket.Socket] = data.profile_for_side(side, false)
		var actual: Array[PieceSocket.Socket] = data.profile_for_side(side, true)
		for slot: int in range(SLOTS_PER_CHUNK):
			var e: PieceSocket.Socket = PieceSocket.from_value(expected[slot] if slot < expected.size() else PieceSocket.SOLID)
			var a: PieceSocket.Socket = PieceSocket.from_value(actual[slot] if slot < actual.size() else PieceSocket.SOLID)
			if a == e:
				result["expected_exact"] = int(result["expected_exact"]) + 1
			elif PieceSocket.compatible(a, e):
				result["expected_compatible"] = int(result["expected_compatible"]) + 1
			else:
				result["expected_broken"] = int(result["expected_broken"]) + 1
				var issues: Array = result["issues"]
				issues.append({
					"coord": data.coord,
					"side": side,
					"slot": slot,
					"expected": PieceSocket.to_name(e),
					"actual": PieceSocket.to_name(a),
					"kind": &"expected_vs_actual",
				})
	return result

static func validate_loaded_chunks(loaded_chunks: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"expected_exact": 0,
		"expected_compatible": 0,
		"expected_broken": 0,
		"neighbor_exact": 0,
		"neighbor_compatible": 0,
		"neighbor_broken": 0,
		"issues": [],
	}
	for item in loaded_chunks.values():
		var data: PieceChunkData = item as PieceChunkData
		if data == null:
			continue
		var local_result: Dictionary = validate_chunk(data)
		result["expected_exact"] = int(result["expected_exact"]) + int(local_result.get("expected_exact", 0))
		result["expected_compatible"] = int(result["expected_compatible"]) + int(local_result.get("expected_compatible", 0))
		result["expected_broken"] = int(result["expected_broken"]) + int(local_result.get("expected_broken", 0))
		var issues: Array = result["issues"]
		issues.append_array(local_result.get("issues", []))
	# Compare each seam once: right and bottom only.
	for coord_value in loaded_chunks.keys():
		var coord: Vector2i = coord_value
		var data: PieceChunkData = loaded_chunks.get(coord, null) as PieceChunkData
		if data == null:
			continue
		_compare_neighbor(data, loaded_chunks.get(coord + Vector2i.RIGHT, null) as PieceChunkData, &"right", &"left", result)
		_compare_neighbor(data, loaded_chunks.get(coord + Vector2i.DOWN, null) as PieceChunkData, &"bottom", &"top", result)
	return result

static func _compare_neighbor(a_chunk: PieceChunkData, b_chunk: PieceChunkData, side_a: StringName, side_b: StringName, result: Dictionary) -> void:
	if a_chunk == null or b_chunk == null:
		return
	var profile_a: Array[PieceSocket.Socket] = a_chunk.profile_for_side(side_a, true)
	var profile_b: Array[PieceSocket.Socket] = b_chunk.profile_for_side(side_b, true)
	for slot: int in range(SLOTS_PER_CHUNK):
		var a: PieceSocket.Socket = PieceSocket.from_value(profile_a[slot] if slot < profile_a.size() else PieceSocket.SOLID)
		var b: PieceSocket.Socket = PieceSocket.from_value(profile_b[slot] if slot < profile_b.size() else PieceSocket.SOLID)
		if a == b:
			result["neighbor_exact"] = int(result["neighbor_exact"]) + 1
		elif PieceSocket.compatible(a, b):
			result["neighbor_compatible"] = int(result["neighbor_compatible"]) + 1
		else:
			result["neighbor_broken"] = int(result["neighbor_broken"]) + 1
			var issues: Array = result["issues"]
			issues.append({
				"coord": a_chunk.coord,
				"neighbor_coord": b_chunk.coord,
				"side": side_a,
				"slot": slot,
				"actual": PieceSocket.to_name(a),
				"neighbor_actual": PieceSocket.to_name(b),
				"kind": &"neighbor_actual",
			})
