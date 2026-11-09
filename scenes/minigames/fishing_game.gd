extends Control

signal fish_caught
signal fish_missed

@onready var fishing_bar = $FishingBar
@onready var fish_target = $FishingBar/FishTarget
@onready var moving_indicator = $FishingBar/MovingIndicator
@onready var result_label = $ResultLabel

@export var min_indicator_speed: float = 200.0
@export var max_indicator_speed: float = 400.0

var indicator_speed: float = 300.0
var indicator_direction: float = 1.0
var minigame_active := false

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
		result_label.text = "Fish caught!"
		fish_caught.emit()
	else:
		result_label.text = "The fish got away!"
		fish_missed.emit()
		
func close_minigame():
	minigame_active = false
	visible = false
