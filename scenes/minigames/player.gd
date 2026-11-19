extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var tool_sprite = $Tool2D
## Float bobbing and the "got away" message (scenes/minigames/fishing_cues.gd).
@onready var cues = $FishingCues
## Relative to the player, so the fishing scene can be renamed or rearranged.
@export var fishing_game_path: NodePath = NodePath("../CanvasLayer/FishingGame")
@onready var fishing_minigame = get_node(fishing_game_path)

const SPEED := 100.0

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

func _physics_process(_delta: float) -> void:
	if fishing_state != FishingState.IDLE:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Open questions, the dictionary and save prompts hold the player in place.
	var direction := Vector2.ZERO
	if not MovementBlockers.is_blocking(get_tree()):
		direction = Input.get_vector(
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

# An input event rather than polling Input: once the timing bar (or a text box) has used
# an E press, it doesn't reach here too. Polling saw the same press that missed the bar
# and immediately cast the line again.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if MovementBlockers.is_blocking(get_tree()):
		return
	if _on_interact_pressed():
		get_viewport().set_input_as_handled()

## Returns true if the press did something (so the timing bar doesn't also act on it).
func _on_interact_pressed() -> bool:
	match fishing_state:
		FishingState.IDLE:
			if can_fish:
				start_fishing()
				return true
		FishingState.CASTING, FishingState.WAITING:
			# Pressing again before anything bites reels the line back in.
			cancel_fishing()
			return true
		FishingState.BITE:
			start_reeling()
			return true
	return false

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
	cues.show_float()

	var wait_time = randf_range(2.0, 5.0)

	# false: the wait stops while the game is paused.
	await get_tree().create_timer(wait_time, false).timeout
	if session != _fishing_session:
		return

	fish_bites()


func fish_bites():
	fishing_state = FishingState.BITE
	var session := _fishing_session
	cues.start_bite()

	print("A fish is biting!")

	var bite_window = 1.5

	await get_tree().create_timer(bite_window, false).timeout
	if session != _fishing_session:
		return

	if fishing_state == FishingState.BITE:
		fail_fishing()


func start_reeling():
	fishing_state = FishingState.REELING
	cues.hide_float()

	animated_sprite_2d.play("reeling")
	tool_sprite.play("reeling")
	
	position_fishing_minigame()

	fishing_minigame.start_minigame()

func _ready():
	fishing_minigame.fish_caught.connect(catch_fish)
	fishing_minigame.fish_missed.connect(fail_fishing)

func catch_fish():
	fishing_minigame.close_minigame()
	fishing_state = FishingState.CAUGHT

	animated_sprite_2d.play("caught")
	tool_sprite.play("caught")

	print("FISH CAUGHT!")

	await animated_sprite_2d.animation_finished

	end_fishing()


func fail_fishing():
	fishing_state = FishingState.FAILED
	cues.show_message("The fish got away...")

	print("The fish got away!")

	end_fishing()


## Player reeled the line back in before a fish bit.
func cancel_fishing():
	print("Reeled the line back in.")
	end_fishing()


func end_fishing():
	_fishing_session += 1
	cues.hide_float()
	fishing_minigame.close_minigame()
	fishing_state = FishingState.IDLE

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")
