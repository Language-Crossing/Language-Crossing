extends Node
## Decides what happens when a fish is hooked (a good press on the timing bar).
##
## Usually the player has to translate a word to land it: the Spanish word is shown and the
## English is typed into the translation box (translation_challenge.tscn), with a couple of
## tries. Right lands the fish, wrong lets it get away. Words come from the dictionary, and
## words the player has missed come up more often: right/wrong counts per word are saved
## under PlayerState.minigames["fishing"]["words"].
##
## Some catches instead carry a fishing-only word (scripts/levels/content/fishing.json):
## the fish is landed and the word is shown with its meaning in the shared dialogue box,
## then offered through the "Save this word?" prompt. A word the player skips stays new
## and is offered again on a later catch; once saved, it is quizzed like any other word.
##
## The teach card talks to the dialogue box (scenes/ui/dialogue_ui.tscn) the same way
## base_level.gd does: the same three signals plus choose_dialogue_option() and
## close_dialogue(). Fishing gives no XP and changes no story progress.

signal dialogue_started(context: Dictionary)
signal dialogue_choice_resolved(result: Dictionary)
signal dialogue_closed

const SPEAKER := "Fishing"
## Not "quiz", so the dialogue box shows Continue rather than "Try again".
const KIND := "fishing"
const SOURCE := "fishing"
const FISHING_WORDS_PATH := "res://scripts/levels/content/fishing.json"

@export var fishing_game_path: NodePath = NodePath("../CanvasLayer/FishingGame")
@export var challenge_path: NodePath = NodePath("../TranslationChallenge")
## Chance that a catch teaches a new fishing word instead of asking a review question.
@export_range(0.0, 1.0) var new_word_chance := 0.35
## How many tries the player gets at the translation before the fish gets away.
@export var translation_attempts := 2

var _current_word: Dictionary = {}
var _teaching := false
var _last_word := ""
var _fishing_words: Array[Dictionary] = []
var _fishing_game: Node
var _challenge: Node


func _ready() -> void:
	_load_fishing_words()
	_fishing_game = get_node_or_null(fishing_game_path)
	_challenge = get_node_or_null(challenge_path)
	if _fishing_game == null or _challenge == null:
		push_error("FishingQuiz needs the fishing bar (%s) and translation box (%s)" % [fishing_game_path, challenge_path])
		return
	_fishing_game.fish_hooked.connect(_on_fish_hooked)
	_challenge.finished.connect(_on_translation_finished)


func _on_fish_hooked() -> void:
	ask_question()


## Teaches a new fishing word or asks for a translation. Lands the fish straight away when
## there is nothing to ask. Returns "teach", "translate" or "" (nothing asked).
func ask_question() -> String:
	var known := _translatable(_known_words())
	var new_words := _unlearned_fishing_words()
	if not new_words.is_empty() and (known.size() < 2 or randf() < new_word_chance):
		_land(true)
		_teach(new_words.pick_random())
		return "teach"
	if known.is_empty():
		_land(true)
		return ""

	_teaching = false
	# Don't ask the same word twice in a row when there is a choice.
	if known.size() > 1:
		known = known.filter(func(word): return str(word["spanishWord"]) != _last_word)
	_current_word = _pick_weighted(known)
	_last_word = str(_current_word["spanishWord"])
	_challenge.start(_current_word, _fishing_game.fish_target.texture, translation_attempts)
	return "translate"


func _on_translation_finished(correct: bool) -> void:
	if _current_word.is_empty():
		return
	_record_answer(str(_current_word.get("spanishWord", "")), correct)
	_current_word = {}
	_land(correct)


func _land(caught: bool) -> void:
	if _fishing_game != null and _fishing_game.is_waiting_for_hook():
		_fishing_game.land_fish(caught)


