extends Node2D

const MAIN_MENU := "res://assets/Menu/Menu.tscn"

@onready var _back_button: BaseButton = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
