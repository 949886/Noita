class_name PieceChunkGenerator
extends RefCounted

const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

var world_seed: int = 12345
var library: PieceLibrary
var config: WorldGenConfig
var special_chunk_planner: SpecialChunkPlanner
var world_structure: WorldStructure
var biome_map: BiomeMap
var socket_profile_planner: SocketProfilePlanner
var seam_registry: WorldSeamRegistry

func _init(p_seed: int, p_library: PieceLibrary, p_config: WorldGenConfig = null, p_special_chunk_planner: SpecialChunkPlanner = null, p_world_structure: WorldStructure = null) -> void:
	world_seed = p_seed
	library = p_library
	config = p_config
	special_chunk_planner = p_special_chunk_planner
	world_structure = p_world_structure
	biome_map = BiomeMap.new(world_seed, config)
	biome_map.world_structure = world_structure
	biome_map.special_chunk_planner = special_chunk_planner
	socket_profile_planner = SocketProfilePlanner.new(world_seed, biome_map, special_chunk_planner)
	seam_registry = WorldSeamRegistry.new(socket_profile_planner)

func generate_chunk(coord: Vector2i, create_texture: bool = true) -> PieceChunkData:
	var data: PieceChunkData = PieceChunkData.new(coord)
	data.biome_id = biome_map.get_biome(coord)
	data.chunk_type = biome_map.get_chunk_type(coord)
	data.structure_tags = biome_map.get_structure_tags(coord)
	var structure_node: WorldStructureNode = biome_map.get_structure_node(coord)
	if structure_node != null:
		data.chamber_id = structure_node.chamber_id
		data.chamber_origin = structure_node.chamber_origin
		data.chamber_size = structure_node.chamber_size
		data.special_chunk_id = structure_node.special_chunk_id
		data.special_chunk_origin = structure_node.special_chunk_origin
		data.special_chunk_size = structure_node.special_chunk_size
		data.special_chunk_gateway_side = structure_node.special_chunk_gateway_side
	data.structure_source = "structure_v1" if world_structure != null and world_structure.has_node(coord) else "fallback"
	data.intended_connection_count = _count_intended_connections(coord)
	var profiles: Dictionary = seam_registry.get_profiles_for_chunk(coord) if seam_registry != null else socket_profile_planner.get_profiles_for_chunk(coord)
	data.top_profile = _profile_from_variant(profiles.get("top", []))
	data.bottom_profile = _profile_from_variant(profiles.get("bottom", []))
	data.left_profile = _profile_from_variant(profiles.get("left", []))
	data.right_profile = _profile_from_variant(profiles.get("right", []))
	var rng: RandomNumberGenerator = SeedUtil.rng_from_seed(SeedUtil.chunk_seed(world_seed, data.coord))
	var occupied: Array[bool] = []
	occupied.resize(UNITS_PER_CHUNK * UNITS_PER_CHUNK)
	for i: int in range(occupied.size()):
		occupied[i] = false
	data.visual_image = Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	data.visual_image.fill(Color.TRANSPARENT)
	data.material_image = Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	data.material_image.fill(Color.TRANSPARENT)
	_place_anchor_pieces(data, occupied, rng)
	_fill_with_regular_pieces(data, occupied, rng)
	_fill_glue(data, occupied, rng)
	_refresh_actual_profiles(data)
	_repair_boundary_sockets(data, rng)
	_refresh_actual_profiles(data)
	# Do not carve/seal authored piece pixels globally. Seam correctness is
	# enforced through exact socket selection plus localized generated glue repair.
	_recount_seam_status(data)
	if create_texture:
		data.texture = ImageTexture.create_from_image(data.visual_image)
	data.piece_count = data.placements.size()
	data.used_glue_count = _count_glue(data)
	data.regular_piece_count = maxi(0, data.piece_count - data.used_glue_count)
	data.fallback_tiles = data.used_glue_count
	data.exact_match_tiles = data.regular_piece_count
	data.compatible_match_tiles = _count_compatible_seams(data)
	data.open_side_count = _count_open_sides(data)
	data.connected_open_sides = data.open_side_count
	data.connectivity_adjusted = data.intended_connection_count > 0 or data.open_side_count > 0
	data.air_tile_count = _estimate_air_units(data)
	return data

