@tool
extends Control
## One card on the level select screen. Set the text, the scene to open and, optionally,
## a conversation the player has to finish before the card unlocks.

@export var title := "Level":
	set(value):
		title = value
		_update_text()
@export var subtitle := "":
	set(value):
		subtitle = value
		_update_text()
@export_file("*.tscn") var scene_path := ""

@export_group("Unlock")
## Leave empty for a card that is always open.
@export var requires_npc_id := ""
@export var requires_level_id := 1
@export var locked_text := "Locked":
	set(value):
		locked_text = value
		_update_text()

@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _play_button: TextureButton = %PlayButton
@onready var _locked_label: Label = %LockedLabel


func _ready() -> void:
	_update_text()
	if Engine.is_editor_hint():
		return
	_play_button.pressed.connect(_on_play_pressed)
	PlayerState.state_loaded.connect(refresh)
	refresh()


## Shows the Play button or the locked message, based on the player's save.
func refresh() -> void:
	var locked := is_locked()
	_play_button.visible = not locked
	_locked_label.visible = locked
	modulate = Color(0.7, 0.7, 0.7) if locked else Color.WHITE


func is_locked() -> bool:
	if requires_npc_id.is_empty():
		return false
	var checkpoint: Dictionary = PlayerState.get_dialogue_checkpoint(requires_level_id, requires_npc_id)
	return not bool(checkpoint.get("completed", false))


func _on_play_pressed() -> void:
	if is_locked() or scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)


func _update_text() -> void:
	if not is_node_ready():
		return
	_title_label.text = title
	_subtitle_label.text = subtitle
	_locked_label.text = locked_text
