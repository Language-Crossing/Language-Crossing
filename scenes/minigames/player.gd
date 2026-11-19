extends CharacterBody2D

const FISH_TEXTURE := preload("res://assets/tilesets/fishingbar/fish.png")
const EXCLAMATION_FONT := preload("res://assets/Fonts/berkshireSwash/BerkshireSwash-Regular.ttf")

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var tool_sprite = $Tool2D
@onready var fishing_minigame = \
	get_node("/root/WorldRoot/CanvasLayer/FishingGame")

const SPEED := 100.0

## Where the "!" sits relative to the player's origin (center of the mark).
@export var exclamation_offset := Vector2(0, -15)
@export var exclamation_font_size := 12
## Scene that Esc returns to (level_select.tscn). A uid:// path keeps working if the file moves.
@export var level_select_scene: String = "uid://b7orecicnhfvb"
## Width of the caught fish shown above the player, in the player's own units. Its height
## follows from the picture's proportions. The fish appears where the "!" does.
@export var caught_fish_width := 15.0

enum FishingState {
	IDLE,
	CASTING,
	WAITING,
	BITE,
	REELING,
	CAUGHT,
	FAILED
}

var fishing_state = FishingState.IDLE
var can_fish := false
var facing_direction := Vector2.DOWN
var current_fishing_spot: Area2D = null

## Bumped every time fishing ends. The cast/wait/bite steps below are coroutines (await),
## so each one remembers the session it started in and quietly stops if it has changed.
## Without this, a cancelled cast's timers would still fire and wreck the next cast.
var _fishing_session := 0

var _exclamation: Label
var _exclamation_base_y := 0.0
var _exclamation_tween: Tween
var _caught_fish: Sprite2D
var _caught_fish_tween: Tween

func _physics_process(_delta: float) -> void:
	if fishing_state != FishingState.IDLE:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(
	"ui_left",
	"ui_right",
	"ui_up",
	"ui_down"
	)

	velocity = direction * SPEED
	
	if direction != Vector2.ZERO:
		facing_direction = direction
		
		if current_fishing_spot != null:
			update_tool_direction()
		
		animated_sprite_2d.play("walking")
		animated_sprite_2d.flip_h = direction.x < 0
	else:
		animated_sprite_2d.play("idle")
		
	tool_sprite.visible = false
	
	move_and_slide()

# _input (not _unhandled_input) on purpose: the translation prompt's text box would swallow Esc.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		leave_minigame()

## Back to the level select screen from any fishing state.
func leave_minigame() -> void:
	print("returning to level select")
	get_tree().change_scene_to_file(level_select_scene)

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()

func _on_interact_pressed() -> void:
	match fishing_state:
		FishingState.IDLE:
			if can_fish:
				start_fishing()
		FishingState.CASTING, FishingState.WAITING:
			# Pressing again before anything bites reels the line back in.
			cancel_fishing()
		FishingState.BITE:
			start_reeling()
			
func position_fishing_minigame() -> void:
	var screen_position = get_global_transform_with_canvas().origin
	fishing_minigame.global_position = screen_position + Vector2(-150, -70)

func update_tool_direction() -> void:
	if current_fishing_spot == null:
		return
	
	var spot_name: String = current_fishing_spot.get_parent().name
	match spot_name:
		"FishingSpot1":
			tool_sprite.rotation_degrees = 0
			tool_sprite.flip_v = false
			tool_sprite.flip_h = false
		"FishingSpot2":
			tool_sprite.rotation_degrees = 0
			tool_sprite.flip_v = false
			tool_sprite.flip_h = facing_direction.x < 0
		"FishingSpot3":
			tool_sprite.rotation_degrees = -110
			tool_sprite.flip_v = facing_direction.x < 0
			tool_sprite.flip_h = false
		"FishingSpot4":
			tool_sprite.rotation_degrees = 0
			tool_sprite.flip_v = false
			tool_sprite.flip_h = facing_direction.x < 0
	
func start_fishing():
	fishing_state = FishingState.CASTING
	var session := _fishing_session
	tool_sprite.visible = true
	update_tool_direction()
	velocity = Vector2.ZERO

	animated_sprite_2d.play("casting")
	tool_sprite.play("casting")

	await animated_sprite_2d.animation_finished
	if session != _fishing_session:
		return

	start_waiting()


