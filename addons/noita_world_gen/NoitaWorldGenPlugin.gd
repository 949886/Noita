@tool
extends EditorPlugin

const MENU_ITEM: String = "Generate Noita World Resources"
const RESOURCE_EXPORTER = preload("res://addons/noita_world_gen/WorldGenResourceExporter.gd")

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, Callable(self, "_on_generate_requested"))

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)

func _on_generate_requested() -> void:
	var exporter: WorldGenResourceExporter = RESOURCE_EXPORTER.new()
	var messages: Array[String] = exporter.generate_all(get_editor_interface())
	for message: String in messages:
		print(message)