func _teach(word: Dictionary) -> void:
	_teaching = true
	_current_word = word
	var question := "You caught a fish with a new word on it!\n\"%s\" means \"%s\"." % [
		word.get("spanishWord", ""), word.get("englishWord", "")]
	var dialogue := {"kind": KIND, "question": question, "options": [{"optionText": "Got it!", "isAnswer": true}]}
	dialogue_started.emit({"npcName": SPEAKER, "dialogue": dialogue, "completed": false})


func choose_dialogue_option(option_index: int) -> Dictionary:
	if not _teaching or option_index != 0:
		return {}
	# An empty response makes the dialogue box close straight away.
	var taught := {"response": "", "isCorrect": true, "nextDialogue": {}, "completed": true}
	dialogue_choice_resolved.emit(taught)
	return taught


func close_dialogue() -> void:
	if _teaching and not _current_word.is_empty():
		# Offered after the card closes so the prompt isn't stacked on top of it.
		DictionaryManager.offer_word(
			str(_current_word.get("spanishWord", "")),
			str(_current_word.get("englishWord", "")),
			str(_current_word.get("partOfSpeech", "")),
			SOURCE
		)
	_teaching = false
	_current_word = {}
	dialogue_closed.emit()


## Missed words are more likely, well-known ones less: weight = (1 + 2 x wrong) / (1 + right).
func _pick_weighted(words: Array[Dictionary]) -> Dictionary:
	var weights: Array[float] = []
	var total := 0.0
	for word in words:
		var weight := word_weight(str(word.get("spanishWord", "")))
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in words.size():
		roll -= weights[i]
		if roll <= 0.0:
			return words[i]
	return words.back()


func word_weight(spanish: String) -> float:
	var stats := word_stats(spanish)
	return (1.0 + 2.0 * stats["wrong"]) / (1.0 + stats["right"])


## Read-only: asking about a word never adds anything to the save.
func word_stats(spanish: String) -> Dictionary:
	var data: Variant = PlayerState.minigames.get(SOURCE, {})
	var words: Variant = data.get("words", {}) if data is Dictionary else {}
	var saved: Variant = words.get(spanish.to_lower(), {}) if words is Dictionary else {}
	if not saved is Dictionary:
		saved = {}
	return {"right": int(saved.get("right", 0)), "wrong": int(saved.get("wrong", 0))}


func _record_answer(spanish: String, is_correct: bool) -> void:
	var stats := word_stats(spanish)
	stats["right" if is_correct else "wrong"] += 1
	_all_word_stats()[spanish.to_lower()] = stats
	PlayerState.save_game()


func _all_word_stats() -> Dictionary:
	var data: Dictionary = PlayerState.get_minigame_data(SOURCE)
	if not data.get("words") is Dictionary:
		data["words"] = {}
	return data["words"]


func _known_words() -> Array[Dictionary]:
	return DictionaryManager.get_words()


## Only words with an English side can be typed.
func _translatable(words: Array[Dictionary]) -> Array[Dictionary]:
	return words.filter(func(word):
		return not str(word.get("spanishWord", "")).strip_edges().is_empty() \
			and not str(word.get("englishWord", "")).strip_edges().is_empty())


func _unlearned_fishing_words() -> Array[Dictionary]:
	return _fishing_words.filter(func(word): return not DictionaryManager.has_word(str(word["spanishWord"])))


func _load_fishing_words() -> void:
	var data: Variant = ConfigHelpers.read_json(FISHING_WORDS_PATH, {})
	var words: Variant = data.get("words", []) if data is Dictionary else []
	for item in words:
		if not item is Dictionary:
			continue
		var spanish := str(item.get("spanish", "")).strip_edges()
		var english := str(item.get("english", "")).strip_edges()
		if spanish.is_empty() or english.is_empty():
			continue
		_fishing_words.append({
			"spanishWord": spanish,
			"englishWord": english,
			"partOfSpeech": str(item.get("partOfSpeech", "")),
			"source": SOURCE
		})
