extends CanvasLayer
signal finished(correct: bool)

## How long the result (and the right answer) stays on screen before closing.
const RESULT_DELAY := 1.4
## Punctuation ignored when comparing answers.
const IGNORED_CHARS := "!?.¡¿\""
## Anything in (parentheses) is a note for the player, not part of the answer.
## e.g. "good (masculine plural)" is accepted as "good".
const PARENTHESES_PATTERN := "\\([^)]*\\)"
## Leading words ignored when comparing, so "the house" == "house" and "to run" == "run".
const IGNORED_PREFIXES := ["the ", "a ", "an ", "to "]

@onready var _fish: TextureRect = %FishTexture
@onready var _word_label: Label = %WordLabel
@onready var _pos_label: Label = %PartOfSpeechLabel
@onready var _answer: LineEdit = %AnswerEdit
@onready var _feedback: Label = %FeedbackLabel
@onready var _submit: Button = %SubmitButton

var _parentheses_regex := RegEx.create_from_string(PARENTHESES_PATTERN)
var _entry: Dictionary = {}
var _attempts_left := 0
var _active := false
## Bumped on every start()/close() so a pending result timer from an old round is ignored.
var _session := 0


func _ready() -> void:
	_answer.text_submitted.connect(func(_text: String) -> void: _submit_answer())
	_submit.pressed.connect(_submit_answer)


func start(entry: Dictionary, fish_texture: Texture2D, attempts: int = 1) -> void:
	_session += 1
	_entry = entry
	_attempts_left = maxi(1, attempts)
	_active = true

	_fish.texture = fish_texture
	_word_label.text = str(entry.get("spanishWord", ""))

	var part_of_speech := str(entry.get("partOfSpeech", ""))
	_pos_label.text = "(%s)" % part_of_speech
	_pos_label.visible = not part_of_speech.is_empty()

	_answer.text = ""
	_answer.editable = true
	_submit.disabled = false
	_feedback.text = _attempts_text()

	show()
	_answer.grab_focus.call_deferred()


## Closes without emitting `finished` (used if the minigame is cancelled from outside).
func close() -> void:
	_session += 1
	_active = false
	hide()


func _submit_answer() -> void:
	if not _active:
		return
	var guess := _normalize(_answer.text)
	if guess.is_empty():
		return

	if guess in _accepted_answers():
		_finish(true, "Correct!")
		return

	_attempts_left -= 1
	if _attempts_left <= 0:
		_finish(false, "Not quite!")
	else:
		_feedback.text = "Not quite, try again!  %s" % _attempts_text()
		_answer.select_all()
		_answer.grab_focus()


func _finish(correct: bool, message: String) -> void:
	_active = false
	_answer.editable = false
	_submit.disabled = true
	_feedback.text = "%s\n%s = %s" % [
		message,
		str(_entry.get("spanishWord", "")),
		str(_entry.get("englishWord", "")),
	]

	var session := _session
	await get_tree().create_timer(RESULT_DELAY).timeout
	if session != _session:
		return # closed or restarted while we were waiting

	hide()
	finished.emit(correct)


func _attempts_text() -> String:
	return "%d attempt%s left" % [_attempts_left, "" if _attempts_left == 1 else "s"]


func _accepted_answers() -> Array[String]:
	# Strip notes first so commas inside them don't split the answer.
	var raw := _strip_parentheses(str(_entry.get("englishWord", "")))
	var accepted: Array[String] = []

	var whole := _normalize(raw)
	if not whole.is_empty():
		accepted.append(whole)

	for part in raw.replace(";", "/").replace(",", "/").split("/"):
		var normalized := _normalize(part)
		if not normalized.is_empty() and normalized not in accepted:
			accepted.append(normalized)
	return accepted


func _strip_parentheses(text: String) -> String:
	return _parentheses_regex.sub(text, "", true)


func _normalize(text: String) -> String:
	var result := _strip_parentheses(text).strip_edges().to_lower()
	for character in IGNORED_CHARS:
		result = result.replace(character, "")
	# Collapse repeated spaces.
	result = " ".join(result.split(" ", false))
	for prefix in IGNORED_PREFIXES:
		if result.begins_with(prefix):
			result = result.trim_prefix(prefix).strip_edges()
			break
	return result
