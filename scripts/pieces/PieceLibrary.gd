class_name PieceLibrary
extends Resource

@export var pieces: Array[Resource] = []
var pieces_by_id: Dictionary = {}

func prepare() -> void:
	pieces_by_id.clear()
	for resource: Resource in pieces:
		var piece: PieceDef = resource as PieceDef
		if piece != null:
			piece.prepare_image_cache()
			pieces_by_id[piece.id] = piece
	print("PieceLibrary loaded ", pieces_by_id.size(), " piece defs")
	if pieces_by_id.is_empty():
		push_error("PieceLibrary loaded 0 piece defs. Check res://resources/pieces/piece_library.tres and its PieceDef references.")

func load_from_default_dirs() -> void:
	pieces.clear()
	pieces_by_id.clear()
	_load_defs_recursive("res://resources/pieces/defs")
	_load_defs_recursive("res://resources/generated_pieces/defs")
	prepare()

func _load_defs_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("PieceLibrary could not open directory: " + path)
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		names.append(name)
	dir.list_dir_end()
	names.sort()
	for name: String in names:
		var child: String = path + "/" + name
		if DirAccess.dir_exists_absolute(child):
			_load_defs_recursive(child)
		elif name.ends_with(".tres") or name.ends_with(".res"):
			var res: Resource = ResourceLoader.load(child)
			var piece: PieceDef = res as PieceDef
			if piece != null:
				pieces.append(piece)

func candidates_for(biome_id: StringName, tags: Array[StringName], max_size_units: Vector2i) -> Array[PieceDef]:
	var result: Array[PieceDef] = []
	for resource: Resource in pieces:
		var piece: PieceDef = resource as PieceDef
		if piece == null:
			continue
		if piece.kind == PieceDef.PieceKind.GLUE:
			continue
		if not piece.allows_biome(biome_id):
			continue
		if piece.size_units.x > max_size_units.x or piece.size_units.y > max_size_units.y:
			continue
		var tag_match: bool = tags.is_empty()
		for tag: StringName in tags:
			if piece.has_tag(tag):
				tag_match = true
				break
		if tag_match:
			result.append(piece)
	return result

func weighted_pick(list: Array[PieceDef], rng: RandomNumberGenerator) -> PieceDef:
	if list.is_empty():
		return null
	var total: float = 0.0
	for piece: PieceDef in list:
		total += maxf(piece.weight, 0.001)
	var roll: float = rng.randf() * total
	for piece: PieceDef in list:
		roll -= maxf(piece.weight, 0.001)
		if roll <= 0.0:
			return piece
	return list.back()
