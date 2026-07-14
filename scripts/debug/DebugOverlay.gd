extends CanvasLayer

# Modern, compact debug HUD. It is intentionally built in script so it stays
# resilient while the project changes scene structure during early prototyping.

var panel: PanelContainer
var title_label: Label
var world_label: Label
var chunk_label: Label
var stats_label: Label
var special_label: Label
var help_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var old_panel: Node = get_node_or_null("Panel")
	if old_panel != null:
		old_panel.queue_free()

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "DebugMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 18.0
	margin.offset_top = 18.0
	margin.offset_right = 398.0
	margin.offset_bottom = 310.0
	add_child(margin)

	panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.custom_minimum_size = Vector2(380, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.075, 0.82)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	title_label = _make_label("NOITA WORLD DEBUG", 15, Color(0.90, 0.96, 1.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	box.add_child(title_label)

	world_label = _make_label("World: loading...", 12, Color(0.82, 0.88, 0.94, 1.0))
	box.add_child(world_label)
	chunk_label = _make_label("Chunk: loading...", 12, Color(0.78, 0.86, 0.92, 1.0))
	box.add_child(chunk_label)
	stats_label = _make_label("Stats: loading...", 12, Color(0.78, 0.86, 0.92, 1.0))
	box.add_child(stats_label)
	special_label = _make_label("Special: none", 12, Color(0.84, 0.78, 0.94, 1.0))
	box.add_child(special_label)
	help_label = _make_label("F1 HUD  F2 World Debug  F3 Regen  F4 Next Seed", 11, Color(0.62, 0.68, 0.74, 1.0))
	box.add_child(help_label)

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	return label

func set_debug_snapshot(snapshot: Dictionary) -> void:
	if panel == null:
		_build_ui()
	world_label.text = "Seed %d  ·  Loaded %d  ·  Radius %d\nPlayer chunk %s  ·  Renderer %s" % [
		int(snapshot.get("seed", 0)),
		int(snapshot.get("loaded_count", 0)),
		int(snapshot.get("load_radius", 0)),
		str(snapshot.get("center_chunk", Vector2i.ZERO)),
		str(snapshot.get("renderer", "TileMapLayer")),
	]
	chunk_label.text = "Biome %s  ·  Type %s  ·  Open sides %d  ·  Conn %d\nTags %s\nT %s\nR %s\nB %s\nL %s" % [
		str(snapshot.get("biome", "unknown")),
		str(snapshot.get("chunk_type", "unknown")),
		int(snapshot.get("open_sides", 0)),
		int(snapshot.get("intended_connections", 0)),
		str(snapshot.get("structure_tags", "fallback")),
		str(snapshot.get("top_profile", "--------")),
		str(snapshot.get("right_profile", "--------")),
		str(snapshot.get("bottom_profile", "--------")),
		str(snapshot.get("left_profile", "--------")),
	]
	stats_label.text = "Exact %d  ·  Compatible %d  ·  Fallback %d\nAir tiles %d  ·  Pockets %d  ·  Chamber carve A%d/O%d\nConn path %d  ·  Current sides %d  ·  Adjusted %d" % [
		int(snapshot.get("exact_matches", 0)),
		int(snapshot.get("compatible_matches", 0)),
		int(snapshot.get("fallback_count", 0)),
		int(snapshot.get("air_tiles", 0)),
		int(snapshot.get("air_pockets", 0)),
		int(snapshot.get("chamber_carve_air", 0)),
		int(snapshot.get("chamber_carve_open", 0)),
		int(snapshot.get("connectivity_path_tiles", 0)),
		int(snapshot.get("connected_open_sides", 0)),
		int(snapshot.get("connectivity_adjusted", 0)),
	]
	var special_text: String = str(snapshot.get("special_info", ""))
	var chamber_text: String = str(snapshot.get("current_chamber", ""))
	var detail_text: String = "SpecialChunk: %s" % (special_text if special_text != "" else "none nearby / current normal chunk")
	if chamber_text != "":
		detail_text += "\nChamber: " + chamber_text
	special_label.text = detail_text
	help_label.text = "F1 HUD  F2 World Debug  F3 Regenerate  F4 Next Seed"

# Backward-compatible entry point retained for older WorldManager builds.
func set_debug_data(seed_value: int, center_chunk: Vector2i, loaded_count: int, fallback_count: int, renderer_name: String = "TileMapLayer", air_tile_count: int = 0, compatible_match_count: int = 0) -> void:
	set_debug_snapshot({
		"seed": seed_value,
		"center_chunk": center_chunk,
		"loaded_count": loaded_count,
		"load_radius": 0,
		"renderer": renderer_name,
		"fallback_count": fallback_count,
		"compatible_matches": compatible_match_count,
		"air_tiles": air_tile_count,
	})

func toggle_visible() -> void:
	visible = not visible
