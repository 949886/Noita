class_name PieceSocket
extends RefCounted

const SOLID: StringName = &"solid"
const OPEN_SMALL: StringName = &"open_small"
const DOUBLE_OPEN_SMALL: StringName = &"double_open_small"
const OPEN_MEDIUM: StringName = &"open_medium"
const OPEN_LARGE: StringName = &"open_large"
const ROOM: StringName = &"room"
const SHAFT: StringName = &"shaft"
const ANY: StringName = &"any"

static func is_open(socket: StringName) -> bool:
	return socket != SOLID and socket != &""

static func is_open_family(socket: StringName) -> bool:
	return socket == OPEN_SMALL or socket == DOUBLE_OPEN_SMALL or socket == OPEN_MEDIUM or socket == OPEN_LARGE

# Strict direct seam scoring.
# double_open_small is intentionally its own direct-match family: it does not directly
# match open_small, open_medium, or open_large. Use an adapter/glue piece for those transitions.
static func compatibility_score(a: StringName, b: StringName) -> int:
	if a == b:
		return 100
	if a == &"" or b == &"":
		return 0
	if a == ANY or b == ANY:
		return 80
	if a == SOLID or b == SOLID:
		return 0
	if a == DOUBLE_OPEN_SMALL or b == DOUBLE_OPEN_SMALL:
		return 0
	if (a == OPEN_SMALL and b == OPEN_MEDIUM) or (a == OPEN_MEDIUM and b == OPEN_SMALL):
		return 70
	if (a == OPEN_SMALL and b == OPEN_LARGE) or (a == OPEN_LARGE and b == OPEN_SMALL):
		return 30
	if (a == OPEN_MEDIUM and b == OPEN_LARGE) or (a == OPEN_LARGE and b == OPEN_MEDIUM):
		return 80
	if (a == ROOM and is_open_family(b)) or (b == ROOM and is_open_family(a)):
		return 70
	if (a == SHAFT and (b == OPEN_SMALL or b == OPEN_MEDIUM)) or (b == SHAFT and (a == OPEN_SMALL or a == OPEN_MEDIUM)):
		return 70
	return 0

static func compatible(a: StringName, b: StringName) -> bool:
	return compatibility_score(a, b) >= 60

static func weakly_compatible(a: StringName, b: StringName) -> bool:
	return compatibility_score(a, b) > 0

static func open_width(socket: StringName, unit_size: int) -> int:
	match socket:
		&"open_small": return int(unit_size * 0.28)
		&"double_open_small": return int(unit_size * 0.22)
		&"open_medium": return int(unit_size * 0.46)
		&"open_large": return int(unit_size * 0.72)
		&"room": return int(unit_size * 0.68)
		&"shaft": return int(unit_size * 0.34)
		&"any": return int(unit_size * 0.50)
		_: return 0

static func opening_count(socket: StringName) -> int:
	match socket:
		&"double_open_small": return 2
		&"open_small", &"open_medium", &"open_large", &"room", &"shaft", &"any": return 1
		_: return 0

# Returns per-slot opening patterns as Vector2i(offset_px_in_slot, opening_width_px).
static func open_patterns(socket: StringName, unit_size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match socket:
		&"open_small":
			result.append(Vector2i(unit_size / 2, int(unit_size * 0.27)))
		&"double_open_small":
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
