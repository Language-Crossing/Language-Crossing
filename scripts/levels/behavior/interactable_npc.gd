class_name InteractableNPC
extends "res://scenes/characters/character.gd"

signal interacted(npc_id: StringName)

const GROUP := &"interactable_npcs"
## Above the name label (character.tscn's NameLabel spans y -43 to -27), so the key never covers the name.
const PROMPT_OFFSET := Vector2(0, -52)
## Standing frame for each facing on the character sheets (first column of rows 0-3).
const STAND_FRAMES := {"down": 0, "up": 8, "right": 16, "left": 24}

@export var npc_id: StringName = &""
@export var interact_radius: float = 30.0
@export_group("Looking around")
## Which way the NPC faces when not looking around.
@export_enum("down", "up", "left", "right") var rest_facing := "down"
## Seconds between glances, picked at random in this range.
@export var glance_interval := Vector2(3.0, 7.0)
## How long each glance lasts.
@export var glance_duration := Vector2(1.0, 2.2)

var player_in_range: bool = false
var interact_area: Area2D

var _player: Node2D
var _cue: InteractCue
var facing := "down"
var _glance_timer := 0.0
var _glancing := false

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	add_to_group(InteractCue.GROUP)
	_create_interact_area()
	_cue = InteractCue.new()
	_cue.outline_target = get_node("Sprites")
	_cue.prompt_offset = PROMPT_OFFSET
	add_child(_cue)
	# The sheets have no idle animation, so NPCs stand still and look around instead.
	anim_player.stop()
	set_facing(rest_facing)
	# Start each NPC partway through, so they don't all glance at the same moment.
	_glance_timer = randf_range(0.5, glance_interval.y)

func _create_interact_area() -> void:
	interact_area = Area2D.new()
	interact_area.name = "InteractArea"

	var shape_node = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = interact_radius
	shape_node.shape = circle_shape

	interact_area.add_child(shape_node)
	add_child(interact_area)

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("Player recognized!")
		player_in_range = true
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player left range.")
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	# Check if the button was pressed at all, regardless of range
	if event.is_action_pressed("interact"):
		print("Interact button pressed. Player in range? ", player_in_range) # DEBUG LINE

		# Only the thing showing the cue answers, so E always talks to the highlighted one.
		if is_target():
			interacted.emit(npc_id)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_cue.set_shown(is_target() and not MovementBlockers.is_blocking(get_tree()))
	_update_facing(delta)


## Turns to face the player while they're close; otherwise glances around now and then.
func _update_facing(delta: float) -> void:
	if player_in_range and is_instance_valid(_player):
		set_facing(_direction_to(_player.global_position))
		_glancing = false
		_glance_timer = randf_range(glance_interval.x, glance_interval.y)
		return
	_glance_timer -= delta
	if _glance_timer > 0.0:
		return
	if _glancing:
		_glancing = false
		set_facing(rest_facing)
		_glance_timer = randf_range(glance_interval.x, glance_interval.y)
	else:
		_glancing = true
		var options := STAND_FRAMES.keys().filter(func(d): return d != rest_facing)
		set_facing(options.pick_random())
		_glance_timer = randf_range(glance_duration.x, glance_duration.y)


func set_facing(direction: String) -> void:
	if direction == facing and body_sprite.frame == STAND_FRAMES[direction]:
		return
	facing = direction
	var frame: int = STAND_FRAMES[direction]
	body_sprite.frame = frame
	outfit_sprite.frame = frame
	head_sprite.frame = frame


func _direction_to(target: Vector2) -> String:
	var offset := target - global_position
	if absf(offset.x) > absf(offset.y):
		return "right" if offset.x > 0 else "left"
	return "down" if offset.y > 0 else "up"


## True when the player is in range and this is the closest NPC or task item that is.
func is_target() -> bool:
	return InteractCue.is_nearest(self)


func distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func is_cue_visible() -> bool:
	return _cue.is_shown()
