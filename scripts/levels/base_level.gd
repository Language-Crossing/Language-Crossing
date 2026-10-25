extends Node2D

signal dialogue_started(context: Dictionary)
signal dialogue_choice_resolved(result: Dictionary)
signal dialogue_closed

@export_file("*.json") var config_path := ""

var level_data: Dictionary = {}
var npcs_by_id: Dictionary = {}
var active_npc_id: StringName = &""
var active_dialogues: Array = []
var active_dialogue_index := -1
@onready var player_state: Node = get_node("/root/PlayerState")


func _ready() -> void:
	var loaded_config: Variant = ConfigHelpers.read_json(config_path, {})
	if not loaded_config is Dictionary:
		push_error("Level config must contain a JSON object: %s" % config_path)
		return

	level_data = loaded_config
	var npc_entries: Variant = level_data.get("NPCS", [])
	if not npc_entries is Array:
		push_error("Level config NPCS must be an array: %s" % config_path)
		return

	for npc_data in npc_entries:
		if not npc_data is Dictionary:
			continue
		var npc_id := StringName(str(npc_data.get("npcId", "")))
		if npc_id.is_empty():
			push_warning("Skipping an NPC with no npcId in %s" % config_path)
			continue
		npcs_by_id[npc_id] = npc_data

	_connect_interactable_npcs(self)


func _connect_interactable_npcs(parent: Node) -> void:
	for child in parent.get_children():
		if child is InteractableNPC:
			if not npcs_by_id.has(child.npc_id):
				push_warning("NPC node '%s' has no matching config entry in %s" % [child.name, config_path])
			elif not child.interacted.is_connected(_on_npc_interacted):
				child.interacted.connect(_on_npc_interacted)
		_connect_interactable_npcs(child)


func start_dialogue(npc_id: StringName) -> Dictionary:
	if not npcs_by_id.has(npc_id):
		push_warning("No NPC named '%s' exists in %s" % [npc_id, config_path])
		return {}

	var npc_data: Dictionary = npcs_by_id[npc_id]
	var dialogues: Variant = npc_data.get("dialogues", [])
	if not dialogues is Array or dialogues.is_empty():
		push_warning("NPC '%s' has no dialogue entries" % npc_id)
		return {}

	active_npc_id = npc_id
	active_dialogues = dialogues.duplicate(true)
	var checkpoint: Dictionary = player_state.call("get_dialogue_checkpoint", int(level_data.get("levelId", 0)), str(npc_id))
	if bool(checkpoint.get("completed", false)):
		active_dialogue_index = -1
		_log_dialogue("Conversation already completed for %s" % npc_id)
		var completed_context := _build_dialogue_context(npc_data, {}, true)
		dialogue_started.emit(completed_context)
		return completed_context

	var dialogue_id := int(checkpoint.get("dialogueId", 0))
	active_dialogue_index = _find_dialogue_index(dialogue_id)
	if active_dialogue_index < 0:
		active_dialogue_index = 0
		player_state.call("set_dialogue_checkpoint",
			int(level_data.get("levelId", 0)),
			str(npc_id),
			int(active_dialogues[0].get("id", 0)),
			false
		)

	var context := _build_dialogue_context(npc_data, active_dialogues[active_dialogue_index], false)
	_log_dialogue("Started %s at dialogue id %d" % [npc_id, int(context.dialogue.get("id", 0))])
	dialogue_started.emit(context)
	return context


func choose_dialogue_option(option_index: int) -> Dictionary:
	if active_dialogue_index < 0 or active_dialogue_index >= active_dialogues.size():
		return {}

	var current_dialogue: Dictionary = active_dialogues[active_dialogue_index]
	var options: Variant = current_dialogue.get("options", [])
	if not options is Array or option_index < 0 or option_index >= options.size():
		return {}
	if not options[option_index] is Dictionary:
		return {}

	var selected_option: Dictionary = options[option_index]
	var is_correct := bool(selected_option.get("isAnswer", false))
	_log_dialogue(
		"%s selected option %d for dialogue id %d (correct: %s)" % [
			active_npc_id,
			option_index + 1,
			int(current_dialogue.get("id", 0)),
			is_correct
		]
	)
	var next_dialogue: Dictionary = current_dialogue
	var completed := false
	if is_correct:
		var next_index := active_dialogue_index + 1
		if next_index < active_dialogues.size():
			active_dialogue_index = next_index
			next_dialogue = active_dialogues[active_dialogue_index]
		else:
			completed = true
			next_dialogue = {}
			active_dialogue_index = -1

		var target_level_id := int(level_data.get("levelId", 0))
		var checkpoint_dialogue_id := int(current_dialogue.get("id", 0))
		if not completed:
			checkpoint_dialogue_id = int(next_dialogue.get("id", checkpoint_dialogue_id))
		var learned_terms: Variant = current_dialogue.get("dictionary", [])
		if learned_terms is Array:
			for term in learned_terms:
				if term is Dictionary:
					DictionaryManager.add_level_entry(term)
		player_state.call("set_dialogue_checkpoint", target_level_id, str(active_npc_id), checkpoint_dialogue_id, completed)
		player_state.call("save_game")

	var result := {
		"npcId": str(active_npc_id),
		"response": str(selected_option.get("response", "")),
		"isCorrect": is_correct,
		"nextDialogue": next_dialogue,
		"completed": completed
	}
	dialogue_choice_resolved.emit(result)
	return result


func close_dialogue() -> void:
	_log_dialogue("Closed conversation with %s" % active_npc_id)
	active_npc_id = &""
	active_dialogues = []
	active_dialogue_index = -1
	dialogue_closed.emit()


func _on_npc_interacted(npc_id: StringName) -> void:
	start_dialogue(npc_id)


func _log_dialogue(message: String) -> void:
	if OS.is_debug_build():
		print("[Dialogue] %s" % message)


func _find_dialogue_index(dialogue_id: int) -> int:
	for index in range(active_dialogues.size()):
		var dialogue: Variant = active_dialogues[index]
		if dialogue is Dictionary and int(dialogue.get("id", 0)) == dialogue_id:
			return index
	return -1


func _build_dialogue_context(npc_data: Dictionary, dialogue: Dictionary, completed: bool) -> Dictionary:
	return {
		"levelId": int(level_data.get("levelId", 0)),
		"npcId": str(active_npc_id),
		"npcName": str(npc_data.get("name", active_npc_id)),
		"dialogue": dialogue.duplicate(true),
		"completed": completed
	}
