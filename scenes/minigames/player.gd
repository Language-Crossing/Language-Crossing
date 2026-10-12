extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var tool_sprite = $Tool2D
@onready var fishing_minigame = \
	get_node("/root/WorldRoot/CanvasLayer/FishingGame")

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

func _process(_delta):
	if Input.is_action_just_pressed("interact"):

		if fishing_state == FishingState.IDLE:
			if can_fish:
				start_fishing()

		elif fishing_state == FishingState.BITE:
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
	tool_sprite.visible = true
	update_tool_direction()
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

	print("The fish got away!")

	end_fishing()


func end_fishing():
	fishing_minigame.close_minigame()
	fishing_state = FishingState.IDLE

	animated_sprite_2d.play("idle")
	tool_sprite.play("idle")
