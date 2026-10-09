extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	var level1 = "res://scenes/levels/level1.tscn"
	get_tree().change_scene_to_file(level1)
	print("loading " + level1)

func _on_options_button_pressed() -> void:
	print("options")
	pass # Replace with function body.

func _on_exit_button_pressed() -> void:
	get_tree().quit()
	print("quit")
	pass # Replace with function body.
