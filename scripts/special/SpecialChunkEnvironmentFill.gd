class_name SpecialChunkEnvironmentFill
extends RefCounted

# Fills empty cells inside an authored SpecialChunk with ordinary biome Wang tiles.
# v2 uses an edge-map instead of treating every empty neighbor as OPEN. This makes
# the generated fill look like normal cave terrain instead of a grid of OOOO cells.
#
# Hard constraints come from:
# - SpecialChunk external profiles
# - authored Ground tiles and their edge metadata
# - FillTerminal markers that request a reachable route through the filled terrain
#
# The pass never overwrites authored Ground cells.
const EMPTY: int = 0
const AUTHORED: int = 1
const EDGE_UNKNOWN: int = -1
const COMMON_SOURCE_ID: int = TileConstants.SOURCE_COMMON

static func fill_empty_cells(
	ground: TileMapLayer,
	chunk_def: SpecialChunkDef,
	placement: SpecialChunkPlacement
) -> int:
	if ground == null or chunk_def == null or placement == null:
		return 0
	var size_tiles: Vector2i = chunk_def.size_in_chunks * TileConstants.TILES_PER_CHUNK
	if size_tiles.x <= 0 or size_tiles.y <= 0:
		return 0

	# Build a stable authored/empty mask first so fill result does not depend on scan order.
	var mask: Array = _build_mask(ground, size_tiles)
	var horizontal_edges: Array = _make_edge_grid(size_tiles.y + 1, size_tiles.x, EDGE_UNKNOWN)
	var vertical_edges: Array = _make_edge_grid(size_tiles.y, size_tiles.x + 1, EDGE_UNKNOWN)

	_apply_external_profiles(horizontal_edges, vertical_edges, size_tiles, chunk_def)
	_apply_authored_tile_constraints(ground, mask, horizontal_edges, vertical_edges, size_tiles)
	_fill_unknown_edges(horizontal_edges, vertical_edges, size_tiles, placement)

	# Connectivity terminals make authored doors/targets and external entrances reachable.
	# They open only the required path edges, rather than turning whole cells into OOOO.
	var terminals: Array[Vector2i] = _collect_terminals(ground, mask, size_tiles, chunk_def)
	_open_terminal_network(horizontal_edges, vertical_edges, terminals, size_tiles, placement)

	var biome_source_id: int = TileConstants.source_id_for_biome(placement.biome_id)
	var filled: int = 0
	for y: int in range(size_tiles.y):
		for x: int in range(size_tiles.x):
			if int(mask[y][x]) != EMPTY:
				continue
			var signature: String = _signature_from_edges(horizontal_edges, vertical_edges, Vector2i(x, y))
			var row_index: int = TileConstants.signature_order().find(signature)
			if row_index < 0:
				row_index = TileConstants.base_signature_order().find("OOOO")
				if row_index < 0:
					row_index = 15
			var variant: int = _variant_for(Vector2i(x, y), placement)
			ground.set_cell(Vector2i(x, y), biome_source_id, Vector2i(variant, row_index), 0)
			filled += 1
	return filled

static func _build_mask(ground: TileMapLayer, size_tiles: Vector2i) -> Array:
	var mask: Array = []
	for y: int in range(size_tiles.y):
		var row: Array[int] = []
		for x: int in range(size_tiles.x):
			var cell := Vector2i(x, y)
			row.append(AUTHORED if ground.get_cell_source_id(cell) != -1 else EMPTY)
		mask.append(row)
	return mask

static func _make_edge_grid(rows: int, columns: int, value: int) -> Array:
	var grid: Array = []
	for _y: int in range(rows):
		var row: Array[int] = []
		for _x: int in range(columns):
			row.append(value)
		grid.append(row)
	return grid

static func _apply_external_profiles(horizontal_edges: Array, vertical_edges: Array, size_tiles: Vector2i, chunk_def: SpecialChunkDef) -> void:
	for x: int in range(size_tiles.x):
		_set_horizontal_edge(horizontal_edges, x, 0, _profile_edge(chunk_def.top_profile, x))
		_set_horizontal_edge(horizontal_edges, x, size_tiles.y, _profile_edge(chunk_def.bottom_profile, x))
	for y: int in range(size_tiles.y):
		_set_vertical_edge(vertical_edges, 0, y, _profile_edge(chunk_def.left_profile, y))
		_set_vertical_edge(vertical_edges, size_tiles.x, y, _profile_edge(chunk_def.right_profile, y))

