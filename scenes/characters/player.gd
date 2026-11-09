extends "res://scenes/characters/character.gd"

func _physics_process(_delta):
	# 1. Fetch directional input vector using your Input Map action names
	# (negative_x, positive_x, negative_y, positive_y)
	# Open conversations and the dictionary hold the player in place.
	var input_dir = Vector2.ZERO
	if not _is_movement_blocked():
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# 2. Apply movement velocity
	if input_dir != Vector2.ZERO:
		velocity = input_dir * SPEED
	else:
		velocity = Vector2.ZERO

	# 3. Move the character with Godot's physics engine
	move_and_slide()
	
	# 4. Trigger the base character's animation handler
	update_animation_state(input_dir)


func _is_movement_blocked() -> bool:
	for node in get_tree().get_nodes_in_group("blocks_player_movement"):
		if node.is_visible_in_tree():
			return true
	return false
