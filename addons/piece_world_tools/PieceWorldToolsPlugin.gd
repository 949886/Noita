@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_tool_menu_item("Generate Test Piece Library", Callable(self, "_generate_test_piece_library"))
	add_tool_menu_item("Validate Piece Library", Callable(self, "_validate_piece_library"))

func _exit_tree() -> void:
	remove_tool_menu_item("Generate Test Piece Library")
	remove_tool_menu_item("Validate Piece Library")

func _generate_test_piece_library() -> void:
	var gen_script: Script = load("res://addons/piece_world_tools/PieceTextureGenerator.gd")
	if gen_script == null:
		push_error("PieceTextureGenerator.gd not found")
		return
	var generator: Object = gen_script.new()
	generator.generate_default_library()
	EditorInterface.get_resource_filesystem().scan()
	print("Generated slot-correct test piece library. Reopen PieceWorld.tscn or press F3 to regenerate chunks.")

func _validate_piece_library() -> void:
	var errors: int = 0
	errors += _validate_dir("res://resources/generated_pieces/defs")
	errors += _validate_dir("res://resources/pieces/defs")
	if errors == 0:
		print("Piece library validation passed.")
	else:
		push_warning("Piece library validation finished with %d issue(s)." % errors)

func _validate_dir(path: String) -> int:
	var issues: int = 0
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var child: String = path + "/" + name
		if dir.current_is_dir():
			issues += _validate_dir(child)
		elif name.ends_with(".tres") or name.ends_with(".res"):
			issues += _validate_piece(child)
	dir.list_dir_end()
	return issues

func _validate_piece(path: String) -> int:
	var issues: int = 0
	var res: Resource = ResourceLoader.load(path)
	var piece: PieceDef = res as PieceDef
	if piece == null:
		push_warning("Not a PieceDef: " + path)
		return 1
	if piece.texture == null:
		push_warning("Piece has no texture: " + str(piece.id))
		return 1
	if piece.size_units.x <= 0 or piece.size_units.y <= 0:
		push_warning("Invalid size_units: " + str(piece.id))
		issues += 1
	if piece.size_px != piece.size_units * 128:
		push_warning("size_px does not match size_units*128: " + str(piece.id))
		issues += 1
	if piece.top_slots.size() != piece.size_units.x:
		push_warning("top_slots count mismatch: " + str(piece.id))
		issues += 1
	if piece.bottom_slots.size() != piece.size_units.x:
		push_warning("bottom_slots count mismatch: " + str(piece.id))
		issues += 1
	if piece.left_slots.size() != piece.size_units.y:
		push_warning("left_slots count mismatch: " + str(piece.id))
		issues += 1
	if piece.right_slots.size() != piece.size_units.y:
		push_warning("right_slots count mismatch: " + str(piece.id))
		issues += 1
	return issues