static func _apply_authored_tile_constraints(ground: TileMapLayer, mask: Array, horizontal_edges: Array, vertical_edges: Array, size_tiles: Vector2i) -> void:
	for y: int in range(size_tiles.y):
		for x: int in range(size_tiles.x):
			if int(mask[y][x]) != AUTHORED:
				continue
			var cell := Vector2i(x, y)
			var source_id: int = ground.get_cell_source_id(cell)
			var atlas_coords: Vector2i = ground.get_cell_atlas_coords(cell)
			var edges: Array[int] = _edges_for_atlas_tile(source_id, atlas_coords)
			_set_horizontal_edge(horizontal_edges, x, y, _to_so_edge(edges[0]))
			_set_vertical_edge(vertical_edges, x + 1, y, _to_so_edge(edges[1]))
			_set_horizontal_edge(horizontal_edges, x, y + 1, _to_so_edge(edges[2]))
			_set_vertical_edge(vertical_edges, x, y, _to_so_edge(edges[3]))

static func _fill_unknown_edges(horizontal_edges: Array, vertical_edges: Array, size_tiles: Vector2i, placement: SpecialChunkPlacement) -> void:
	var open_chance: float = _base_open_chance(placement.biome_id)
	for y: int in range(size_tiles.y + 1):
		for x: int in range(size_tiles.x):
			if int(horizontal_edges[y][x]) == EDGE_UNKNOWN:
				horizontal_edges[y][x] = _random_edge_for(x, y, 0, open_chance, placement)
	for y: int in range(size_tiles.y):
		for x: int in range(size_tiles.x + 1):
			if int(vertical_edges[y][x]) == EDGE_UNKNOWN:
				vertical_edges[y][x] = _random_edge_for(x, y, 1, open_chance, placement)

static func _base_open_chance(biome_id: StringName) -> float:
	match biome_id:
		&"mine": return 0.52
		&"snow": return 0.62
		&"deep": return 0.46
		_: return 0.54

static func _random_edge_for(x: int, y: int, orientation: int, open_chance: float, placement: SpecialChunkPlacement) -> int:
	var raw: int = hash("edge_%d_%d_%d_%d_%d_%d" % [x, y, orientation, placement.origin_chunk.x, placement.origin_chunk.y, placement.seed])
	var normalized: float = float(absi(raw) % 10000) / 10000.0
	return TileDef.Edge.OPEN if normalized < open_chance else TileDef.Edge.SOLID

static func _collect_terminals(ground: TileMapLayer, mask: Array, size_tiles: Vector2i, chunk_def: SpecialChunkDef) -> Array[Vector2i]:
	var terminals: Array[Vector2i] = []
	_collect_boundary_terminals(terminals, mask, size_tiles, chunk_def)
	_collect_marker_terminals(terminals, ground, mask, size_tiles)
	return _deduplicate_cells(terminals)

static func _collect_boundary_terminals(terminals: Array[Vector2i], mask: Array, size_tiles: Vector2i, chunk_def: SpecialChunkDef) -> void:
	for x: int in range(size_tiles.x):
		if _profile_edge(chunk_def.top_profile, x) == TileDef.Edge.OPEN:
			_add_terminal_near_boundary(terminals, mask, Vector2i(x, 0), Vector2i(0, 1), size_tiles)
		if _profile_edge(chunk_def.bottom_profile, x) == TileDef.Edge.OPEN:
			_add_terminal_near_boundary(terminals, mask, Vector2i(x, size_tiles.y - 1), Vector2i(0, -1), size_tiles)
	for y: int in range(size_tiles.y):
		if _profile_edge(chunk_def.left_profile, y) == TileDef.Edge.OPEN:
			_add_terminal_near_boundary(terminals, mask, Vector2i(0, y), Vector2i(1, 0), size_tiles)
		if _profile_edge(chunk_def.right_profile, y) == TileDef.Edge.OPEN:
			_add_terminal_near_boundary(terminals, mask, Vector2i(size_tiles.x - 1, y), Vector2i(-1, 0), size_tiles)

static func _add_terminal_near_boundary(terminals: Array[Vector2i], mask: Array, start: Vector2i, inward: Vector2i, size_tiles: Vector2i) -> void:
	var pos: Vector2i = start
	for _i: int in range(3):
		if _in_bounds(pos, size_tiles) and int(mask[pos.y][pos.x]) == EMPTY:
			terminals.append(pos)
			return
		pos += inward

static func _collect_marker_terminals(terminals: Array[Vector2i], ground: TileMapLayer, mask: Array, size_tiles: Vector2i) -> void:
	var root: Node = ground.get_parent()
	if root == null:
		return
	var markers_root: Node = root.get_node_or_null(^"Markers/FillTerminals")
	if markers_root == null:
		return
	for child: Node in markers_root.get_children():
		if not (child is Node2D):
			continue
		var node2d: Node2D = child as Node2D
		var local: Vector2 = ground.to_local(node2d.global_position)
		var cell: Vector2i = ground.local_to_map(local)
		_add_nearest_empty_terminal(terminals, mask, cell, size_tiles)

