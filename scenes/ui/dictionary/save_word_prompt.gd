extends PanelContainer
## "Do you want to save this word to your dictionary?" popup.
##
## Interactions never talk to this directly. They call
##   DictionaryManager.offer_word("Hola", "Hello", "interjection")
## and this prompt (living in dictionary_hud.tscn) picks it up. Offers made while the
## prompt is open are queued, so a dialogue that teaches 3 words asks 3 times in a row.

signal answered(entry: Dictionary, saved: bool)

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}

@onready var _word_label: Label = %WordLabel


func _ready() -> void:
	hide()
	%SaveButton.pressed.connect(_answer.bind(true))
	%SkipButton.pressed.connect(_answer.bind(false))
	DictionaryManager.word_offered.connect(_enqueue)


func _enqueue(entry: Dictionary) -> void:
	var spanish := str(entry.get("spanishWord", ""))
	if _is_pending(spanish):
		return
	_queue.append(entry)
	if _current.is_empty():
		_show_next()


func _is_pending(spanish: String) -> bool:
	var wanted := spanish.to_lower()
	if not _current.is_empty() and str(_current.get("spanishWord", "")).to_lower() == wanted:
		return true
	for queued in _queue:
		if str(queued.get("spanishWord", "")).to_lower() == wanted:
			return true
	return false


func _show_next() -> void:
	if _queue.is_empty():
		_current = {}
		hide()
		return
	_current = _queue.pop_front()
	_word_label.text = "%s  -  %s" % [_current.get("spanishWord", ""), _current.get("englishWord", "")]
	show()


func _answer(saved: bool) -> void:
	var entry := _current
	if saved:
		DictionaryManager.add_word(
			str(entry.get("spanishWord", "")),
			str(entry.get("englishWord", "")),
			str(entry.get("partOfSpeech", ""))
		)
	answered.emit(entry, saved)
	_show_next()