func _profile_from_variant(value: Variant) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	if value is Array:
		for socket_value in value:
			result.append(PieceSocket.from_value(socket_value))
	while result.size() < UNITS_PER_CHUNK:
		result.append(PieceSocket.SOLID)
	if result.size() > UNITS_PER_CHUNK:
		result.resize(UNITS_PER_CHUNK)
	return result

func _place_anchor_pieces(data: PieceChunkData, occupied: Array[bool], rng: RandomNumberGenerator) -> void:
	var desired_tags: Array[StringName] = _desired_tags_for(data.chunk_type)
	var attempts: int = 4 if data.chunk_type != BiomeMap.ChunkType.SOLID else 1
	for i: int in range(attempts):
		var max_size: Vector2i = Vector2i(2, 2)
		var candidates: Array[PieceDef] = library.candidates_for(data.biome_id, desired_tags, max_size)
		if candidates.is_empty():
			return
		var best_piece: PieceDef = null
		var best_pos: Vector2i = Vector2i(-1, -1)
		var best_score: int = -999999
		for trial: int in range(40):
			var piece: PieceDef = library.weighted_pick(candidates, rng)
			if piece == null:
				continue
			var pos: Vector2i = _find_empty_spot(occupied, piece.size_units, rng)
			if pos.x < 0:
				continue
			var score: int = _placement_total_score(data, occupied, piece, pos, rng, true)
			if score < 0:
				continue
			if score > best_score:
				best_score = score
				best_piece = piece
				best_pos = pos
				if score >= 520:
					break
		if best_piece != null and best_pos.x >= 0:
			_add_piece(data, occupied, best_piece, best_pos, &"anchor")

func _fill_with_regular_pieces(data: PieceChunkData, occupied: Array[bool], rng: RandomNumberGenerator) -> void:
	var desired_tags: Array[StringName] = _desired_tags_for(data.chunk_type)
	var candidates: Array[PieceDef] = library.candidates_for(data.biome_id, desired_tags, Vector2i(2, 2))
	if candidates.is_empty():
		return
	var guard: int = UNITS_PER_CHUNK * UNITS_PER_CHUNK
	while guard > 0:
		guard -= 1
		var best: Dictionary = _find_best_regular_placement(data, occupied, candidates, rng)
		if best.is_empty():
			break
		var best_piece: PieceDef = best.get(&"piece", null) as PieceDef
		var best_pos: Vector2i = best.get(&"unit_pos", Vector2i(-1, -1))
		if best_piece == null:
			break
		_add_piece(data, occupied, best_piece, best_pos, &"regular")

func _find_best_regular_placement(data: PieceChunkData, occupied: Array[bool], candidates: Array[PieceDef], rng: RandomNumberGenerator) -> Dictionary:
	var best_score: int = -999999
	var best_piece: PieceDef = null
	var best_pos: Vector2i = Vector2i(-1, -1)
	for piece: PieceDef in candidates:
		if piece.kind == PieceDef.PieceKind.GLUE:
			continue
		for y: int in range(UNITS_PER_CHUNK - piece.size_units.y + 1):
			for x: int in range(UNITS_PER_CHUNK - piece.size_units.x + 1):
				var pos: Vector2i = Vector2i(x, y)
				if not _fits_empty_area(occupied, pos, piece.size_units):
					continue
				var score: int = _placement_total_score(data, occupied, piece, pos, rng, false)
				if score < 0:
					continue
				if score > best_score:
					best_score = score
					best_piece = piece
					best_pos = pos
	if best_piece == null:
		return {}
	return {&"piece": best_piece, &"unit_pos": best_pos, &"score": best_score}

