extends CanvasLayer

@export var level_controller_path: NodePath = NodePath("..")
@export_range(16, 48) var dialogue_font_size := 24
@export_range(16, 48) var speaker_font_size := 26
@export_range(14, 36) var option_font_size := 20
@export var option_button_size := Vector2(0, 56)

@onready var ui_root: Control = $Root
@onready var speaker_name: Label = $Root/BottomLayout/DialoguePanel/DialogueContent/SpeakerName
@onready var dialogue_text: Label = $Root/BottomLayout/DialoguePanel/DialogueContent/DialogueText
@onready var options_container: GridContainer = $Root/BottomLayout/Options
@onready var close_button: Button = $Root/BottomLayout/CloseButton

var level_controller: Node
var current_dialogue: Dictionary = {}
var pending_result: Dictionary = {}


func _ready() -> void:
	ui_root.hide()
	dialogue_text.add_theme_font_size_override("font_size", dialogue_font_size)
	speaker_name.add_theme_font_size_override("font_size", speaker_font_size)
	close_button.add_theme_font_size_override("font_size", option_font_size)
	close_button.pressed.connect(_close_dialogue)
	level_controller = get_node_or_null(level_controller_path)
	if level_controller == null:
		push_error("Dialogue UI could not find its level controller")
		return

	_connect_controller_signal("dialogue_started", _on_dialogue_started)
	_connect_controller_signal("dialogue_choice_resolved", _on_dialogue_choice_resolved)
	_connect_controller_signal("dialogue_closed", _on_dialogue_closed)


func _connect_controller_signal(signal_name: String, handler: Callable) -> void:
	if not level_controller.has_signal(signal_name):
		push_error("Level controller is missing signal '%s'" % signal_name)
		return
	if not level_controller.is_connected(signal_name, handler):
		level_controller.connect(signal_name, handler)


func _on_dialogue_started(context: Dictionary) -> void:
	ui_root.show()
	pending_result.clear()
	speaker_name.text = str(context.get("npcName", ""))
	if bool(context.get("completed", false)):
		current_dialogue.clear()
		dialogue_text.text = "You have completed this conversation."
		_clear_options()
		return

	var dialogue: Variant = context.get("dialogue", {})
	if dialogue is Dictionary:
		_show_dialogue(dialogue)


func _show_dialogue(dialogue: Dictionary) -> void:
	current_dialogue = dialogue.duplicate(true)
	dialogue_text.text = str(current_dialogue.get("question", ""))
	_clear_options()

	var choices: Variant = current_dialogue.get("options", [])
	if not choices is Array:
		return
	for index in range(choices.size()):
		var choice: Variant = choices[index]
		if not choice is Dictionary:
			continue
		var button := Button.new()
		button.text = str(choice.get("optionText", "Continue"))
		button.custom_minimum_size = option_button_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", option_font_size)
		button.pressed.connect(_on_choice_pressed.bind(index))
		options_container.add_child(button)


func _on_choice_pressed(option_index: int) -> void:
	if level_controller != null:
		level_controller.call("choose_dialogue_option", option_index)


func _on_dialogue_choice_resolved(result: Dictionary) -> void:
	pending_result = result.duplicate(true)
	dialogue_text.text = str(result.get("response", ""))
	_clear_options()
	_add_action_button("Continue", _continue_dialogue)


func _continue_dialogue() -> void:
	if bool(pending_result.get("completed", false)):
		_close_dialogue()
		return

	if bool(pending_result.get("isCorrect", false)):
		var next_dialogue: Variant = pending_result.get("nextDialogue", {})
		if next_dialogue is Dictionary and not next_dialogue.is_empty():
			_show_dialogue(next_dialogue)
			return

	_show_dialogue(current_dialogue)


func _add_action_button(button_text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = option_button_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", option_font_size)
	button.pressed.connect(handler)
	options_container.add_child(button)


func _clear_options() -> void:
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()


func _close_dialogue() -> void:
	if level_controller != null:
		level_controller.call("close_dialogue")
	else:
		ui_root.hide()


func _on_dialogue_closed() -> void:
	ui_root.hide()
	current_dialogue.clear()
	pending_result.clear()