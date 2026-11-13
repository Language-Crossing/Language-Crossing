extends CanvasLayer

const BLANK_TOKEN := "[blank]"
const BLANK_DISPLAY := "_____"
const REPLAY_CONFIRMATION := "You've already completed this interaction. Do you want to start it again? You won't gain more XP for this."

@export var level_controller_path: NodePath = NodePath("..")
@export_range(16, 48) var dialogue_font_size := 24
@export_range(16, 48) var speaker_font_size := 26
@export_range(14, 36) var option_font_size := 20
@export var option_button_size := Vector2(0, 56)
# The theme's pixel_ui_font only has basic ASCII, so ¡ ¿ á é í ó ú ñ show as boxes. This one has them.
@export var dialogue_font: Font = preload("res://assets/Fonts/pixel-game/Pixel Game.otf")

@onready var ui_root: Control = $Root
@onready var speaker_name: Label = $Root/BottomLayout/DialoguePanel/DialogueContent/SpeakerName
@onready var dialogue_text: Label = $Root/BottomLayout/DialoguePanel/DialogueContent/DialogueText
@onready var options_container: GridContainer = $Root/BottomLayout/Options
@onready var close_button: Button = $Root/BottomLayout/CloseButton

var level_controller: Node
var current_dialogue: Dictionary = {}
var pending_result: Dictionary = {}


func _ready() -> void:
	MovementBlockers.register(ui_root)
	ui_root.hide()
	dialogue_text.add_theme_font_size_override("font_size", dialogue_font_size)
	speaker_name.add_theme_font_size_override("font_size", speaker_font_size)
	close_button.add_theme_font_size_override("font_size", option_font_size)
	dialogue_text.add_theme_font_override("font", dialogue_font)
	speaker_name.add_theme_font_override("font", dialogue_font)
	close_button.add_theme_font_override("font", dialogue_font)
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
	_log_dialogue_ui("Showing conversation with %s" % speaker_name.text)
	var notice := str(context.get("notice", ""))
	if not notice.is_empty():
		current_dialogue.clear()
		dialogue_text.text = notice
		_clear_options()
		return

	if bool(context.get("completed", false)):
		_show_replay_confirmation()
		return

	var dialogue: Variant = context.get("dialogue", {})
	if dialogue is Dictionary:
		_show_dialogue(dialogue)


func _show_replay_confirmation() -> void:
	current_dialogue.clear()
	dialogue_text.text = REPLAY_CONFIRMATION
	_clear_options()
	_add_action_button("Yes", _on_replay_confirmed)
	_add_action_button("No", _close_dialogue)
	options_container.columns = 2


func _on_replay_confirmed() -> void:
	if level_controller != null:
		level_controller.call("replay_dialogue")


func _show_dialogue(dialogue: Dictionary) -> void:
	current_dialogue = dialogue.duplicate(true)
	dialogue_text.text = str(current_dialogue.get("question", "")).replace(BLANK_TOKEN, BLANK_DISPLAY)
	_clear_options()

	var choices: Variant = current_dialogue.get("options", [])
	if not choices is Array:
		return

	# Shuffled so the answer's position gives nothing away. Each button keeps its index
	# in the original options array, since that is what choose_dialogue_option expects.
	var valid_indexes: Array[int] = []
	for index in range(choices.size()):
		var choice: Variant = choices[index]
		if not choice is Dictionary or str(choice.get("optionText", "")).strip_edges().is_empty():
			continue
		valid_indexes.append(index)
	valid_indexes.shuffle()

	options_container.columns = mini(2, maxi(1, valid_indexes.size()))
	for index in valid_indexes:
		var choice: Dictionary = choices[index]
		var button := Button.new()
		button.text = str(choice.get("optionText", ""))
		button.custom_minimum_size = option_button_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", option_font_size)
		button.add_theme_font_override("font", dialogue_font)
		button.pressed.connect(_on_choice_pressed.bind(index))
		options_container.add_child(button)


func _on_choice_pressed(option_index: int) -> void:
	if level_controller != null:
		level_controller.call("choose_dialogue_option", option_index)


func _on_dialogue_choice_resolved(result: Dictionary) -> void:
	pending_result = result.duplicate(true)
	var response := str(result.get("response", "")).strip_edges()
	var is_correct := bool(result.get("isCorrect", false))
	# Only quiz questions get "Try again"; a non-answer like "No, I need more time" keeps "Continue".
	var is_retry := not is_correct and str(current_dialogue.get("kind", "")) == "quiz"
	_log_dialogue_ui("Showing answer feedback (correct: %s, completed: %s)" % [is_correct, result.get("completed", false)])

	if is_retry:
		response = "Not quite! %s" % response if not response.is_empty() else "Not quite!"
	elif response.is_empty():
		_clear_options()
		_continue_dialogue()
		return

	# A correct fill-in-the-blank shows the completed sentence above the reply.
	var question := str(current_dialogue.get("question", ""))
	var blank_fill := str(result.get("blankFill", "")).strip_edges()
	if is_correct and question.contains(BLANK_TOKEN) and not blank_fill.is_empty():
		response = "%s\n%s" % [question.replace(BLANK_TOKEN, blank_fill), response]

	dialogue_text.text = response
	_clear_options()
	_add_action_button("Try again" if is_retry else "Continue", _continue_dialogue)


func _continue_dialogue() -> void:
	var is_correct := bool(pending_result.get("isCorrect", false))
	# Declining a non-quiz question ends the talk; the checkpoint stays, so it resumes here next time.
	var declined := not is_correct and str(current_dialogue.get("kind", "")) != "quiz"
	if bool(pending_result.get("completed", false)) or declined:
		_close_dialogue()
		return

	if is_correct:
		var next_dialogue: Variant = pending_result.get("nextDialogue", {})
		if next_dialogue is Dictionary and not next_dialogue.is_empty():
			_show_dialogue(next_dialogue)
			return

	_show_dialogue(current_dialogue)


func _add_action_button(button_text: String, handler: Callable) -> void:
	options_container.columns = 1
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = option_button_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", option_font_size)
	button.add_theme_font_override("font", dialogue_font)
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
	_log_dialogue_ui("Hiding dialogue panel")
	ui_root.hide()
	current_dialogue.clear()
	pending_result.clear()


func _log_dialogue_ui(message: String) -> void:
	if OS.is_debug_build():
		print("[Dialogue UI] %s" % message)
