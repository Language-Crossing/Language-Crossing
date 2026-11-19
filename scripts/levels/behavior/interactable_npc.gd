class_name InteractableNPC
extends "res://scenes/characters/character.gd"

signal interacted(npc_id: StringName)

const GROUP := &"interactable_npcs"
## Above the name label (character.tscn's NameLabel spans y -43 to -27), so the key never covers the name.
const PROMPT_OFFSET := Vector2(0, -52)

@export var npc_id: StringName = &""
@export var interact_radius: float = 30.0

var player_in_range: bool = false
var interact_area: Area2D

var _player: Node2D
var _cue: InteractCue

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	add_to_group(InteractCue.GROUP)
	_create_interact_area()
	_cue = InteractCue.new()
	_cue.outline_target = get_node("Sprites")
	_cue.prompt_offset = PROMPT_OFFSET
	add_child(_cue)

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


func _process(_delta: float) -> void:
	_cue.set_shown(is_target() and not MovementBlockers.is_blocking(get_tree()))


## True when the player is in range and this is the closest NPC or task item that is.
func is_target() -> bool:
	return InteractCue.is_nearest(self)


func distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func is_cue_visible() -> bool:
	return _cue.is_shown()
