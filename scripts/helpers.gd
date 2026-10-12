@export var player_name = "Player One"
@export var levelId = 1
@export var progress = 0
@export var XP = 0
@export var dictionary = {}
@export var inventory = {}

const SAVE_DIR = "user://saves/"
const PLAYER_PATH = SAVE_DIR + "player.json"
const DICTIONARY_PATH = SAVE_DIR + "dictionary.json"
const INVENTORY_PATH = SAVE_DIR + "inventory.json"

# --- Saving ---

func get_player_data() -> Dictionary:
	return {
		"name": player_name,
		"levelId": levelId,
		"progress": progress,
		"XP": XP
	}

func save_game():
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_write_json(PLAYER_PATH, get_player_data())
	_write_json(DICTIONARY_PATH, dictionary)
	_write_json(INVENTORY_PATH, inventory)

func _write_json(path: String, data: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# --- Loading ---

func load_game():
	var player_data = _read_json(PLAYER_PATH)
	if player_data is Dictionary:
		player_name = player_data.get("name", player_name)
		levelId = player_data.get("levelId", levelId)
		progress = player_data.get("progress", progress)
		XP = player_data.get("XP", XP)

	var dict_data = _read_json(DICTIONARY_PATH)
	if dict_data is Dictionary:
		dictionary = dict_data

	var inv_data = _read_json(INVENTORY_PATH)
	if inv_data is Dictionary:
		inventory = inv_data

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed
	
	
