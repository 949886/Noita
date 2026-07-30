class_name WorldSeamRegistry
extends RefCounted

# Authoritative, cached socket seam storage for the whole world.
# A seam is generated once and then shared by both chunks that touch it:
# - chunk (x - 1, y).right and chunk (x, y).left use vertical_seams[(x, y)]
# - chunk (x, y - 1).bottom and chunk (x, y).top use horizontal_seams[(x, y)]
# This prevents load-order differences from producing open-vs-solid chunk borders.

const SLOTS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS

var planner: SocketProfilePlanner
var vertical_seams: Dictionary = {}
var horizontal_seams: Dictionary = {}

func _init(p_planner: SocketProfilePlanner) -> void:
	planner = p_planner

func clear() -> void:
	vertical_seams.clear()
	horizontal_seams.clear()

func get_profiles_for_chunk(coord: Vector2i) -> Dictionary:
	return {
		"top": get_horizontal(coord.x, coord.y),
		"bottom": get_horizontal(coord.x, coord.y + 1),
		"left": get_vertical(coord.x, coord.y),
		"right": get_vertical(coord.x + 1, coord.y),
	}

func get_vertical(edge_x: int, chunk_y: int) -> Array[PieceSocket.Socket]:
	var key: Vector2i = Vector2i(edge_x, chunk_y)
	if not vertical_seams.has(key):
		vertical_seams[key] = _canonicalize_profile(planner.get_vertical_profile(edge_x, chunk_y) if planner != null else [])
	return _duplicate_profile(vertical_seams.get(key, []))

func get_horizontal(chunk_x: int, edge_y: int) -> Array[PieceSocket.Socket]:
	var key: Vector2i = Vector2i(chunk_x, edge_y)
	if not horizontal_seams.has(key):
		horizontal_seams[key] = _canonicalize_profile(planner.get_horizontal_profile(chunk_x, edge_y) if planner != null else [])
	return _duplicate_profile(horizontal_seams.get(key, []))

func vertical_key_for_chunk_side(coord: Vector2i, side: StringName) -> Vector2i:
	if side == &"left":
		return Vector2i(coord.x, coord.y)
	if side == &"right":
		return Vector2i(coord.x + 1, coord.y)
	return Vector2i.ZERO

func horizontal_key_for_chunk_side(coord: Vector2i, side: StringName) -> Vector2i:
	if side == &"top":
		return Vector2i(coord.x, coord.y)
	if side == &"bottom":
		return Vector2i(coord.x, coord.y + 1)
	return Vector2i.ZERO

func _canonicalize_profile(profile_value: Variant) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	if profile_value is Array:
		for socket_value in profile_value:
			var socket: PieceSocket.Socket = PieceSocket.from_value(socket_value)
			# ANY is useful inside pieces, but world seams must be concrete.
			if socket == PieceSocket.ANY:
				socket = PieceSocket.OPEN_MEDIUM
			result.append(socket)
	while result.size() < SLOTS_PER_CHUNK:
		result.append(PieceSocket.SOLID)
	if result.size() > SLOTS_PER_CHUNK:
		result.resize(SLOTS_PER_CHUNK)
	return result

func _duplicate_profile(profile_value: Variant) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	if profile_value is Array:
		for socket_value in profile_value:
			result.append(PieceSocket.from_value(socket_value))
	return result
