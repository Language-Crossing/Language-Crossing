extends CharacterBody2D

var speed = 500

func _physics_process(delta: float) -> void:

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if Input.is_action_pressed("ui_right") || Input.is_action_pressed("ui_left"):
		direction.y = 0
	elif Input.is_action_pressed("ui_up") || Input.is_action_pressed("ui_down"):
		direction.x = 0
	else:
		direction = Vector2.ZERO
	
	# noramlize the directional movement
	direction = direction.normalized()
	
	#setup the actual movement
	velocity = (direction * speed)
	move_and_slide()
