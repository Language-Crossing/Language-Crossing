class_name InteractableNPC
extends "res://scenes/characters/character.gd"

signal interacted(npc_id: StringName)

const GROUP := &"interactable_npcs"
const OUTLINE_SHADER := preload("res://scenes/characters/outline_group.gdshader")
const KEY_CAP_TEXTURE := preload("res://assets/tilesets/Sprout Lands - UI Pack - Basic pack/Sprite sheets/buttons/Small Square Buttons.png")
const KEY_CAP_REGION := Rect2(0, 32, 16, 16)
const PROMPT_FONT := preload("res://assets/Fonts/pixel-game/Pixel Game.otf")
## Above the name label (character.tscn's NameLabel spans y -43 to -27), so the key never covers the name.
const PROMPT_OFFSET := Vector2(0, -52)

@export var npc_id: StringName = &""
@export var interact_radius: float = 30.0

var player_in_range: bool = false
var interact_area: Area2D

var _player: Node2D
var _targeted := false
var _prompt: Node2D
var _outline: ShaderMaterial
var _time := 0.0

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	_create_interact_area()
	_create_cue()

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

		# Only the NPC showing the cue answers, so E always talks to the highlighted one.
		if is_target():
			interacted.emit(npc_id)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var targeted := is_target() and not MovementBlockers.is_blocking(get_tree())
	if targeted != _targeted:
		_set_cue_visible(targeted)
	if _targeted:
		# A gentle one-pixel bob so the prompt catches the eye.
		_time += delta
		_prompt.position = PROMPT_OFFSET + Vector2(0, round(sin(_time * 3.0)))


## True when the player is in range and this is the closest NPC that is.
func is_target() -> bool:
	if not player_in_range:
		return false
	var my_distance := distance_to_player()
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or not other.player_in_range:
			continue
		var other_distance: float = other.distance_to_player()
		if other_distance < my_distance or (other_distance == my_distance and other.get_instance_id() < get_instance_id()):
			return false
	return true


func distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func is_cue_visible() -> bool:
	return _targeted


## The "E" key above the head plus a white outline around the whole character.
func _create_cue() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER

	_prompt = Node2D.new()
	_prompt.name = "InteractPrompt"
	_prompt.position = PROMPT_OFFSET
	_prompt.z_index = 10
	_prompt.visible = false
	add_child(_prompt)

	var key_cap := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = KEY_CAP_TEXTURE
	atlas.region = KEY_CAP_REGION
	key_cap.texture = atlas
	key_cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prompt.add_child(key_cap)

	# Drawn at double size and scaled down, so the letter stays crisp at the level's 2x zoom.
	var letter := Label.new()
	letter.text = "E"
	letter.add_theme_font_override("font", PROMPT_FONT)
	letter.add_theme_font_size_override("font_size", 20)
	letter.add_theme_color_override("font_color", Color(0.29, 0.16, 0.06))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.size = Vector2(32, 32)
	letter.scale = Vector2(0.5, 0.5)
	letter.position = Vector2(-8, -9)
	_prompt.add_child(letter)


func _set_cue_visible(on: bool) -> void:
	_targeted = on
	_prompt.visible = on
	_time = 0.0
	var sprites: CanvasItem = get_node("Sprites")
	if on:
		# One art pixel thick, whatever the level's zoom is.
		_outline.set_shader_parameter("line_thickness", get_global_transform_with_canvas().get_scale().x)
		sprites.material = _outline
	else:
		sprites.material = null