func start_waiting():
	fishing_state = FishingState.WAITING
	var session := _fishing_session

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")

	var wait_time = randf_range(2.0, 5.0)

	await get_tree().create_timer(wait_time).timeout
	if session != _fishing_session:
		return

	fish_bites()


func fish_bites():
	fishing_state = FishingState.BITE
	var session := _fishing_session

	print("A fish is biting!")
	_set_exclamation_visible(true)

	var bite_window = 1.5

	await get_tree().create_timer(bite_window).timeout
	if session != _fishing_session:
		return

	if fishing_state == FishingState.BITE:
		fail_fishing()


func start_reeling():
	fishing_state = FishingState.REELING
	_set_exclamation_visible(false)

	animated_sprite_2d.play("reeling")
	tool_sprite.play("reeling")
	
	position_fishing_minigame()

	fishing_minigame.start_minigame()

func _ready():
	_create_exclamation()
	_create_caught_fish()
	fishing_minigame.fish_caught.connect(catch_fish)
	fishing_minigame.fish_missed.connect(fail_fishing)

func catch_fish():
	fishing_minigame.close_minigame()
	fishing_state = FishingState.CAUGHT

	animated_sprite_2d.play("caught")
	tool_sprite.play("caught")

	print("FISH CAUGHT!")
	_show_caught_fish(true)

	await animated_sprite_2d.animation_finished

	end_fishing()


func fail_fishing():
	fishing_state = FishingState.FAILED

	print("The fish got away!")

	end_fishing()


## Player backed out before a fish bit.
func cancel_fishing():
	print("Reeled the line back in.")
	end_fishing()


func end_fishing():
	_fishing_session += 1
	_set_exclamation_visible(false)
	_show_caught_fish(false)
	fishing_minigame.close_minigame()
	fishing_state = FishingState.IDLE

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")


# --- "!" bite indicator ---

func _create_exclamation() -> void:
	_exclamation = Label.new()
	_exclamation.text = "!"
	_exclamation.add_theme_font_override("font", EXCLAMATION_FONT)
	_exclamation.add_theme_font_size_override("font_size", exclamation_font_size)
	_exclamation.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_exclamation.add_theme_color_override("font_outline_color", Color.WHITE)
	_exclamation.add_theme_constant_override("outline_size", 3)
	_exclamation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exclamation.custom_minimum_size = Vector2(exclamation_font_size, exclamation_font_size + 4)
	_exclamation.position = exclamation_offset - _exclamation.custom_minimum_size / 2.0
	_exclamation.z_index = 10
	_exclamation.visible = false
	_exclamation_base_y = _exclamation.position.y
	add_child(_exclamation)


func _set_exclamation_visible(enabled: bool) -> void:
	if _exclamation_tween != null:
		_exclamation_tween.kill()
		_exclamation_tween = null
	_exclamation.visible = enabled
	_exclamation.position.y = _exclamation_base_y
	if enabled:
		# Small hop so it catches the eye.
		_exclamation_tween = create_tween().set_loops()
		_exclamation_tween.tween_property(_exclamation, "position:y", _exclamation_base_y - 3.0, 0.15)
		_exclamation_tween.tween_property(_exclamation, "position:y", _exclamation_base_y, 0.15)


# --- Caught fish shown above the player ---

func _create_caught_fish() -> void:
	_caught_fish = Sprite2D.new()
	_caught_fish.texture = FISH_TEXTURE
	_caught_fish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_caught_fish.z_index = 10
	_caught_fish.visible = false
	add_child(_caught_fish)


func _show_caught_fish(enabled: bool) -> void:
	if _caught_fish_tween != null:
		_caught_fish_tween.kill()
		_caught_fish_tween = null
	_caught_fish.visible = enabled
	if not enabled:
		return

	var final_scale := Vector2.ONE * (caught_fish_width / float(FISH_TEXTURE.get_width()))
	_caught_fish.position = exclamation_offset
	_caught_fish.scale = Vector2.ZERO
	# Pop in with a little overshoot.
	_caught_fish_tween = create_tween()
	_caught_fish_tween.tween_property(_caught_fish, "scale", final_scale, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
