extends Node
## Autoload: the one place to read or add the player's saved words.
## UI scenes and dialogue only go through this, so nothing else holds its own copy.
##
## The words themselves live in PlayerState.dictionary and are written to PlayerState's
## save file, so there is one save and F8 (reset progress) resets the dictionary too.
## New players start with the words in configs/Player/dictionary.json (currently none).
## In the game, words arrive from dialogue: base_level.gd calls add_level_entry() for each
## word in a question's "dictionary" list when the player answers it correctly.
##
## Entry shape matches configs/Player/dictionary.json:
##   { "spanishWord": "Hola", "englishWord": "Hello", "partOfSpeech": "interjection" (optional) }

## Emitted after a word is actually saved (not for duplicates).
signal word_added(entry: Dictionary)
## Emitted whenever the list changes in any way. UI should just refresh on this.
signal dictionary_changed
## Emitted by offer_word(). The save prompt listens to this.
signal word_offered(entry: Dictionary)

## Only used by the F9 debug helper below, never as the player's real data.
const DEBUG_SAMPLE_WORDS: Array[Dictionary] = [
	{"spanishWord": "Casa", "englishWord": "House"},
	{"spanishWord": "Perro", "englishWord": "Dog"},
	{"spanishWord": "Gato", "englishWord": "Cat"},
	{"spanishWord": "Agua", "englishWord": "Water"},
	{"spanishWord": "Libro", "englishWord": "Book"},
]


func _ready() -> void:
	# PlayerState loads before this autoload, and emits state_loaded again after F8.
	PlayerState.state_loaded.connect(dictionary_changed.emit)


func get_words() -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	for item in _entries():
		if item is Dictionary and item.has("spanishWord"):
			words.append(item.duplicate())
	return words


func get_word_count() -> int:
	return get_words().size()


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
	_entries().append(entry)
	PlayerState.save_game()
	word_added.emit(entry)
	dictionary_changed.emit()
	return true


## Same as add_word, for an entry from a level JSON "dictionary" array. Accepts either key style:
##   { "spanish": "Hola", "english": "Hello", "partOfSpeech": "interjection" }
##   { "spanishWord": "Hola", "englishWord": "Hello" }
func add_level_entry(level_entry: Dictionary) -> bool:
	return add_word(
		str(level_entry.get("spanish", level_entry.get("spanishWord", ""))),
		str(level_entry.get("english", level_entry.get("englishWord", ""))),
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

## Adds the next debug sample word that isn't saved yet, the same way dialogue does (no prompt).
func debug_add_sample_word() -> void:
	for item in DEBUG_SAMPLE_WORDS:
		if not has_word(str(item["spanishWord"])):
			add_level_entry(item)
			return


## Empties the dictionary. F8 (reset progress) does the same, since new players start blank.
func debug_clear() -> void:
	_entries().clear()
	PlayerState.save_game()
	dictionary_changed.emit()


# --- Internals ---

## The live word list inside PlayerState. Edits to it are saved by PlayerState.save_game().
func _entries() -> Array:
	if not PlayerState.dictionary.get("dictionary") is Array:
		PlayerState.dictionary["dictionary"] = []
	return PlayerState.dictionary["dictionary"]


func _index_of(spanish: String) -> int:
	var wanted := spanish.strip_edges().to_lower()
	var words := _entries()
	for i in words.size():
		if words[i] is Dictionary and str(words[i].get("spanishWord", "")).to_lower() == wanted:
			return i
	return -1
