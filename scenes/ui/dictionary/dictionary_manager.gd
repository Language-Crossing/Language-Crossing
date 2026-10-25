extends Node
## Autoload: owns the player's saved words.
## UI scenes only read from this and write through it, so the book, the button
## and the "save this word?" prompt never hold their own copy of the data.
##
## Entry shape matches configs/Player/dictionary.json:
##   { "spanishWord": "Hola", "englishWord": "Hello", "partOfSpeech": "interjection" (optional) }

## Emitted after a word is actually saved (not for duplicates).
signal word_added(entry: Dictionary)
## Emitted whenever the list changes in any way. UI should just refresh on this.
signal dictionary_changed
## Emitted by offer_word(). The save prompt listens to this.
signal word_offered(entry: Dictionary)

const SAVE_PATH := "user://dictionary.json"
## Only used by the F9 debug helper below, never as the player's real data.
const SAMPLE_PATH := "res://configs/Player/dictionary.json"

var _words: Array[Dictionary] = []


func _ready() -> void:
	_load()


func get_words() -> Array[Dictionary]:
	return _words.duplicate()


func get_word_count() -> int:
	return _words.size()


func has_word(spanish: String) -> bool:
	return _index_of(spanish) != -1


## Saves a word. Returns false if it was empty or already in the dictionary.
func add_word(spanish: String, english: String, part_of_speech: String = "") -> bool:
	spanish = spanish.strip_edges()
	if spanish.is_empty() or has_word(spanish):
		return false
	var entry := {"spanishWord": spanish, "englishWord": english.strip_edges()}
	if not part_of_speech.is_empty():
		entry["partOfSpeech"] = part_of_speech
	_words.append(entry)
	_save()
	word_added.emit(entry)
	dictionary_changed.emit()
	return true


## Same as add_word, for an entry from a level JSON "dictionary" array:
##   { "spanish": "Hola", "english": "Hello", "partOfSpeech": "interjection" }
func add_level_entry(level_entry: Dictionary) -> bool:
	return add_word(
		str(level_entry.get("spanish", "")),
		str(level_entry.get("english", "")),
		str(level_entry.get("partOfSpeech", ""))
	)


## Call this after an interaction to ask "do you want to save this word?".
## Does nothing if the word is already saved. The prompt in dictionary_hud.tscn shows it.
func offer_word(spanish: String, english: String, part_of_speech: String = "") -> void:
	if spanish.strip_edges().is_empty() or has_word(spanish):
		return
	var entry := {"spanishWord": spanish.strip_edges(), "englishWord": english.strip_edges()}
	if not part_of_speech.is_empty():
		entry["partOfSpeech"] = part_of_speech
	word_offered.emit(entry)


# --- Debug helpers (only wired up in debug builds, see dictionary_hud.gd) ---

## Offers the next sample word that isn't saved yet, to test the prompt + book end to end.
func debug_offer_sample_word() -> void:
	var file := FileAccess.open(SAMPLE_PATH, FileAccess.READ)
	if file == null:
		push_warning("DictionaryManager: could not open %s" % SAMPLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("dictionary"):
		return
	for item in parsed["dictionary"]:
		if item is Dictionary and not has_word(str(item.get("spanishWord", ""))):
			offer_word(
				str(item.get("spanishWord", "")),
				str(item.get("englishWord", "")),
				str(item.get("partOfSpeech", ""))
			)
			return


func debug_clear() -> void:
	_words.clear()
	_save()
	dictionary_changed.emit()


# --- Internals ---

func _index_of(spanish: String) -> int:
	var wanted := spanish.strip_edges().to_lower()
	for i in _words.size():
		if str(_words[i].get("spanishWord", "")).to_lower() == wanted:
			return i
	return -1


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("DictionaryManager: could not write %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"dictionary": _words}, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("dictionary"):
		push_warning("DictionaryManager: %s is not a valid dictionary file, starting empty" % SAVE_PATH)
		return
	for item in parsed["dictionary"]:
		if item is Dictionary and item.has("spanishWord"):
			_words.append(item)
