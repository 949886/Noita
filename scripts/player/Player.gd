extends CharacterBody2D

@export var speed: float = 420.0
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.35
@export var max_zoom: float = 2.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	_ensure_input_actions()
	camera.make_current()

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_add_key_action("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])

func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var exists: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.keycode == key:
				exists = true
		if not exists:
			var ev: InputEventKey = InputEventKey.new()
			ev.keycode = key
			InputMap.action_add_event(action, ev)

func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	velocity = input_dir * speed
	move_and_slide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		_set_zoom(camera.zoom + Vector2.ONE * zoom_step)
	elif Input.is_action_just_pressed("zoom_out"):
		_set_zoom(camera.zoom - Vector2.ONE * zoom_step)

func _set_zoom(value: Vector2) -> void:
	var clamped: float = clampf(value.x, min_zoom, max_zoom)
	camera.zoom = Vector2(clamped, clamped)
