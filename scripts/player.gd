extends CharacterBody2D

@export var speed = 150
var screen_size: Vector2

@onready var _animated_sprite = $AnimatedSprite2D

func _ready():
	screen_size = get_viewport_rect().size

func _physics_process(_delta):
	var direction = Vector2.ZERO

	# Input handling
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	# Movement & Animation logic
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * speed
		
		if direction.x > 0:
			_animated_sprite.play("walk_right_down")
		elif direction.x < 0:
			_animated_sprite.play("walk_left_down")
		elif direction.y > 0:
			_animated_sprite.play("walk_down")
		elif direction.y < 0:
			_animated_sprite.play("walk_up")
	else:
		velocity = Vector2.ZERO
		_animated_sprite.play("idle_down")
		
	move_and_slide()
	position = position.clamp(Vector2.ZERO, screen_size)
