extends Area2D

@export_file("*.tscn") var level_scene: String

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file(level_scene)
func _ready() -> void:
	input_event.connect(_on_input_event)
