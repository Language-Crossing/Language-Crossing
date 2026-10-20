extends Node

const SAVE_FILE := "save.json"

signal state_loaded
signal state_saved

var player_name := "Player 1"
var level_id := 1
var progress := 0
var xp := 0
var dictionary: Dictionary = {}
var inventory: Dictionary = {}
var dialogue_progress: Dictionary = {}


func _ready() -> void:
	load_game()


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_progress(true)


func load_game() -> void:
	var default_player: Variant = ConfigHelpers.read_config("Player/player.json", {})
	var default_dictionary: Variant = ConfigHelpers.read_config("Player/dictionary.json", {"dictionary": []})
	var default_inventory: Variant = ConfigHelpers.read_config("Player/inventory.json", {"inventory": []})
	var saved_state: Variant = ConfigHelpers.read_save(SAVE_FILE, {})
	var has_global_save: bool = saved_state is Dictionary and not saved_state.is_empty()

	var player_data: Variant
	var dictionary_data: Variant
	var inventory_data: Variant
	if has_global_save:
		player_data = saved_state.get("player", default_player)
		dictionary_data = saved_state.get("dictionary", default_dictionary)
		inventory_data = saved_state.get("inventory", default_inventory)
	else:
		player_data = ConfigHelpers.read_save("player.json", default_player)
		dictionary_data = ConfigHelpers.read_save("dictionary.json", default_dictionary)
		inventory_data = ConfigHelpers.read_save("inventory.json", default_inventory)

	if not player_data is Dictionary:
		player_data = default_player

	player_name = str(player_data.get("name", "Player 1"))
	level_id = int(player_data.get("levelId", 1))
	progress = int(player_data.get("progress", 0))
	xp = int(player_data.get("XP", 0))
	dialogue_progress = player_data.get("dialogueProgress", {})
	if not dialogue_progress is Dictionary:
		dialogue_progress = {}

	dictionary = _dictionary_or_fallback(dictionary_data, default_dictionary)
	inventory = _dictionary_or_fallback(inventory_data, default_inventory)
	state_loaded.emit()


func reset_progress(restart_current_scene: bool = false) -> bool:
	var default_player: Variant = ConfigHelpers.read_config("Player/player.json", {})
	if not default_player is Dictionary:
		push_error("Player defaults must contain a JSON object")
		return false

	var default_dictionary: Variant = ConfigHelpers.read_config("Player/dictionary.json", {"dictionary": []})
	var default_inventory: Variant = ConfigHelpers.read_config("Player/inventory.json", {"inventory": []})
	player_name = str(default_player.get("name", "Player 1"))
	level_id = int(default_player.get("levelId", 1))
	progress = int(default_player.get("progress", 0))
	xp = int(default_player.get("XP", 0))
	dialogue_progress.clear()
	dictionary = _dictionary_or_fallback(default_dictionary, {"dictionary": []})
	inventory = _dictionary_or_fallback(default_inventory, {"inventory": []})

	if not save_game():
		return false
	state_loaded.emit()
	print("Player progress reset to config defaults.")
	if restart_current_scene:
		get_tree().reload_current_scene()
	return true


func save_game() -> bool:
	var saved := ConfigHelpers.write_save(SAVE_FILE, {
		"player": get_player_data(),
		"dictionary": dictionary,
		"inventory": inventory
	})
	if saved:
		state_saved.emit()
	return saved


func get_player_data() -> Dictionary:
	return {
		"name": player_name,
		"levelId": level_id,
		"progress": progress,
		"XP": xp,
		"dialogueProgress": dialogue_progress
	}


func get_dialogue_checkpoint(target_level_id: int, npc_id: String) -> Dictionary:
	var level_checkpoints: Variant = dialogue_progress.get(str(target_level_id), {})
	if not level_checkpoints is Dictionary:
		return {"dialogueId": 0, "completed": false}

	var checkpoint: Variant = level_checkpoints.get(npc_id, {"dialogueId": 0, "completed": false})
	if checkpoint is Dictionary:
		return checkpoint.duplicate(true)
	return {"dialogueId": 0, "completed": false}


func set_dialogue_checkpoint(target_level_id: int, npc_id: String, dialogue_id: int, completed: bool) -> void:
	var level_key := str(target_level_id)
	var level_checkpoints: Dictionary = dialogue_progress.get(level_key, {})
	level_checkpoints[npc_id] = {
		"dialogueId": dialogue_id,
		"completed": completed
	}
	dialogue_progress[level_key] = level_checkpoints


func add_dictionary_entries(entries: Array) -> void:
	var learned_entries: Array = dictionary.get("dictionary", [])
	for entry in entries:
		if not entry is Dictionary:
			continue

		var spanish_word := str(entry.get("spanishWord", entry.get("spanish", "")))
		var english_word := str(entry.get("englishWord", entry.get("english", "")))
		if spanish_word.is_empty() or english_word.is_empty():
			continue

		var already_learned := false
		for learned_entry in learned_entries:
			if learned_entry is Dictionary and str(learned_entry.get("spanishWord", "")) == spanish_word:
				already_learned = true
				break
		if already_learned:
			continue

		var normalized_entry := {
			"spanishWord": spanish_word,
			"englishWord": english_word
		}
		if entry.has("partOfSpeech"):
			normalized_entry["partOfSpeech"] = entry["partOfSpeech"]
		learned_entries.append(normalized_entry)

	dictionary["dictionary"] = learned_entries


func _dictionary_or_fallback(value: Variant, fallback: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	if fallback is Dictionary:
		return fallback.duplicate(true)
	return {}
