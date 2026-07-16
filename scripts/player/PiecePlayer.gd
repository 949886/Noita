extends CharacterBody2D

@export var speed: float = 360.0

func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(24, 36)
	shape.shape = rect
	add_child(shape)
	var body: ColorRect = ColorRect.new()
	body.size = Vector2(24, 36)
	body.position = Vector2(-12, -18)
	body.color = Color(1.0, 0.6, 0.2, 1.0)
	add_child(body)

func _physics_process(_delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0
	velocity = dir.normalized() * speed
	move_and_slide()
