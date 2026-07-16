class_name PieceSocket
extends RefCounted

const OPEN_SMALL: StringName = &"open_small"
const OPEN_SMALL_DOUBLE: StringName = &"open_small_double"
const OPEN_MEDIUM: StringName = &"open_medium"
const OPEN_LARGE: StringName = &"open_large"
const SOLID: StringName = &"solid"

static func is_open(socket: StringName) -> bool:
	return socket != SOLID and socket != &""

static func compatible(a: StringName, b: StringName) -> bool:
	if a == &"any" or b == &"any":
		return true
	if a == b:
		return true
	if a == SOLID or b == SOLID:
		return false
	if _open_family(a) and _open_family(b):
		return true
	if a == &"room" and _open_family(b):
		return true
	if b == &"room" and _open_family(a):
		return true
	if a == &"shaft" and (b == OPEN_SMALL or b == OPEN_SMALL_DOUBLE or b == OPEN_MEDIUM):
		return true
	if b == &"shaft" and (a == OPEN_SMALL or a == OPEN_SMALL_DOUBLE or a == OPEN_MEDIUM):
		return true
	return false

static func _open_family(socket: StringName) -> bool:
	return socket == OPEN_SMALL or socket == OPEN_SMALL_DOUBLE or socket == OPEN_MEDIUM or socket == OPEN_LARGE

static func open_width(socket: StringName, unit_size: int) -> int:
	match socket:
		&"open_small": return int(unit_size * 0.28)
		&"open_small_double": return int(unit_size * 0.22)
		&"open_medium": return int(unit_size * 0.46)
		&"open_large": return int(unit_size * 0.72)
		&"room": return int(unit_size * 0.68)
		&"shaft": return int(unit_size * 0.34)
		&"any": return int(unit_size * 0.50)
		_: return 0

static func opening_count(socket: StringName) -> int:
	match socket:
		&"open_small_double": return 2
		&"open_small", &"open_medium", &"open_large", &"room", &"shaft", &"any": return 1
		_: return 0

# Returns per-slot opening patterns as Vector2i(offset_px_in_slot, opening_width_px).
static func open_patterns(socket: StringName, unit_size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match socket:
		&"open_small":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.27)))
		&"open_small_double":
			result.append(Vector2i(unit_size / 4, int(unit_size * 0.22)))
			result.append(Vector2i(unit_size * 3 / 4, int(unit_size * 0.22)))
		&"open_medium":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.48)))
		&"open_large":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.72)))
		&"room":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.68)))
		&"shaft":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.34)))
		&"any":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.50)))
	return result
