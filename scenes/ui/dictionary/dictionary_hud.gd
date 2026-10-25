extends CanvasLayer
## Always-on dictionary UI: corner book button + open-book viewer + "save this word?" prompt.
## Drop one instance of dictionary_hud.tscn into any level scene.
##
## Debug builds only (so you can test without any interactions existing yet):
##   F9  - offer the next sample word (shows the save prompt)
##   F10 - clear the saved dictionary

@onready var _button: BaseButton = %DictionaryButton
@onready var _book: Control = %DictionaryBook


func _ready() -> void:
	_button.pressed.connect(_book.open)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			DictionaryManager.debug_offer_sample_word()
		elif event.keycode == KEY_F10:
			DictionaryManager.debug_clear()
