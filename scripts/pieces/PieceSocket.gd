class_name PieceSocket
extends RefCounted

static func is_open(socket: StringName) -> bool:
	return socket != &"solid" and socket != &""

static func compatible(a: StringName, b: StringName) -> bool:
	if a == &"any" or b == &"any":
		return true
	if a == b:
		return true
	if a == &"solid" or b == &"solid":
		return false
	if a == &"open_small" and b == &"open_medium":
		return true
	if a == &"open_medium" and (b == &"open_small" or b == &"open_large" or b == &"room"):
		return true
	if a == &"open_large" and (b == &"open_medium" or b == &"room"):
		return true
	if a == &"room" and (b == &"open_medium" or b == &"open_large"):
		return true
	return false

static func open_width(socket: StringName, unit_size: int) -> int:
	match socket:
		&"open_small": return int(unit_size * 0.28)
		&"open_medium": return int(unit_size * 0.46)
		&"open_large": return int(unit_size * 0.72)
		&"room": return int(unit_size * 0.68)
		&"shaft": return int(unit_size * 0.34)
		&"any": return int(unit_size * 0.50)
		_: return 0
