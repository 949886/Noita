class_name PiecePlacement
extends RefCounted

var piece_def: PieceDef
var id: StringName = &""
var unit_pos: Vector2i = Vector2i.ZERO
var size_units: Vector2i = Vector2i.ONE
var is_glue: bool = false
var generated_image: Image
var sockets: Dictionary = {}
var phase: StringName = &"unknown"
var sequence_index: int = -1

func pixel_rect(unit_size: int) -> Rect2i:
	return Rect2i(unit_pos * unit_size, size_units * unit_size)
