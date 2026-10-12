extends "res://scenes/characters/character.gd"

func _physics_process(_delta):
	# 1. Fetch directional input vector using your Input Map action names
	# (negative_x, positive_x, negative_y, positive_y)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# 2. Apply movement velocity
	if input_dir != Vector2.ZERO:
		velocity = input_dir * SPEED
	else:
		velocity = Vector2.ZERO

	# 3. Move the character with Godot's physics engine
	move_and_slide()
	
	# 4. Trigger the base character's animation handler
	update_animation_state(input_dir)