func _placement_total_score(data: PieceChunkData, occupied: Array[bool], piece: PieceDef, unit_pos: Vector2i, rng: RandomNumberGenerator, anchor_mode: bool) -> int:
	var match_score: int = _placement_match_score(data, occupied, piece, unit_pos)
	if match_score < 0:
		return -1
	var score: int = match_score
	var area: int = piece.size_units.x * piece.size_units.y
	if area > 1:
		score += 90
	match piece.kind:
		PieceDef.PieceKind.ROOM:
			score += 28
		PieceDef.PieceKind.STRUCTURE:
			score += 24
		PieceDef.PieceKind.SPECIAL:
			score += 20
		PieceDef.PieceKind.CAVE:
			score += 8
		_:
			score += 0
	for tag: StringName in _desired_tags_for(data.chunk_type):
		if piece.has_tag(tag):
			score += 12
	if anchor_mode:
		score += 18
	score += rng.randi_range(0, 7)
	return score

func _desired_tags_for(chunk_type: int) -> Array[StringName]:
	var result: Array[StringName] = []
	match chunk_type:
		BiomeMap.ChunkType.CHAMBER:
			result = [&"room", &"cave_room", &"symbol"]
		BiomeMap.ChunkType.MAIN_PATH:
			result = [&"room", &"lab", &"horizontal", &"cave_room"]
		BiomeMap.ChunkType.BRANCH:
			result = [&"tank", &"vertical", &"room", &"cave_room"]
		BiomeMap.ChunkType.SOLID:
			result = [&"cave_room"]
		_:
			result = [&"cave_room", &"room"]
	return result

