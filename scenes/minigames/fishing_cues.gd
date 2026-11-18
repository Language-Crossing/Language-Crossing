extends Node2D
## What the player sees while fishing: a float at the end of the line that bobs calmly
## while waiting and dips hard during a bite, plus a short message when a fish gets away.
## player.gd calls show_float(), start_bite(), hide_float() and show_message().

const FLOAT_TEXTURE := preload("res://assets/tilesets/character/tools_casting_strip15.png")
## The red float as drawn in frame 8 of the cast animation (frames are 96x64).
const FLOAT_REGION := Rect2(843, 33, 4, 4)
## Where the float lands in the last cast frame, relative to the rod frame's center.
const LINE_END := Vector2(29.5, 24.0)

## Sizes in texture pixels; they grow with the player's scale like the rest of the art.
@export var wait_bob_height := 0.6
@export var wait_bob_speed := 2.5
@export var bite_dip_depth := 2.5
@export var bite_dip_speed := 14.0
@export var message_seconds := 1.6

@export var rod_path: NodePath = NodePath("../Tool2D")

var is_biting := false

var _float: Sprite2D
var _message_layer: CanvasLayer
var _message: Label
var _message_tween: Tween
var _time := 0.0

@onready var _rod: AnimatedSprite2D = get_node(rod_path)


func _ready() -> void:
	_float = Sprite2D.new()
	_float.name = "Float"
	var atlas := AtlasTexture.new()
	atlas.atlas = FLOAT_TEXTURE
	atlas.region = FLOAT_REGION
	_float.texture = atlas
	_float.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_float.z_index = 2
	_float.top_level = true
	_float.visible = false
	add_child(_float)

	_message_layer = CanvasLayer.new()
	_message_layer.layer = 5
	add_child(_message_layer)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_override("font", preload("res://assets/Fonts/pixel-game/Pixel Game.otf"))
	_message.add_theme_font_size_override("font_size", 32)
	_message.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03))
	_message.add_theme_constant_override("outline_size", 8)
	_message.visible = false
	_message_layer.add_child(_message)


func _process(delta: float) -> void:
	if _message.visible:
		_place_message()
	if not _float.visible:
		return
	_time += delta
	var drop := 0.0
	if is_biting:
		# Quick, deep tugs: the float is pulled under and pops back up.
		drop = absf(sin(_time * bite_dip_speed)) * bite_dip_depth
	else:
		drop = sin(_time * wait_bob_speed) * wait_bob_height
	_float.global_scale = _rod.global_scale
	_float.global_position = float_anchor() + Vector2(0, drop * _rod.global_scale.y)


## Call when the cast has landed.
func show_float() -> void:
	is_biting = false
	_time = 0.0
	_float.visible = true
	_float.global_scale = _rod.global_scale
	_float.global_position = float_anchor()


func start_bite() -> void:
	is_biting = true
	_time = 0.0


func hide_float() -> void:
	is_biting = false
	_float.visible = false


func is_float_visible() -> bool:
	return _float.visible


func float_position() -> Vector2:
	return _float.global_position


## The end of the line in world space, following the rod's flip and rotation.
func float_anchor() -> Vector2:
	var local := LINE_END
	if _rod.flip_h:
		local.x = -local.x
	if _rod.flip_v:
		local.y = -local.y
	return _rod.to_global(local + _rod.offset)


## A short message above the player that fades out, e.g. "The fish got away...".
func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message.visible = true
	_place_message()
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(message_seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
	_message_tween.tween_callback(_message.hide)


func message_text() -> String:
	return _message.text if _message.visible else ""


func _place_message() -> void:
	var screen_position := get_global_transform_with_canvas().origin
	_message.reset_size()
	_message.position = screen_position + Vector2(-_message.size.x / 2.0, -110)
