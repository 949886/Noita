class_name ChunkRenderer
extends RefCounted

# Legacy Sprite2D renderer kept only as a fallback reference. The active demo uses ChunkTileMapRenderer.
const TILE_SIZE: int = TileConstants.TILE_SIZE
const TILES_PER_CHUNK: int = TileConstants.TILES_PER_CHUNK

func create_chunk_node(data: ChunkData) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = "LegacyChunk_%d_%d" % [data.coord.x, data.coord.y]
	node.position = Vector2(data.coord.x * TILES_PER_CHUNK * TILE_SIZE, data.coord.y * TILES_PER_CHUNK * TILE_SIZE)
	for y: int in range(TILES_PER_CHUNK):
		for x: int in range(TILES_PER_CHUNK):
			var tile: TileDef = data.tile_at(x, y)
			if tile.texture == null:
				continue
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = tile.texture
			sprite.centered = false
			sprite.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			node.add_child(sprite)
	return node
