class_name PieceSocket
extends RefCounted

# A socket is one 128px piece-edge connection slot. Runtime chunk edges now have
# four socket slots per side instead of the legacy eight 64px TileMap edge points.
#
# Keep socket types intentionally minimal: these are boundary-connection shapes,
# not semantic room types. Room/lab/cave identities belong to PieceDef.kind or tags.
enum Socket {
	SOLID,
	OPEN_SMALL,
	DOUBLE_OPEN_SMALL,
	OPEN_MEDIUM,
	OPEN_LARGE,
	ANY,
}

const SOLID: Socket = Socket.SOLID
const OPEN_SMALL: Socket = Socket.OPEN_SMALL
const DOUBLE_OPEN_SMALL: Socket = Socket.DOUBLE_OPEN_SMALL
const OPEN_MEDIUM: Socket = Socket.OPEN_MEDIUM
const OPEN_LARGE: Socket = Socket.OPEN_LARGE
const ANY: Socket = Socket.ANY

const _NAME_BY_SOCKET: Dictionary = {
	Socket.SOLID: &"solid",
	Socket.OPEN_SMALL: &"open_small",
	Socket.DOUBLE_OPEN_SMALL: &"double_open_small",
	Socket.OPEN_MEDIUM: &"open_medium",
	Socket.OPEN_LARGE: &"open_large",
	Socket.ANY: &"any",
}

const _SOCKET_BY_NAME: Dictionary = {
	&"solid": Socket.SOLID,
	&"open_small": Socket.OPEN_SMALL,
	&"double_open_small": Socket.DOUBLE_OPEN_SMALL,
	&"open_medium": Socket.OPEN_MEDIUM,
	&"open_large": Socket.OPEN_LARGE,
	&"any": Socket.ANY,
}

static func to_name(socket: Socket) -> StringName:
	return _NAME_BY_SOCKET.get(socket, &"solid")

static func from_name(socket_name: StringName) -> Socket:
	return _SOCKET_BY_NAME.get(socket_name, Socket.SOLID)

static func from_value(value: Variant) -> Socket:
	if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
		return from_name(StringName(str(value)))
	return int(value)

static func is_open(socket: Socket) -> bool:
	return socket != SOLID

static func is_open_family(socket: Socket) -> bool:
	return socket == OPEN_SMALL or socket == DOUBLE_OPEN_SMALL or socket == OPEN_MEDIUM or socket == OPEN_LARGE

static func compatibility_score(a: Socket, b: Socket) -> int:
	if a == b:
		return 100
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
	return 0

static func compatible(a: Socket, b: Socket) -> bool:
	return compatibility_score(a, b) >= 60

static func weakly_compatible(a: Socket, b: Socket) -> bool:
	return compatibility_score(a, b) > 0

static func open_width(socket: Socket, unit_size: int) -> int:
	match socket:
		OPEN_SMALL:
			return int(unit_size * 0.28)
		DOUBLE_OPEN_SMALL:
			return int(unit_size * 0.22)
		OPEN_MEDIUM:
			return int(unit_size * 0.46)
		OPEN_LARGE:
			return int(unit_size * 0.72)
		ANY:
			return int(unit_size * 0.50)
		_:
			return 0

static func opening_count(socket: Socket) -> int:
	match socket:
		DOUBLE_OPEN_SMALL:
			return 2
		OPEN_SMALL, OPEN_MEDIUM, OPEN_LARGE, ANY:
			return 1
		_:
			return 0

static func open_patterns(socket: Socket, unit_size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match socket:
		OPEN_SMALL:
			result.append(Vector2i(int(unit_size / 2), int(unit_size * 0.27)))
		DOUBLE_OPEN_SMALL:
			result.append(Vector2i(int(unit_size / 4), int(unit_size * 0.22)))
			result.append(Vector2i(int(unit_size * 3 / 4), int(unit_size * 0.22)))
		OPEN_MEDIUM:
			result.append(Vector2i(int(unit_size / 2), int(unit_size * 0.48)))
		OPEN_LARGE:
			result.append(Vector2i(int(unit_size / 2), int(unit_size * 0.72)))
		ANY:
			result.append(Vector2i(int(unit_size / 2), int(unit_size * 0.50)))
	return result

static func to_debug_char(socket: Socket) -> String:
	match socket:
		SOLID:
			return "S"
		OPEN_SMALL:
			return "s"
		DOUBLE_OPEN_SMALL:
			return "d"
		OPEN_MEDIUM:
			return "m"
		OPEN_LARGE:
			return "L"
		ANY:
			return "?"
		_:
			return "!"
