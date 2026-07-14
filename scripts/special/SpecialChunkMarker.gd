class_name SpecialChunkMarker
extends Marker2D

# Marker placed inside editable SpecialChunk scenes.
# Later systems can turn these into chests, enemies, portals, lights, etc.
enum MarkerKind {
	CHEST,
	ENEMY,
	WAND,
	POTION,
	PORTAL,
	LIGHT,
	NPC,
	ALTAR,
}

@export_enum("Chest", "Enemy", "Wand", "Potion", "Portal", "Light", "NPC", "Altar") var marker_kind: int = MarkerKind.CHEST
@export var id: StringName = &""
@export var tags: Array[StringName] = []
@export var spawn_weight: float = 1.0
