extends CanvasLayer

const LEVEL_SELECT_SCENE := "res://scenes/ui/level_select.tscn"

@onready var menu_panel: PanelContainer = $MenuPanel
@onready var background_fade: ColorRect = $BackgroundFade
@onready var resume_button: Button = $MenuPanel/Margin/MenuItems/ResumeButton
@onready var back_button: Button = $MenuPanel/Margin/MenuItems/BackToLevelsButton


func _ready() -> void:
	MovementBlockers.register(menu_panel)
	menu_panel.hide()
	resume_button.pressed.connect(_close_menu)
	back_button.pressed.connect(_back_to_levels)
	background_fade.gui_input.connect(_on_background_fade_gui_input)


func _on_menu_button_pressed() -> void:
	var should_open := not menu_panel.visible
	menu_panel.visible = should_open
	background_fade.visible = should_open


func _close_menu() -> void:
	menu_panel.hide()
	background_fade.hide()


func _on_background_fade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_menu()


func _back_to_levels() -> void:
	if not PlayerState.save_game():
		push_error("Could not save player progress before returning to level selection")
		return
	var error := get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
	if error != OK:
		push_error("Could not return to level selection: %s" % error_string(error))
