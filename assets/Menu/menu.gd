extends CanvasLayer
var is_pause_menu: bool = false

const LEVEL_SELECT := "res://scenes/ui/level_select.tscn"

@onready var start_button: TextureButton = $Control/StartButton
@onready var options_button: TextureButton = $Control/OptionsButton
@onready var exit_button: TextureButton = $Control/ExitButton
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# CRITICAL FIX: Must be ALWAYS so it can listen for Escape while the game is running!
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_pause_menu = (get_tree().current_scene.name != "Menu")
	
	if is_pause_menu:
		hide()
		start_button.label.text = "Resume"
		# There are no options yet, so in the pause menu this slot leads back to level select.
		options_button.label.text = "Levels"
	else:
		show()
		start_button.label.text = "Start"

func toggle_pause() -> void:
	var should_pause = not get_tree().paused
	get_tree().paused = should_pause
	visible = should_pause

func _input(event: InputEvent) -> void:
	if is_pause_menu and event.is_action_pressed("ui_cancel"):
		toggle_pause()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	if is_pause_menu:
		toggle_pause()
		print("resuming game")
	else:
		get_tree().change_scene_to_file(LEVEL_SELECT)
		print("loading " + LEVEL_SELECT)

func _on_options_button_pressed() -> void:
	if is_pause_menu:
		# Unpause first, or the next scene would start frozen.
		get_tree().paused = false
		get_tree().change_scene_to_file(LEVEL_SELECT)
		return
	print("options")

func _on_exit_button_pressed() -> void:
		get_tree().quit()
		print("quit")
