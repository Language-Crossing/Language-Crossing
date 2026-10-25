extends Control
## Open-book viewer for the player's saved words. Two pages per spread.
## Pages are blank until words are saved; they refresh on DictionaryManager.dictionary_changed.

signal closed

const ENTRIES_PER_PAGE := 5
const INK := Color("2b2d3c")
const INK_SOFT := Color("7a5a50")
const FONT := preload("res://assets/Fonts/berkshireSwash/BerkshireSwash-Regular.ttf")

var _spread := 0

@onready var _left_entries: VBoxContainer = %LeftEntries
@onready var _right_entries: VBoxContainer = %RightEntries
@onready var _left_number: Label = %LeftNumber
@onready var _right_number: Label = %RightNumber
@onready var _count_label: Label = %CountLabel
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	DictionaryManager.dictionary_changed.connect(_refresh)
	_prev_button.pressed.connect(_turn.bind(-1))
	_next_button.pressed.connect(_turn.bind(1))
	%CloseButton.pressed.connect(close)
	%Dim.gui_input.connect(_on_dim_gui_input)
	_refresh()


func open() -> void:
	_spread = 0
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _turn(direction: int) -> void:
	_spread += direction
	_refresh()


func _refresh() -> void:
	var words := DictionaryManager.get_words()
	var per_spread := ENTRIES_PER_PAGE * 2
	var spread_count := maxi(1, ceili(words.size() / float(per_spread)))
	_spread = clampi(_spread, 0, spread_count - 1)

	var start := _spread * per_spread
	_fill(_left_entries, words.slice(start, start + ENTRIES_PER_PAGE))
	_fill(_right_entries, words.slice(start + ENTRIES_PER_PAGE, start + per_spread))

	_left_number.text = str(_spread * 2 + 1)
	_right_number.text = str(_spread * 2 + 2)
	_count_label.text = "%d word%s" % [words.size(), "" if words.size() == 1 else "s"]
	_prev_button.disabled = _spread == 0
	_next_button.disabled = _spread >= spread_count - 1


func _fill(container: VBoxContainer, entries: Array) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for entry in entries:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", -2)
		row.add_child(_make_label(str(entry.get("spanishWord", "")), 20, INK))
		row.add_child(_make_label(str(entry.get("englishWord", "")), 14, INK_SOFT))
		container.add_child(row)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