static func _add_nearest_empty_terminal(terminals: Array[Vector2i], mask: Array, start: Vector2i, size_tiles: Vector2i) -> void:
	if _in_bounds(start, size_tiles) and int(mask[start.y][start.x]) == EMPTY:
		terminals.append(start)
		return
	for radius: int in range(1, 4):
		for y: int in range(start.y - radius, start.y + radius + 1):
			for x: int in range(start.x - radius, start.x + radius + 1):
				var p := Vector2i(x, y)
				if _in_bounds(p, size_tiles) and int(mask[p.y][p.x]) == EMPTY:
					terminals.append(p)
					return

static func _open_terminal_network(horizontal_edges: Array, vertical_edges: Array, terminals: Array[Vector2i], size_tiles: Vector2i, placement: SpecialChunkPlacement) -> void:
	if terminals.size() < 2:
		return
	var connected: Array[int] = [0]
	var remaining: Array[int] = []
	for i: int in range(1, terminals.size()):
		remaining.append(i)
	while not remaining.is_empty():
		var best_connected: int = connected[0]
		var best_remaining: int = remaining[0]
		var best_distance: int = 999999
		for c_idx: int in connected:
			for r_idx: int in remaining:
				var d: int = _manhattan(terminals[c_idx], terminals[r_idx])
				if d < best_distance:
					best_distance = d
					best_connected = c_idx
					best_remaining = r_idx
		_open_wandering_path(horizontal_edges, vertical_edges, terminals[best_connected], terminals[best_remaining], size_tiles, placement)
		connected.append(best_remaining)
		remaining.erase(best_remaining)

static func _open_wandering_path(horizontal_edges: Array, vertical_edges: Array, start: Vector2i, target: Vector2i, size_tiles: Vector2i, placement: SpecialChunkPlacement) -> void:
	var pos: Vector2i = start
	var safety: int = size_tiles.x * size_tiles.y * 2
	var step_index: int = 0
	while pos != target and safety > 0:
		safety -= 1
		var step: Vector2i = _biased_step(pos, target, step_index, placement)
		var next: Vector2i = pos + step
		if not _in_bounds(next, size_tiles):
			step = _direct_step(pos, target)
			next = pos + step
			if not _in_bounds(next, size_tiles):
				break
		_open_edge_between(horizontal_edges, vertical_edges, pos, next)
		pos = next
		step_index += 1

static func _biased_step(pos: Vector2i, target: Vector2i, step_index: int, placement: SpecialChunkPlacement) -> Vector2i:
	var direct: Vector2i = _direct_step(pos, target)
	var raw: int = hash("path_%d_%d_%d_%d_%d_%d" % [pos.x, pos.y, target.x, target.y, step_index, placement.seed])
	var roll: int = absi(raw) % 100
	if roll < 75:
		return direct
	# Small detours reduce rigid L-shaped paths without sacrificing convergence.
	var options: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	return options[absi(int(raw / 101)) % options.size()]

static func _direct_step(pos: Vector2i, target: Vector2i) -> Vector2i:
	var dx: int = target.x - pos.x
	var dy: int = target.y - pos.y
	if absi(dx) >= absi(dy) and dx != 0:
		return Vector2i(_sign_int(dx), 0)
	if dy != 0:
		return Vector2i(0, _sign_int(dy))
	if dx != 0:
		return Vector2i(_sign_int(dx), 0)
	return Vector2i.ZERO

