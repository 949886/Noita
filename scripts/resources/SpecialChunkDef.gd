class_name SpecialChunkDef
extends Resource

# Metadata for a hand-authored chunk-sized structure.
# The PackedScene contains the visible content; this Resource tells the world generator
# where the structure may appear and which edge profiles neighboring Wang chunks must match.
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

# TransitionStyle selects which column family in the special_chunk transition rows
# should be used for this authored chunk. Direction comes from the edge being filled.
enum TransitionStyle {
	ROCK,
	SNOW,
	DEEP,
	RUINS,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("Treasure", "Shop", "Altar", "Portal", "Boss Entrance", "Puzzle", "Hall", "Shrine", "Decorative") var chunk_kind: int = ChunkKind.DECORATIVE
@export var scene: PackedScene
@export var allowed_biomes: Array[StringName] = []
@export var tags: Array[StringName] = []
# Structure-aware placement controls. These are soft rules used by SpecialChunkPlanner
# to place authored chunks at branch ends, chamber edges, or other macro-structure nodes.
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
@export var auto_fill_transition_border: bool = true

# External profiles are measured in tile edges, not pixels.
# For a 2x1 chunk, top_profile and bottom_profile have 16 entries; left/right have 8.
@export var top_profile: Array[int] = []
@export var right_profile: Array[int] = []
@export var bottom_profile: Array[int] = []
@export var left_profile: Array[int] = []

func profile_length_top_bottom(tiles_per_chunk: int) -> int:
	return size_in_chunks.x * tiles_per_chunk

func profile_length_left_right(tiles_per_chunk: int) -> int:
	return size_in_chunks.y * tiles_per_chunk

func validate_profiles(tiles_per_chunk: int) -> bool:
	return top_profile.size() == profile_length_top_bottom(tiles_per_chunk) \
		and bottom_profile.size() == profile_length_top_bottom(tiles_per_chunk) \
		and left_profile.size() == profile_length_left_right(tiles_per_chunk) \
		and right_profile.size() == profile_length_left_right(tiles_per_chunk)