func _find_empty_spot(occupied: Array[bool], size_units: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var possible: Array[Vector2i] = []
	for y: int in range(UNITS_PER_CHUNK - size_units.y + 1):
		for x: int in range(UNITS_PER_CHUNK - size_units.x + 1):
			var pos: Vector2i = Vector2i(x, y)
			if _fits_empty_area(occupied, pos, size_units):
				possible.append(pos)
	if possible.is_empty():
		return Vector2i(-1, -1)
	return possible[rng.randi_range(0, possible.size() - 1)]

func _fits_empty_area(occupied: Array[bool], unit_pos: Vector2i, size_units: Vector2i) -> bool:
	if unit_pos.x < 0 or unit_pos.y < 0:
		return false
	if unit_pos.x + size_units.x > UNITS_PER_CHUNK:
		return false
	if unit_pos.y + size_units.y > UNITS_PER_CHUNK:
		return false
	for yy: int in range(size_units.y):
		for xx: int in range(size_units.x):
			if occupied[(unit_pos.y + yy) * UNITS_PER_CHUNK + (unit_pos.x + xx)]:
				return false
	return true

func _placement_match_score(data: PieceChunkData, occupied: Array[bool], piece: PieceDef, unit_pos: Vector2i) -> int:
	var total: int = 0
	var checked: int = 0
	for y: int in range(piece.size_units.y):
		for x: int in range(piece.size_units.x):
			var cell: Vector2i = unit_pos + Vector2i(x, y)
			for side: StringName in [&"top", &"right", &"bottom", &"left"]:
				if not _is_outer_piece_side(piece, Vector2i(x, y), side):
					continue
				var socket_a: PieceSocket.Socket = _piece_socket_for_local_side(piece, Vector2i(x, y), side)
				var neighbor_pos: Vector2i = cell + _side_dir(side)
				if not _unit_in_chunk(neighbor_pos):
					var seam_socket: PieceSocket.Socket = _boundary_socket(data, cell, side)
					# Chunk borders are exact hard constraints from WorldSeamRegistry.
					# Compatibility remains allowed only inside a chunk.
					if socket_a != seam_socket:
						return -1
					total += 120
					checked += 1
					continue
				if not occupied[neighbor_pos.y * UNITS_PER_CHUNK + neighbor_pos.x]:
					continue
				var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
				if neighbor == null:
					continue
				var socket_b: PieceSocket.Socket = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
				var score: int = PieceSocket.compatibility_score(socket_a, socket_b)
				if score < 60:
					return -1
				total += score
				checked += 1
	if checked == 0:
		return 10
	return total

func _unit_in_chunk(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < UNITS_PER_CHUNK and pos.y < UNITS_PER_CHUNK

func _side_dir(side: StringName) -> Vector2i:
	match side:
		&"top":
			return Vector2i(0, -1)
		&"right":
			return Vector2i(1, 0)
		&"bottom":
			return Vector2i(0, 1)
		&"left":
			return Vector2i(-1, 0)
	return Vector2i.ZERO

func _opposite_side(side: StringName) -> StringName:
	match side:
		&"top":
			return &"bottom"
		&"right":
			return &"left"
		&"bottom":
			return &"top"
		&"left":
			return &"right"
	return &""

func _is_outer_piece_side(piece: PieceDef, local: Vector2i, side: StringName) -> bool:
	match side:
		&"top":
			return local.y == 0
		&"right":
			return local.x == piece.size_units.x - 1
		&"bottom":
			return local.y == piece.size_units.y - 1
		&"left":
			return local.x == 0
	return false

func _piece_socket_for_local_side(piece: PieceDef, local: Vector2i, side: StringName) -> PieceSocket.Socket:
	var slots: Array[PieceSocket.Socket] = piece.normalized_slots(side)
	var slot_index: int = local.x if (side == &"top" or side == &"bottom") else local.y
	if slot_index >= 0 and slot_index < slots.size():
		return PieceSocket.from_value(slots[slot_index])
	return PieceSocket.SOLID

func _placement_at_unit(data: PieceChunkData, unit: Vector2i) -> PiecePlacement:
	return data.placement_at_unit(unit)

func _placement_socket_for_unit_side(placement: PiecePlacement, unit: Vector2i, side: StringName) -> PieceSocket.Socket:
	if placement.is_glue:
		return PieceSocket.from_value(placement.sockets.get(side, PieceSocket.SOLID))
	if placement.piece_def == null:
		return PieceSocket.SOLID
	var local: Vector2i = unit - placement.unit_pos
	if not _is_outer_piece_side(placement.piece_def, local, side):
		return PieceSocket.SOLID
	return _piece_socket_for_local_side(placement.piece_def, local, side)

func _add_piece(data: PieceChunkData, occupied: Array[bool], piece: PieceDef, unit_pos: Vector2i, phase: StringName = &"regular") -> void:
	var placement: PiecePlacement = PiecePlacement.new()
	placement.piece_def = piece
	placement.id = piece.id
	placement.unit_pos = unit_pos
	placement.size_units = piece.size_units
	placement.is_glue = false
	placement.phase = phase
	placement.sequence_index = data.placements.size()
	data.placements.append(placement)
	for y: int in range(piece.size_units.y):
		for x: int in range(piece.size_units.x):
			occupied[(unit_pos.y + y) * UNITS_PER_CHUNK + (unit_pos.x + x)] = true
	_paste_piece_image(data.visual_image, piece.cached_visual_image, piece.texture, dst_rect_for_piece(placement))
	_paste_piece_image(data.material_image, piece.cached_material_image, piece.material_texture if piece.material_texture != null else piece.texture, dst_rect_for_piece(placement))

func dst_rect_for_piece(placement: PiecePlacement) -> Rect2i:
	return placement.pixel_rect(UNIT_SIZE)

func _paste_piece_image(target: Image, cached_img: Image, fallback_tex: Texture2D, dst_rect: Rect2i) -> void:
	var img: Image = cached_img
	if img == null or img.is_empty():
		# This fallback should only be reached when a library was not prepared. It is
		# kept for editor/demo resilience, but runtime threaded generation prepares all
		# images on the main thread before workers start.
		if fallback_tex == null:
			return
		img = fallback_tex.get_image()
		if img == null or img.is_empty():
			return
		img = img.duplicate()
		if img.is_compressed():
			var err: Error = img.decompress()
			if err != OK:
				push_warning("Could not decompress piece texture image before blit.")
				return
		if img.get_format() != target.get_format():
			img.convert(target.get_format())
		if img.get_size() != dst_rect.size:
			img.resize(dst_rect.size.x, dst_rect.size.y, Image.INTERPOLATE_NEAREST)
	if img.get_format() != target.get_format():
		# Do not mutate the cached image when it is already shared by worker jobs. The
		# prepared cache uses target format, so this branch is normally unreachable.
		img = img.duplicate()
		img.convert(target.get_format())
	target.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), dst_rect.position)


