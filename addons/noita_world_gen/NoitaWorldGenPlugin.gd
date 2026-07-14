@tool
extends EditorPlugin

const GENERATE_MENU_ITEM: String = "Generate Noita World Resources"
const VALIDATE_MENU_ITEM: String = "Validate Noita World Resources"
const RESOURCE_EXPORTER = preload("res://addons/noita_world_gen/WorldGenResourceExporter.gd")
const RESOURCE_VALIDATOR = preload("res://addons/noita_world_gen/WorldGenResourceValidator.gd")

func _enter_tree() -> void:
	add_tool_menu_item(GENERATE_MENU_ITEM, Callable(self, "_on_generate_requested"))
	add_tool_menu_item(VALIDATE_MENU_ITEM, Callable(self, "_on_validate_requested"))

func _exit_tree() -> void:
	remove_tool_menu_item(GENERATE_MENU_ITEM)
	remove_tool_menu_item(VALIDATE_MENU_ITEM)

func _on_generate_requested() -> void:
	var exporter: WorldGenResourceExporter = RESOURCE_EXPORTER.new()
	var messages: Array[String] = exporter.generate_all(get_editor_interface())
	for message: String in messages:
		print(message)

func _on_validate_requested() -> void:
	var validator: WorldGenResourceValidator = RESOURCE_VALIDATOR.new()
	var messages: Array[String] = validator.validate_all()
	for message: String in messages:
		if message.begins_with("ERROR"):
			push_error(message)
		elif message.begins_with("WARNING"):
			push_warning(message)
		else:
			print(message)
