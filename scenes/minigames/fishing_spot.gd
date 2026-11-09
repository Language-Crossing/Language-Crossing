extends Area2D

var player_nearby := false
var spot_valid := false
var player: Node2D = null


func _on_body_entered(body):
	if body.name == "Player":
		player_nearby = true
		player = body
		player.current_fishing_spot = self
		spot_valid = check_spot_validity(player)
		if spot_valid:
			body.can_fish = true


func _on_body_exited(body):
	if body.name == "Player":
		player_nearby = false
		player = null
		spot_valid = false
		body.can_fish = false
		body.current_fishing_spot = null

func _process(_delta):
	if player_nearby and player != null:
		check_spot_validity(player)

func check_spot_validity(player):
	if not player_nearby or player == null:
		spot_valid = false
		player.can_fish = false
		return false
	
	var spot_name: String = get_parent().name
	var direction: Vector2 = player.facing_direction
	spot_valid = true
	match spot_name:
		"FishingSpot1":
			# not left
			spot_valid = direction != Vector2.LEFT
		"FishingSpot2":
			# not right
			spot_valid = direction != Vector2.RIGHT
		"FishingSpot3":
			# not down
			spot_valid = direction != Vector2.DOWN
		"FishingSpot4":
			# not up
			spot_valid = direction != Vector2.UP
		_:
			spot_valid = false
	player.can_fish = spot_valid
	return spot_valid
