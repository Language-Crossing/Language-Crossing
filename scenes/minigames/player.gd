extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var tool_sprite = $ToolAnimatedSprite2D

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
		animated_sprite_2d.play("walking")
		animated_sprite_2d.flip_h = direction.x < 0
	else:
		animated_sprite_2d.play("idle")
	
	move_and_slide()

func _process(_delta):
	if Input.is_action_just_pressed("interact"):

		if fishing_state == FishingState.IDLE:
			if can_fish:
				start_fishing()

		elif fishing_state == FishingState.BITE:
			start_reeling()

	elif fishing_state == FishingState.REELING:
		if Input.is_action_just_released("interact"):
			catch_fish()


func start_fishing():
	fishing_state = FishingState.CASTING

	velocity = Vector2.ZERO

	animated_sprite_2d.play("casting")
	tool_sprite.play("casting")

	await animated_sprite_2d.animation_finished

	start_waiting()


func start_waiting():
	fishing_state = FishingState.WAITING

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")

	var wait_time = randf_range(2.0, 5.0)

	await get_tree().create_timer(wait_time).timeout

	fish_bites()


func fish_bites():
	fishing_state = FishingState.BITE

	print("A fish is biting!")

	var bite_window = 1.5

	await get_tree().create_timer(bite_window).timeout

	if fishing_state == FishingState.BITE:
		fail_fishing()


func start_reeling():
	fishing_state = FishingState.REELING

	animated_sprite_2d.play("reeling")
	tool_sprite.play("reeling")

	print("REELING!")


func catch_fish():
	fishing_state = FishingState.CAUGHT

	animated_sprite_2d.play("caught")
	tool_sprite.play("caught")

	print("FISH CAUGHT!")

	await animated_sprite_2d.animation_finished

	end_fishing()


func fail_fishing():
	fishing_state = FishingState.FAILED

	print("The fish got away!")

	end_fishing()


func end_fishing():
	fishing_state = FishingState.IDLE

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")
