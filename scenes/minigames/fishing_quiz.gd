extends Node
## Asks a word question each time a fish is caught.
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

@export var fishing_game_path: NodePath = NodePath("../CanvasLayer/FishingGame")

var _current_word: Dictionary = {}
var _current_options: Array = []


func _ready() -> void:
	var fishing_game := get_node_or_null(fishing_game_path)
	if fishing_game == null:
		push_error("FishingQuiz could not find the fishing bar at %s" % fishing_game_path)
		return
	fishing_game.fish_caught.connect(_on_fish_caught)


func _on_fish_caught() -> void:
	ask_question()


## Shows a question about a known word. Returns false when there aren't enough words yet.
func ask_question() -> bool:
	var words := _known_words()
	if words.is_empty():
		return false
	_current_word = words.pick_random()
	var dialogue := _build_question(_current_word, words)
	if dialogue.is_empty():
		return false
	dialogue_started.emit({"npcName": SPEAKER, "dialogue": dialogue, "completed": false})
	return true


func choose_dialogue_option(option_index: int) -> Dictionary:
	if _current_word.is_empty() or option_index < 0 or option_index >= _current_options.size():
		return {}
	var is_correct := bool(_current_options[option_index].get("isAnswer", false))
	var spanish := str(_current_word.get("spanishWord", ""))
	var english := str(_current_word.get("englishWord", ""))
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
	_current_word = {}
	_current_options = []
	dialogue_closed.emit()


func _known_words() -> Array[Dictionary]:
	return DictionaryManager.get_words()


## Half the questions go Spanish -> English, half English -> Spanish.
func _build_question(word: Dictionary, pool: Array[Dictionary]) -> Dictionary:
	var to_english := randf() < 0.5
	var answer_key := "englishWord" if to_english else "spanishWord"
	var answer := str(word.get(answer_key, ""))
	if answer.is_empty():
		return {}

	var used := {answer.to_lower(): true}
	_current_options = [{"optionText": answer, "isAnswer": true}]
	var others := pool.duplicate()
	others.shuffle()
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