func _repair_boundary_sockets(data: PieceChunkData, rng: RandomNumberGenerator) -> void:
	# Long-term seam correctness rule: a chunk edge must expose exactly the
	# canonical WorldSeamRegistry socket. Repair is non-destructive: only empty or
	# generated-glue boundary units may be replaced. Authored prefab pieces are
	# reported as seam issues but are never carved or overwritten here.
	var repair_units: Dictionary = {}
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		for slot: int in range(UNITS_PER_CHUNK):
			var unit_pos: Vector2i = _boundary_unit_for_slot(side, slot)
			var expected: PieceSocket.Socket = _boundary_socket(data, unit_pos, side)
			var actual: PieceSocket.Socket = _actual_boundary_socket(data, unit_pos, side)
			if actual != expected:
				data.seam_issue_count += 1
				var placement: PiecePlacement = _placement_at_unit(data, unit_pos)
				var can_repair_non_destructively: bool = placement == null or placement.is_glue
				data.seam_repairs.append({
					"unit": unit_pos,
					"side": side,
					"slot": slot,
					"expected": PieceSocket.to_name(expected),
					"actual_before": PieceSocket.to_name(actual),
					"repair_mode": &"generated_glue" if can_repair_non_destructively else &"authored_piece_not_modified",
				})
				if can_repair_non_destructively:
					repair_units[unit_pos] = true
	for unit_value in repair_units.keys():
		var unit_pos: Vector2i = unit_value
		_add_seam_repair_glue(data, unit_pos, rng)

func _add_seam_repair_glue(data: PieceChunkData, unit_pos: Vector2i, rng: RandomNumberGenerator) -> void:
	var sockets: Dictionary = _repair_glue_sockets_for(data, unit_pos, rng)
	var top_socket: PieceSocket.Socket = PieceSocket.from_value(sockets.get(&"top", PieceSocket.SOLID))
	var right_socket: PieceSocket.Socket = PieceSocket.from_value(sockets.get(&"right", PieceSocket.SOLID))
	var bottom_socket: PieceSocket.Socket = PieceSocket.from_value(sockets.get(&"bottom", PieceSocket.SOLID))
	var left_socket: PieceSocket.Socket = PieceSocket.from_value(sockets.get(&"left", PieceSocket.SOLID))
	var seed_value: int = int(_chunk_seed(data.coord) + unit_pos.x * 1009 + unit_pos.y * 9173 + 531441)
	var glue: Image = GluePieceGenerator.generate(data.biome_id, top_socket, right_socket, bottom_socket, left_socket, seed_value)
	var rect: Rect2i = Rect2i(unit_pos * UNIT_SIZE, Vector2i.ONE * UNIT_SIZE)
	data.visual_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
	data.material_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
	var placement: PiecePlacement = PiecePlacement.new()
	placement.id = &"seam_repair_glue"
	placement.unit_pos = unit_pos
	placement.size_units = Vector2i.ONE
	placement.is_glue = true
	placement.phase = &"seam_repair"
	placement.sequence_index = data.placements.size()
	placement.generated_image = glue
	placement.sockets = sockets
	data.placements.append(placement)
	data.used_glue_count += 1
	data.seam_repair_count += 1

