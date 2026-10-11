extends Area2D

var player_nearby := false


func _on_body_entered(body):
	if body.name == "Player" and "can_fish" in body:
		player_nearby = true
		body.can_fish = true


func _on_body_exited(body):
	if body.name == "Player" and "can_fish" in body:
		player_nearby = false
		body.can_fish = false
