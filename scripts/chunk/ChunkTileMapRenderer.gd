class_name ChunkTileMapRenderer
extends RefCounted

const TILES_PER_CHUNK: int = TileConstants.TILES_PER_CHUNK

var tile_library: TileLibrary

func _init(p_tile_library: TileLibrary = null) -> void:
	tile_library = p_tile_library

func paint_chunk(data: ChunkData, layer: TileMapLayer) -> void:
	var origin: Vector2i = data.coord * TILES_PER_CHUNK
	var source_id: int = 0
	if tile_library != null:
		source_id = tile_library.get_source_id_for_biome(data.biome_id)
	for y: int in range(TILES_PER_CHUNK):
		for x: int in range(TILES_PER_CHUNK):
			var tile: TileDef = data.tile_at(x, y)
			var map_pos: Vector2i = origin + Vector2i(x, y)
			layer.set_cell(map_pos, source_id, tile.atlas_coords, tile.alternative_tile)

func clear_chunk(coord: Vector2i, layer: TileMapLayer) -> void:
	var origin: Vector2i = coord * TILES_PER_CHUNK
	for y: int in range(TILES_PER_CHUNK):
		for x: int in range(TILES_PER_CHUNK):
			layer.erase_cell(origin + Vector2i(x, y))
