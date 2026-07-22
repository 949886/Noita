class_name PieceDebugOverlay
extends CanvasLayer

var label: Label
var manager: PieceWorldManager

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(18, 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

func _process(_delta: float) -> void:
	if manager == null or label == null:
		return
	var current: Vector2i = manager.current_player_chunk
	var lines: Array[String] = []
	lines.append("Piece World Prototype")
	lines.append("seed %d" % manager.world_seed)
	lines.append("chunk %s loaded %d" % [str(current), manager.loaded_chunks.size()])
	lines.append("F1 debug draw  F3 regen  F4 next seed")
	var data: PieceChunkData = manager.chunk_data_by_coord.get(current, null)
	if data != null:
		lines.append("biome/type %s/%s" % [str(data.biome_id), str(data.chunk_type)])
		lines.append("pieces %d regular %d glue %d" % [data.piece_count, data.regular_piece_count, data.used_glue_count])
		lines.append(data.tag_string())
	label.text = "\n".join(lines)