static func _sign_int(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

static func _open_edge_between(horizontal_edges: Array, vertical_edges: Array, a: Vector2i, b: Vector2i) -> void:
	var delta: Vector2i = b - a
	if delta == Vector2i(1, 0):
		_set_vertical_edge(vertical_edges, a.x + 1, a.y, TileDef.Edge.OPEN)
	elif delta == Vector2i(-1, 0):
		_set_vertical_edge(vertical_edges, a.x, a.y, TileDef.Edge.OPEN)
	elif delta == Vector2i(0, 1):
		_set_horizontal_edge(horizontal_edges, a.x, a.y + 1, TileDef.Edge.OPEN)
	elif delta == Vector2i(0, -1):
		_set_horizontal_edge(horizontal_edges, a.x, a.y, TileDef.Edge.OPEN)

static func _signature_from_edges(horizontal_edges: Array, vertical_edges: Array, cell: Vector2i) -> String:
	var top: int = int(horizontal_edges[cell.y][cell.x])
	var right: int = int(vertical_edges[cell.y][cell.x + 1])
	var bottom: int = int(horizontal_edges[cell.y + 1][cell.x])
	var left: int = int(vertical_edges[cell.y][cell.x])
	return _edge_char(top) + _edge_char(right) + _edge_char(bottom) + _edge_char(left)

static func _set_horizontal_edge(horizontal_edges: Array, x: int, y: int, edge_value: int) -> void:
	if y < 0 or y >= horizontal_edges.size():
		return
	if x < 0 or x >= horizontal_edges[y].size():
		return
	horizontal_edges[y][x] = _merge_edge(int(horizontal_edges[y][x]), edge_value)

static func _set_vertical_edge(vertical_edges: Array, x: int, y: int, edge_value: int) -> void:
	if y < 0 or y >= vertical_edges.size():
		return
	if x < 0 or x >= vertical_edges[y].size():
		return
	vertical_edges[y][x] = _merge_edge(int(vertical_edges[y][x]), edge_value)

static func _merge_edge(existing: int, incoming: int) -> int:
	var edge_value: int = _to_so_edge(incoming)
	if existing == EDGE_UNKNOWN:
		return edge_value
	# If authored/open terminals conflict with a solid hint, prefer OPEN. This prevents
	# doors and explicit terminals from being sealed by neighboring solid metadata.
	if existing == TileDef.Edge.OPEN or edge_value == TileDef.Edge.OPEN:
		return TileDef.Edge.OPEN
	return TileDef.Edge.SOLID

static func _edges_for_atlas_tile(source_id: int, atlas_coords: Vector2i) -> Array[int]:
	# Common atlas: explicit room air / authoring helper tiles.
	# common_air is an authored tile, so ENVIRONMENT_WANG_FILL will not overwrite it;
	# its AIR edges are treated as OPEN when neighboring empty cells are generated.
	if source_id == COMMON_SOURCE_ID:
		if atlas_coords == TileConstants.COMMON_AIR_COORDS:
			return _edges_from_signature("AAAA")
		return _edges_from_signature("OOOO")

	# Biome Wang atlas: row is the edge signature.
	if source_id == 0 or source_id == 1 or source_id == 2:
		var signatures: Array[String] = TileConstants.signature_order()
		if atlas_coords.y >= 0 and atlas_coords.y < signatures.size():
			return TileDef.signature_to_edges(signatures[atlas_coords.y])
		return _edges_from_signature("SSSS")

	# Authored SpecialChunk category atlases. These rows are semantic, not Wang rows.
	if source_id == TileConstants.SOURCE_SPECIAL_CHUNK or source_id == TileConstants.SOURCE_CRYSTAL_GROTTO:
		return _special_category_edges(atlas_coords)

	# Unknown authored tile: stay conservative and treat it as solid.
	return _edges_from_signature("SSSS")

static func _special_category_edges(atlas_coords: Vector2i) -> Array[int]:
	match atlas_coords.y:
		0: return _edges_from_signature("SSSS") # wall
		1: return _edges_from_signature("OOSO") # floor: open top/sides, solid bottom
		2: return _edges_from_signature("OOOO") # platform/overlay
		3: return _edges_from_signature("OOOO") # door/open connector
		4: return _edges_from_signature("SSSS") # pillar
		5: return _edges_from_signature("OOOO") # background
		6: return _edges_from_signature("OOOO") # decoration
		7, 8, 9, 10: return _edges_from_signature("OOOO" if atlas_coords.x >= 4 else "SSSS")
		11: return _edges_from_signature("OOOO")
		_: return _edges_from_signature("SSSS")

static func _edges_from_signature(signature: String) -> Array[int]:
	return TileDef.signature_to_edges(signature)

static func _to_so_edge(edge_value: int) -> int:
	return TileDef.Edge.OPEN if edge_value == TileDef.Edge.OPEN or edge_value == TileDef.Edge.AIR else TileDef.Edge.SOLID

static func _profile_edge(profile: Array[int], index: int) -> int:
	if profile.is_empty():
		return TileDef.Edge.SOLID
	var wrapped: int = index % profile.size()
	var edge_value: int = int(profile[wrapped])
	return _to_so_edge(edge_value)

static func _edge_char(edge_value: int) -> String:
	return "O" if edge_value == TileDef.Edge.OPEN else "S"

static func _variant_for(cell: Vector2i, placement: SpecialChunkPlacement) -> int:
	var raw: int = hash("%d_%d_%d_%d_%d" % [cell.x, cell.y, placement.origin_chunk.x, placement.origin_chunk.y, placement.seed])
	return absi(raw) % TileConstants.GENERATED_VARIANTS_PER_SIGNATURE

static func _deduplicate_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var key: String = "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		result.append(cell)
	return result

static func _in_bounds(cell: Vector2i, size_tiles: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_tiles.x and cell.y < size_tiles.y

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
