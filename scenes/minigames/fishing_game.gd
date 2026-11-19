extends Control

signal fish_caught
signal fish_missed

const TranslationChallengeScene := preload("res://scenes/minigames/translation_challenge.tscn")

@onready var fishing_bar = $FishingBar
@onready var fish_target = $FishingBar/FishTarget
@onready var moving_indicator = $FishingBar/MovingIndicator
@onready var result_label = $ResultLabel

@export var min_indicator_speed: float = 200.0
@export var max_indicator_speed: float = 400.0
## How many tries the player gets at the translation before the fish gets away.
@export var translation_attempts: int = 2

var indicator_speed: float = 300.0
var indicator_direction: float = 1.0
var minigame_active := false

var _challenge: Node = null
var _last_word := ""

func _ready():
	visible = false

func start_minigame():
	visible = true
	minigame_active = true
	result_label.text = ""
	
	var bar_width: float = fishing_bar.size.x
	var fish_width: float = fish_target.size.x
	
	fish_target.position.x = randf_range(
		40.0,
		maxf(40.0, bar_width - fish_width - 35.0)
	)
	
	indicator_speed = randf_range(
		min_indicator_speed,
		max_indicator_speed
	)
	
	moving_indicator.position.x = 40.0
	indicator_direction = 1.0
	
func _process(delta):
	if not minigame_active:
		return
	
	var max_x: float = fishing_bar.size.x - moving_indicator.size.x
	
	moving_indicator.position.x += (
		indicator_direction * indicator_speed * delta
	)
	
	if moving_indicator.position.x >= (max_x - 35.0):
		moving_indicator.position.x = (max_x - 35.0)
		indicator_direction = -1.0
	elif moving_indicator.position.x <= 40.0:
		moving_indicator.position.x = 40.0
		indicator_direction = 1.0
	
func _unhandled_input(event: InputEvent):
	if not minigame_active:
		return
		
	if event.is_action_pressed("interact") and not event.is_echo():
		check_result()
		get_viewport().set_input_as_handled()

func check_result():
	if not minigame_active:
		return
		
	minigame_active = false
	
	var indicator_rect := Rect2(
		moving_indicator.position,
		moving_indicator.size
		)
	
	var fish_rect := Rect2(
		fish_target.position,
		fish_target.size
		)
	
	if indicator_rect.intersects(fish_rect):
		# The fish is on the hook. Now the player has to translate a word to land it.
		_start_translation()
	else:
		result_label.text = "The fish got away!"
		fish_missed.emit()

func _start_translation():
	var entry := _pick_entry()
	if entry.is_empty():
		# Nothing in the dictionary yet, so there is nothing to ask. Catch it as before.
		_on_challenge_finished(true)
		return
	
	if _challenge == null:
		_challenge = TranslationChallengeScene.instantiate()
		_challenge.finished.connect(_on_challenge_finished)
		# Added next to this node (not under it) so it isn't shrunk by this node's scale.
		get_parent().add_child(_challenge)
	
	_last_word = str(entry["spanishWord"])
	result_label.text = "Translate it to land the fish!"
	_challenge.start(entry, fish_target.texture, translation_attempts)

## Random saved word that has both a Spanish and English side. Avoids repeating the previous
## word when there is more than one to choose from. Returns {} if none are usable.
func _pick_entry() -> Dictionary:
	var usable: Array[Dictionary] = []
	for word in DictionaryManager.get_words():
		if not str(word.get("englishWord", "")).strip_edges().is_empty():
			usable.append(word)
	
	if usable.size() > 1:
		usable = usable.filter(
			func(word: Dictionary) -> bool: return str(word["spanishWord"]) != _last_word
		)
	
	if usable.is_empty():
		return {}
	return usable.pick_random()

func _on_challenge_finished(correct: bool):
	if correct:
		result_label.text = "Fish caught!"
		fish_caught.emit()
	else:
		result_label.text = "The fish got away!"
		fish_missed.emit()
		
func close_minigame():
	minigame_active = false
	visible = false
	if _challenge != null:
		_challenge.close()