func _repair_glue_sockets_for(data: PieceChunkData, pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var sockets: Dictionary = {}
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		var neighbor_pos: Vector2i = pos + _side_dir(side)
		if not _unit_in_chunk(neighbor_pos):
			# Boundary sides are exact hard constraints from the canonical seam.
			sockets[side] = _boundary_socket(data, pos, side)
		else:
			var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
			if neighbor != null:
				sockets[side] = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
			else:
				sockets[side] = _procedural_socket(data.coord, pos, side, _open_chance_for(data.chunk_type), rng)
	return sockets

func _refresh_actual_profiles(data: PieceChunkData) -> void:
	var top: Array[PieceSocket.Socket] = []
	var right: Array[PieceSocket.Socket] = []
	var bottom: Array[PieceSocket.Socket] = []
	var left: Array[PieceSocket.Socket] = []
	for slot: int in range(UNITS_PER_CHUNK):
		top.append(_actual_boundary_socket(data, Vector2i(slot, 0), &"top"))
		right.append(_actual_boundary_socket(data, Vector2i(UNITS_PER_CHUNK - 1, slot), &"right"))
		bottom.append(_actual_boundary_socket(data, Vector2i(slot, UNITS_PER_CHUNK - 1), &"bottom"))
		left.append(_actual_boundary_socket(data, Vector2i(0, slot), &"left"))
	data.actual_top_profile = top
	data.actual_right_profile = right
	data.actual_bottom_profile = bottom
	data.actual_left_profile = left

func _actual_boundary_socket(data: PieceChunkData, unit_pos: Vector2i, side: StringName) -> PieceSocket.Socket:
	var placement: PiecePlacement = _placement_at_unit(data, unit_pos)
	if placement == null:
		return PieceSocket.SOLID
	return _placement_socket_for_unit_side(placement, unit_pos, side)

func _boundary_unit_for_slot(side: StringName, slot: int) -> Vector2i:
	match side:
		&"top":
			return Vector2i(slot, 0)
		&"right":
			return Vector2i(UNITS_PER_CHUNK - 1, slot)
		&"bottom":
			return Vector2i(slot, UNITS_PER_CHUNK - 1)
		&"left":
			return Vector2i(0, slot)
	return Vector2i.ZERO

func _recount_seam_status(data: PieceChunkData) -> void:
	data.seam_exact_count = 0
	data.seam_compatible_count = 0
	data.seam_broken_count = 0
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		var expected_profile: Array[PieceSocket.Socket] = data.profile_for_side(side, false)
		var actual_profile: Array[PieceSocket.Socket] = data.profile_for_side(side, true)
		for slot: int in range(UNITS_PER_CHUNK):
			var expected: PieceSocket.Socket = PieceSocket.from_value(expected_profile[slot] if slot < expected_profile.size() else PieceSocket.SOLID)
			var actual: PieceSocket.Socket = PieceSocket.from_value(actual_profile[slot] if slot < actual_profile.size() else PieceSocket.SOLID)
			if actual == expected:
				data.seam_exact_count += 1
			elif PieceSocket.compatible(actual, expected):
				data.seam_compatible_count += 1
			else:
				data.seam_broken_count += 1




func _fill_glue(data: PieceChunkData, occupied: Array[bool], rng: RandomNumberGenerator) -> void:
	for y: int in range(UNITS_PER_CHUNK):
		for x: int in range(UNITS_PER_CHUNK):
			if occupied[y * UNITS_PER_CHUNK + x]:
				continue
			var sockets: Dictionary = _glue_sockets_for(data, Vector2i(x, y), rng)
			var top_socket: PieceSocket.Socket = PieceSocket.from_value(sockets[&"top"])
			var right_socket: PieceSocket.Socket = PieceSocket.from_value(sockets[&"right"])
			var bottom_socket: PieceSocket.Socket = PieceSocket.from_value(sockets[&"bottom"])
			var left_socket: PieceSocket.Socket = PieceSocket.from_value(sockets[&"left"])
			var glue: Image = GluePieceGenerator.generate(data.biome_id, top_socket, right_socket, bottom_socket, left_socket, int(_chunk_seed(data.coord) + x * 77 + y * 313))
			var rect: Rect2i = Rect2i(Vector2i(x, y) * UNIT_SIZE, Vector2i.ONE * UNIT_SIZE)
			data.visual_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
			data.material_image.blit_rect(glue, Rect2i(Vector2i.ZERO, glue.get_size()), rect.position)
			var placement: PiecePlacement = PiecePlacement.new()
			placement.id = &"generated_glue"
			placement.unit_pos = Vector2i(x, y)
			placement.size_units = Vector2i.ONE
			placement.is_glue = true
			placement.phase = &"glue"
			placement.sequence_index = data.placements.size()
			placement.generated_image = glue
			placement.sockets = sockets
			data.placements.append(placement)
			data.used_glue_count += 1
			occupied[y * UNITS_PER_CHUNK + x] = true

func _glue_sockets_for(data: PieceChunkData, pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = {}
	var fixed: Dictionary = {}
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		var neighbor_pos: Vector2i = pos + _side_dir(side)
		var socket: PieceSocket.Socket = PieceSocket.SOLID
		var is_fixed: bool = false
		if _unit_in_chunk(neighbor_pos):
			var neighbor: PiecePlacement = _placement_at_unit(data, neighbor_pos)
			if neighbor != null:
				socket = _placement_socket_for_unit_side(neighbor, neighbor_pos, _opposite_side(side))
				is_fixed = true
			else:
				socket = _procedural_socket(data.coord, pos, side, _open_chance_for(data.chunk_type), rng)
		else:
			# Boundary sockets are fixed by WorldSeamRegistry and must never be
			# normalized away by glue-shape cleanup.
			socket = _boundary_socket(data, pos, side)
			is_fixed = true
		d[side] = socket
		fixed[side] = is_fixed
	_normalize_glue_socket_mix(d, fixed)
	return d

func _normalize_glue_socket_mix(sockets: Dictionary, fixed: Dictionary) -> void:
	var has_double: bool = false
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		if PieceSocket.from_value(sockets.get(side, PieceSocket.SOLID)) == PieceSocket.DOUBLE_OPEN_SMALL:
			has_double = true
			break
	if not has_double:
		return
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		var socket: PieceSocket.Socket = PieceSocket.from_value(sockets.get(side, PieceSocket.SOLID))
		var is_fixed: bool = bool(fixed.get(side, false))
		if not is_fixed and PieceSocket.is_open_family(socket) and socket != PieceSocket.DOUBLE_OPEN_SMALL:
			sockets[side] = PieceSocket.SOLID

func _boundary_socket(data: PieceChunkData, unit_pos: Vector2i, side: StringName) -> PieceSocket.Socket:
	var profile: Array[PieceSocket.Socket] = []
	var slot_index: int = 0
	match side:
		&"top":
			profile = data.top_profile
			slot_index = unit_pos.x
		&"right":
			profile = data.right_profile
			slot_index = unit_pos.y
		&"bottom":
			profile = data.bottom_profile
			slot_index = unit_pos.x
		&"left":
			profile = data.left_profile
			slot_index = unit_pos.y
	if slot_index >= 0 and slot_index < profile.size():
		return PieceSocket.from_value(profile[slot_index])
	return PieceSocket.SOLID

func _procedural_socket(chunk_coord: Vector2i, unit_pos: Vector2i, side: StringName, chance: float, rng: RandomNumberGenerator) -> PieceSocket.Socket:
	var global_cell: Vector2i = chunk_coord * UNITS_PER_CHUNK + unit_pos
	var salt: int = int(global_cell.x * 19349663 + global_cell.y * 83492791 + world_seed + _side_salt(side))
	var v: float = float(abs(salt % 10000)) / 10000.0
	# Blend deterministic edge noise with the chunk RNG so unresolved glue is varied but stable per chunk.
	v = (v * 0.75) + (rng.randf() * 0.25)
	if v < chance * 0.20:
		return PieceSocket.OPEN_LARGE
	if v < chance * 0.52:
		return PieceSocket.OPEN_MEDIUM
	if v < chance * 0.76:
		return PieceSocket.DOUBLE_OPEN_SMALL
	if v < chance:
		return PieceSocket.OPEN_SMALL
	return PieceSocket.SOLID

func _side_salt(side: StringName) -> int:
	match side:
		&"top":
			return 101
		&"right":
			return 211
		&"bottom":
			return 307
		&"left":
			return 419
	return 0

func _open_chance_for(chunk_type: int) -> float:
	if biome_map != null:
		return biome_map.openness_for_chunk_type(chunk_type)
	match chunk_type:
		BiomeMap.ChunkType.MAIN_PATH:
			return 0.72
		BiomeMap.ChunkType.CHAMBER:
			return 0.62
		BiomeMap.ChunkType.BRANCH:
			return 0.52
		BiomeMap.ChunkType.SOLID:
			return 0.18
		_:
			return 0.38

func _count_intended_connections(coord: Vector2i) -> int:
	if world_structure == null:
		return 0
	var node: WorldStructureNode = world_structure.get_node(coord)
	if node == null:
		return 0
	var count: int = 0
	for side: StringName in [&"top", &"right", &"bottom", &"left"]:
		if node.has_connection(side):
			count += 1
	return count

func _count_open_sides(data: PieceChunkData) -> int:
	var count: int = 0
	if _profile_has_open(data.top_profile):
		count += 1
	if _profile_has_open(data.right_profile):
		count += 1
	if _profile_has_open(data.bottom_profile):
		count += 1
	if _profile_has_open(data.left_profile):
		count += 1
	return count

func _profile_has_open(profile: Array[PieceSocket.Socket]) -> bool:
	for socket: PieceSocket.Socket in profile:
		if PieceSocket.is_open(socket):
			return true
	return false

func _count_glue(data: PieceChunkData) -> int:
	var count: int = 0
	for placement: PiecePlacement in data.placements:
		if placement.is_glue:
			count += 1
	return count

func _count_compatible_seams(data: PieceChunkData) -> int:
	var count: int = 0
	for placement: PiecePlacement in data.placements:
		for side: StringName in [&"top", &"right", &"bottom", &"left"]:
			if placement.is_glue:
				if PieceSocket.is_open(PieceSocket.from_value(placement.sockets.get(side, PieceSocket.SOLID))):
					count += 1
			elif placement.piece_def != null:
				for socket: PieceSocket.Socket in placement.piece_def.normalized_slots(side):
					if PieceSocket.is_open(socket):
						count += 1
	return count

func _estimate_air_units(data: PieceChunkData) -> int:
	var count: int = 0
	for placement: PiecePlacement in data.placements:
		if placement.is_glue:
			for side: StringName in [&"top", &"right", &"bottom", &"left"]:
				if PieceSocket.is_open(PieceSocket.from_value(placement.sockets.get(side, PieceSocket.SOLID))):
					count += 1
		elif placement.piece_def != null:
			if placement.piece_def.has_tag(&"room") or placement.piece_def.has_tag(&"cave_room"):
				count += placement.size_units.x * placement.size_units.y
	return count

func _chunk_seed(coord: Vector2i) -> int:
	return int(world_seed + coord.x * 73856093 + coord.y * 19349663)
