class_name SpecialChunkTransitionLookup
extends RefCounted

# Central lookup for SpecialChunk transition tiles.
# The special_chunk atlas reserves rows 7-10 for direction-aware transition art:
#   row 7  = top edge transitions
#   row 8  = right edge transitions
#   row 9  = bottom edge transitions
#   row 10 = left edge transitions
# Columns encode style + usage so SpecialChunkNode and future decoration renderers
# can resolve the same tile coordinates without duplicating atlas assumptions.

enum Direction {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT,
}

enum Usage {
	WALL,
	DOOR,
}

static func coords(style: int, usage: int, direction: int) -> Vector2i:
	return Vector2i(_column(style, usage), _row(direction))

static func usage_for_edge(edge_value: int) -> int:
	# Until the atlas gets dedicated AIR transition art, OPEN and AIR both use the door/opening transition.
	if edge_value == TileDef.Edge.OPEN or edge_value == TileDef.Edge.AIR:
		return Usage.DOOR
	return Usage.WALL

static func _row(direction: int) -> int:
	match direction:
		Direction.TOP:
			return TileConstants.SPECIAL_TRANSITION_TOP_ROW
		Direction.RIGHT:
			return TileConstants.SPECIAL_TRANSITION_RIGHT_ROW
		Direction.BOTTOM:
			return TileConstants.SPECIAL_TRANSITION_BOTTOM_ROW
		Direction.LEFT:
			return TileConstants.SPECIAL_TRANSITION_LEFT_ROW
		_:
			return TileConstants.SPECIAL_TRANSITION_TOP_ROW

static func _column(style: int, usage: int) -> int:
	var style_offset: int = 0
	match style:
		SpecialChunkDef.TransitionStyle.ROCK:
			style_offset = 0
		SpecialChunkDef.TransitionStyle.SNOW:
			style_offset = 1
		SpecialChunkDef.TransitionStyle.DEEP:
			style_offset = 2
		SpecialChunkDef.TransitionStyle.RUINS:
			style_offset = 3
		_:
			style_offset = 0
	if usage == Usage.DOOR:
		return 4 + style_offset
	return style_offset
