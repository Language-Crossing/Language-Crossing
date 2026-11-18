extends Node
## Asks a word question each time a fish is caught.
##
## Questions are about words already in the dictionary, and words the player has
## missed come up more often: right/wrong counts per word are saved under
## PlayerState.minigames["fishing"]["words"]. Some catches instead carry a
## fishing-only word (scripts/levels/content/fishing.json): it is shown with its meaning,
## then offered through the "Save this word?" prompt. A word the player skips stays new
## and is offered again on a later catch; once saved, it is quizzed like any other word.
##
## It talks to the shared dialogue box (scenes/ui/dialogue_ui.tscn) the same way
## base_level.gd does: the same three signals plus choose_dialogue_option() and
## close_dialogue(), so the question gets the story's font, answer shuffling and
## movement lock for free. Fishing gives no XP and changes no story progress.

signal dialogue_started(context: Dictionary)
signal dialogue_choice_resolved(result: Dictionary)
signal dialogue_closed

const SPEAKER := "Fishing"
## Not "quiz": a wrong answer ends the question (the fish gets away) instead of
## offering "Try again", which is what dialogue_ui.gd does for "quiz".
const KIND := "fishing"
const OPTION_COUNT := 3
const SOURCE := "fishing"
const FISHING_WORDS_PATH := "res://scripts/levels/content/fishing.json"

@export var fishing_game_path: NodePath = NodePath("../CanvasLayer/FishingGame")
## Chance that a catch teaches a new fishing word instead of asking a review question.
@export_range(0.0, 1.0) var new_word_chance := 0.35

var _current_word: Dictionary = {}
var _current_options: Array = []
var _teaching := false
var _fishing_words: Array[Dictionary] = []


func _ready() -> void:
	_load_fishing_words()
	var fishing_game := get_node_or_null(fishing_game_path)
	if fishing_game == null:
		push_error("FishingQuiz could not find the fishing bar at %s" % fishing_game_path)
		return
	fishing_game.fish_caught.connect(_on_fish_caught)


func _on_fish_caught() -> void:
	ask_question()


## Teaches a new fishing word or asks about a known one. Returns false if there is nothing to ask.
func ask_question() -> bool:
	var known := _known_words()
	var new_words := _unlearned_fishing_words()
	if not new_words.is_empty() and (known.size() < 2 or randf() < new_word_chance):
		_teach(new_words.pick_random())
		return true
	if known.is_empty():
		return false

	_teaching = false
	_current_word = _pick_weighted(known)
	# Fishing words make good wrong answers even before they are learned.
	var dialogue := _build_question(_current_word, known + _fishing_words)
	if dialogue.is_empty():
		return false
	dialogue_started.emit({"npcName": SPEAKER, "dialogue": dialogue, "completed": false})
	return true


func _teach(word: Dictionary) -> void:
	_teaching = true
	_current_word = word
	_current_options = [{"optionText": "Got it!", "isAnswer": true}]
	var question := "You caught a fish with a new word on it!\n\"%s\" means \"%s\"." % [
		word.get("spanishWord", ""), word.get("englishWord", "")]
	var dialogue := {"kind": KIND, "question": question, "options": _current_options.duplicate(true)}
	dialogue_started.emit({"npcName": SPEAKER, "dialogue": dialogue, "completed": false})


func choose_dialogue_option(option_index: int) -> Dictionary:
	if _current_word.is_empty() or option_index < 0 or option_index >= _current_options.size():
		return {}
	var is_correct := bool(_current_options[option_index].get("isAnswer", false))
	if _teaching:
		# An empty response makes the dialogue box close straight away.
		var taught := {"response": "", "isCorrect": true, "nextDialogue": {}, "completed": true}
		dialogue_choice_resolved.emit(taught)
		return taught
	var spanish := str(_current_word.get("spanishWord", ""))
	var english := str(_current_word.get("englishWord", ""))
	_record_answer(spanish, is_correct)
	var response := ""
	if is_correct:
		response = "¡Correcto! You keep the fish. '%s' means '%s'." % [spanish, english]
	else:
		response = "The fish got away! '%s' means '%s'." % [spanish, english]
	var result := {
		"response": response,
		"isCorrect": is_correct,
		"nextDialogue": {},
		"completed": true
	}
	dialogue_choice_resolved.emit(result)
	return result


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
	_current_options = []
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


## Half the questions go Spanish -> English, half English -> Spanish.
func _build_question(word: Dictionary, pool: Array[Dictionary]) -> Dictionary:
	var to_english := randf() < 0.5
	var answer_key := "englishWord" if to_english else "spanishWord"
	var answer := str(word.get(answer_key, ""))
	if answer.is_empty():
		return {}

	var used := {answer.to_lower(): true}
	_current_options = [{"optionText": answer, "isAnswer": true}]
	# Wrong answers that look like the right one (same part of speech, and articles only
	# alongside other words with articles) so the answer can't be spotted by its shape.
	var others := pool.duplicate()
	others.shuffle()
	others.sort_custom(func(a, b): return _similarity(a, word) > _similarity(b, word))
	for other in others:
		if _current_options.size() >= OPTION_COUNT:
			break
		var text := str(other.get(answer_key, ""))
		if text.is_empty() or used.has(text.to_lower()):
			continue
		used[text.to_lower()] = true
		_current_options.append({"optionText": text, "isAnswer": false})
	if _current_options.size() < 2:
		return {}

	var question := ""
	if to_english:
		question = "You caught a fish! What does \"%s\" mean?" % word.get("spanishWord", "")
	else:
		question = "You caught a fish! How do you say \"%s\" in Spanish?" % word.get("englishWord", "")
	return {"kind": KIND, "question": question, "options": _current_options.duplicate(true)}


func _similarity(other: Dictionary, word: Dictionary) -> int:
	var score := 0
	if str(other.get("partOfSpeech", "")) == str(word.get("partOfSpeech", "")):
		score += 2
	if str(other.get("source", "")) == str(word.get("source", "")):
		score += 1
	return score
