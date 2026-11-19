class_name InteractableObject
extends Node2D
## Something the player picks up for a task (e.g. Sofia's book).
##
## With item art set, the item only appears while its task is waiting for it to be found
## (base_level.gd calls set_task_stage()). In range it gets the same outline + "E" cue as
## NPCs; picking it up shows "You found ...!" and a small icon of it next to the player
## until it is handed over. Without item art it is an invisible spot that always answers E.

signal interacted(object_id: StringName, object_name: String)

const MESSAGE_FONT := preload("res://assets/Fonts/pixel-game/Pixel Game.otf")
const MESSAGE_SECONDS := 1.8
## Height of the carried icon, in art pixels.
const CARRIED_ICON_HEIGHT := 12.0
## Where the carried icon floats, relative to the player (art pixels): by the shoulder.
const CARRIED_ICON_OFFSET := Vector2(12, -14)

@export var object_id: StringName = &""
@export var object_name := "Object"
@export var interact_radius := 30.0
@export_group("Item art")
## Sheet the item is drawn from. Leave empty for an invisible interaction spot.
@export var item_texture: Texture2D
@export var item_region := Rect2()
## Shown when picked up: "You found <found_name>!", e.g. "el libro".
@export var found_name := ""

var player_in_range := false

## "" = not needed (hidden), "find" = waiting to be picked up, "deliver" = being carried,
## "completed" = handed over.
var task_stage := ""

var _player: Node2D
var _area: Area2D
var _item: CanvasGroup
var _cue: InteractCue
var _carried_icon: Sprite2D
var _message_layer: CanvasLayer
var _message: Label
var _message_tween: Tween
var _time := 0.0


func _ready() -> void:
	add_to_group(InteractCue.GROUP)
	_area = Area2D.new()
	_area.name = "InteractArea"
	_area.collision_layer = 0
	_area.collision_mask = 1

	var shape_node := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = interact_radius
	shape_node.shape = circle_shape
	_area.add_child(shape_node)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	if has_item_art():
		_create_item_visuals()
		_apply_stage()


func has_item_art() -> bool:
	return item_texture != null and item_region.has_area()


## Called by the level whenever this item's task changes. `announce` shows the
## "You found ...!" message when the item has just been picked up.
func set_task_stage(stage: String, announce: bool = false) -> void:
	var picked_up := task_stage == "find" and stage == "deliver"
	task_stage = stage
	if has_item_art():
		_apply_stage()
		if picked_up and announce:
			show_found_message()


func is_available() -> bool:
	return not has_item_art() or task_stage == "find"


func is_item_visible() -> bool:
	return _item != null and _item.visible


func is_carried_icon_visible() -> bool:
	return _carried_icon != null and _carried_icon.visible


func is_cue_visible() -> bool:
	return _cue != null and _cue.is_shown()


func message_text() -> String:
	return _message.text if _message != null and _message.visible else ""


func distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false


## Only the nearest NPC or item in range answers E, and only while this item is needed.
func is_target() -> bool:
	return is_available() and InteractCue.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not is_target():
		return
	interacted.emit(object_id, object_name)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _cue != null:
		_cue.set_shown(is_target() and not MovementBlockers.is_blocking(get_tree()))
	if _carried_icon != null and _carried_icon.visible:
		_place_carried_icon(delta)
	if _message != null and _message.visible:
		_place_message()


func _apply_stage() -> void:
	var findable := task_stage == "find"
	_item.visible = findable
	# A hidden item must not count as "in range", or it would steal E from a nearby NPC.
	# Deferred: this can run from inside a physics callback, where monitoring can't change.
	_area.set_deferred("monitoring", findable)
	if not findable:
		player_in_range = false
	_carried_icon.visible = task_stage == "deliver"


func _create_item_visuals() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = item_texture
	atlas.region = item_region

	# In a CanvasGroup so the shared outline shader can draw around it, like the NPCs.
	_item = CanvasGroup.new()
	_item.name = "Item"
	_item.fit_margin = 4.0
	add_child(_item)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item.add_child(sprite)

	_cue = InteractCue.new()
	_cue.outline_target = _item
	_cue.prompt_offset = Vector2(0, -item_region.size.y / 2.0 - 12.0)
	add_child(_cue)

	_carried_icon = Sprite2D.new()
	_carried_icon.name = "CarriedIcon"
	_carried_icon.texture = atlas
	_carried_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carried_icon.top_level = true
	_carried_icon.z_index = 10
	_carried_icon.visible = false
	add_child(_carried_icon)

	_message_layer = CanvasLayer.new()
	_message_layer.layer = 5
	add_child(_message_layer)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_override("font", MESSAGE_FONT)
	_message.add_theme_font_size_override("font_size", 32)
	_message.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03))
	_message.add_theme_constant_override("outline_size", 8)
	_message.visible = false
	_message_layer.add_child(_message)


func _find_player() -> Node2D:
	if is_instance_valid(_player):
		return _player
	var scene := get_tree().current_scene
	if scene != null:
		_player = scene.find_child("Player", true, false) as Node2D
	return _player


## A small copy of the item by the player's shoulder while it is being carried.
func _place_carried_icon(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	_time += delta
	var art_scale := player.global_scale
	var fit := CARRIED_ICON_HEIGHT / maxf(item_region.size.y, CARRIED_ICON_HEIGHT)
	_carried_icon.global_scale = art_scale * fit
	var bob := Vector2(0, round(sin(_time * 3.0)))
	_carried_icon.global_position = player.global_position + (CARRIED_ICON_OFFSET + bob) * art_scale


func show_found_message() -> void:
	var shown_name := found_name if not found_name.is_empty() else object_name
	_message.text = "You found %s!" % shown_name
	_message.modulate.a = 1.0
	_message.visible = true
	_place_message()
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SECONDS)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
	_message_tween.tween_callback(_message.hide)


func _place_message() -> void:
	var player := _find_player()
	if player == null:
		return
	_message.reset_size()
	var screen_position := player.get_global_transform_with_canvas().origin
	_message.position = screen_position + Vector2(-_message.size.x / 2.0, -130)
