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
	print("Generated double-open-small test piece library. Reopen PieceWorld.tscn or press F3 to regenerate chunks.")

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
	issues += _validate_socket_names(piece)
	if piece.tags.has(&"generated"):
		issues += _validate_texture_openings(piece)
	return issues

func _validate_socket_names(piece: PieceDef) -> int:
	var issues: int = 0
	var all_slots: Array = []
	all_slots.append_array(piece.top_slots)
	all_slots.append_array(piece.right_slots)
	all_slots.append_array(piece.bottom_slots)
	all_slots.append_array(piece.left_slots)
	for socket_value in all_slots:
		var socket: int = PieceSocket.from_value(socket_value)
		if socket < PieceSocket.Socket.SOLID or socket > PieceSocket.Socket.ANY:
			push_warning("Unknown socket '%s' in piece %s" % [str(socket_value), str(piece.id)])
			issues += 1
	return issues

func _validate_texture_openings(piece: PieceDef) -> int:
	var issues: int = 0
	if piece.texture == null:
		return 0
	var img: Image = piece.texture.get_image()
	if img == null:
		return 0
	if img.get_size() != piece.size_px:
		push_warning("texture size does not match size_px: " + str(piece.id))
		issues += 1
	issues += _validate_edge_slots(piece.id, img, &"top", piece.top_slots)
	issues += _validate_edge_slots(piece.id, img, &"right", piece.right_slots)
	issues += _validate_edge_slots(piece.id, img, &"bottom", piece.bottom_slots)
	issues += _validate_edge_slots(piece.id, img, &"left", piece.left_slots)
	return issues

func _validate_edge_slots(piece_id: StringName, img: Image, edge: StringName, slots: Array[PieceSocket.Socket]) -> int:
	var issues: int = 0
	for i: int in range(slots.size()):
		var socket: PieceSocket.Socket = PieceSocket.from_value(slots[i])
		var expected: int = PieceSocket.opening_count(socket)
		var actual: int = _count_open_segments(img, edge, i)
		if expected != actual:
			push_warning("opening count mismatch in %s %s slot %d: socket=%s expected=%d actual=%d" % [str(piece_id), str(edge), i, str(PieceSocket.to_name(socket)), expected, actual])
			issues += 1
	return issues

func _count_open_segments(img: Image, edge: StringName, slot_index: int) -> int:
	var values: Array[bool] = []
	var scan_depth: int = 4
	for local: int in range(128):
		var open_pixel: bool = false
		match edge:
			&"right":
				var y: int = slot_index * 128 + local
				for dx: int in range(scan_depth):
					if _is_air(img, img.get_width() - 1 - dx, y): open_pixel = true
			&"left":
				var y2: int = slot_index * 128 + local
				for dx2: int in range(scan_depth):
					if _is_air(img, dx2, y2): open_pixel = true
			&"top":
				var x: int = slot_index * 128 + local
				for dy: int in range(scan_depth):
					if _is_air(img, x, dy): open_pixel = true
			&"bottom":
				var x2: int = slot_index * 128 + local
				for dy2: int in range(scan_depth):
					if _is_air(img, x2, img.get_height() - 1 - dy2): open_pixel = true
		values.append(open_pixel)
	var count: int = 0
	var in_segment: bool = false
	var segment_length: int = 0
	for value: bool in values:
		if value:
			segment_length += 1
			if not in_segment:
				in_segment = true
		else:
			if in_segment and segment_length >= 8:
				count += 1
			in_segment = false
			segment_length = 0
	if in_segment and segment_length >= 8:
		count += 1
	return count

func _is_air(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a < 0.10
