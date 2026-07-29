class_name SpecialChunkDef
extends Resource

# Metadata for a piece-rendered special chunk. The old TileMap scene/TileSet path
# is intentionally gone; external seams are stored as PieceSocket slots.
enum ChunkKind {
	TREASURE,
	SHOP,
	ALTAR,
	PORTAL,
	BOSS_ENTRANCE,
	PUZZLE,
	HALL,
	SHRINE,
	DECORATIVE,
}

enum TransitionStyle {
	ROCK,
	SNOW,
	DEEP,
	RUINS,
}

enum FillMode {
	NONE,
	PIECE_BORDER,
	PIECE_ENVIRONMENT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("Treasure", "Shop", "Altar", "Portal", "Boss Entrance", "Puzzle", "Hall", "Shrine", "Decorative") var chunk_kind: int = ChunkKind.DECORATIVE
@export var allowed_biomes: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var prefer_structure_tags: Array[StringName] = []
@export var avoid_structure_tags: Array[StringName] = []
@export var prefer_branch_end: bool = true
@export var prefer_chamber_edge: bool = false
@export var avoid_chamber_interior: bool = true
@export var placement_weight: float = 1.0
@export var size_in_chunks: Vector2i = Vector2i.ONE
@export var weight: float = 1.0
@export var target_count: int = 1
@export var unique_per_world: bool = false
@export var min_depth: int = 0
@export var max_depth: int = 999
@export var can_overlap_main_path: bool = false
@export var require_near_main_path: bool = false
@export_enum("Rock", "Snow", "Deep", "Ruins") var transition_style: int = TransitionStyle.ROCK
@export_enum("None", "Piece Border", "Piece Environment") var fill_mode: int = FillMode.PIECE_ENVIRONMENT

# Profiles are four 128px socket slots per chunk edge.
# For a 2x1 chunk, top/bottom have 8 entries; left/right have 4 entries.
@export var top_profile: Array[int] = []
@export var right_profile: Array[int] = []
@export var bottom_profile: Array[int] = []
@export var left_profile: Array[int] = []

func profile_length_top_bottom(slots_per_chunk: int) -> int:
	return size_in_chunks.x * slots_per_chunk

func profile_length_left_right(slots_per_chunk: int) -> int:
	return size_in_chunks.y * slots_per_chunk

func validate_profiles(slots_per_chunk: int) -> bool:
	return top_profile.size() == profile_length_top_bottom(slots_per_chunk) \
		and bottom_profile.size() == profile_length_top_bottom(slots_per_chunk) \
		and left_profile.size() == profile_length_left_right(slots_per_chunk) \
		and right_profile.size() == profile_length_left_right(slots_per_chunk)

func socket_profile(side: StringName, local_chunk_offset: Vector2i, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	match side:
		&"top":
			return _slice_socket_profile(top_profile, local_chunk_offset.x, slots_per_chunk)
		&"bottom":
			return _slice_socket_profile(bottom_profile, local_chunk_offset.x, slots_per_chunk)
		&"left":
			return _slice_socket_profile(left_profile, local_chunk_offset.y, slots_per_chunk)
		&"right":
			return _slice_socket_profile(right_profile, local_chunk_offset.y, slots_per_chunk)
	return _solid_profile(slots_per_chunk)

func _slice_socket_profile(profile: Array[int], local_chunk_index: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	var start: int = local_chunk_index * slots_per_chunk
	for i: int in range(start, mini(start + slots_per_chunk, profile.size())):
		result.append(PieceSocket.from_value(profile[i]))
	while result.size() < slots_per_chunk:
		result.append(PieceSocket.SOLID)
	return result

func _solid_profile(slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	for i: int in range(slots_per_chunk):
		result.append(PieceSocket.SOLID)
	return result
