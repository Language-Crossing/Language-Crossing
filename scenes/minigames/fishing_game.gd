extends Control

## The fish was landed (or got away) and the minigame is over.
signal fish_caught
signal fish_missed
## The timing press was good. If anything listens to this, it decides whether the fish is
## landed (FishingQuiz asks a translation first) and then calls land_fish(). With no
## listener the fish is caught straight away.
signal fish_hooked

@onready var fishing_bar = $FishingBar
@onready var fish_target = $FishingBar/FishTarget
@onready var moving_indicator = $FishingBar/MovingIndicator
@onready var result_label = $ResultLabel

## How fast the green bar slides, in bar pixels per second; each cast picks a speed in
## this range. Raise both to make catching harder.
@export var min_indicator_speed: float = 320.0
@export var max_indicator_speed: float = 560.0

var indicator_speed: float = 400.0
var indicator_direction: float = 1.0
var minigame_active := false
var _waiting_for_hook := false

func _ready():
	visible = false

func start_minigame():
	visible = true
	minigame_active = true
	_waiting_for_hook = false
	result_label.text = ""

	var bar_width: float = fishing_bar.size.x
	var fish_width: float = fish_drawn_rect().size.x

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

## The fish as it is drawn (FishTarget is scaled down in the scene).
func fish_drawn_rect() -> Rect2:
	return Rect2(fish_target.position, fish_target.size * fish_target.scale)

## A catch needs the middle of the fish inside the green bar, not just any overlap.
func is_fish_in_bar() -> bool:
	var bar_rect := Rect2(moving_indicator.position, moving_indicator.size)
	var fish_center_x := fish_drawn_rect().get_center().x
	return fish_center_x >= bar_rect.position.x and fish_center_x <= bar_rect.end.x

func check_result():
	if not minigame_active:
		return

	minigame_active = false

	if is_fish_in_bar():
		if get_signal_connection_list("fish_hooked").is_empty():
			land_fish(true)
		else:
			_waiting_for_hook = true
			result_label.text = "Translate it to land the fish!"
			fish_hooked.emit()
	else:
		result_label.text = "The fish got away!"
		fish_missed.emit()

## Called once the hooked fish is decided (e.g. after the translation).
func land_fish(caught: bool) -> void:
	_waiting_for_hook = false
	if caught:
		result_label.text = "Fish caught!"
		fish_caught.emit()
	else:
		result_label.text = "The fish got away!"
		fish_missed.emit()

func is_waiting_for_hook() -> bool:
	return _waiting_for_hook

func close_minigame():
	minigame_active = false
	_waiting_for_hook = false
	visible = false
