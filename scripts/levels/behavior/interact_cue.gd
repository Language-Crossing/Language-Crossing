class_name InteractCue
extends Node2D
## The "you can interact with this" cue shared by NPCs and task items: a white outline
## around the target's art plus an "E" key above it with a gentle bob.
##
## Only the nearest thing in range gets the cue, and only that thing answers E. Anything
## that wants to take part joins GROUP and provides `player_in_range` and
## `distance_to_player()`; it then asks InteractCue.is_nearest(self).

const GROUP := &"interact_targets"
const OUTLINE_SHADER := preload("res://scenes/characters/outline_group.gdshader")
const KEY_CAP_TEXTURE := preload("res://assets/tilesets/Sprout Lands - UI Pack - Basic pack/Sprite sheets/buttons/Small Square Buttons.png")
const KEY_CAP_REGION := Rect2(0, 32, 16, 16)
const PROMPT_FONT := preload("res://assets/Fonts/pixel-game/Pixel Game.otf")

## The CanvasGroup holding the art to outline (outline_group.gdshader only works on one).
var outline_target: CanvasGroup
## Where the "E" sits, relative to this node's parent.
var prompt_offset := Vector2(0, -32)

var _outline: ShaderMaterial
var _shown := false
var _time := 0.0


static func is_nearest(node: Node2D) -> bool:
	if not node.player_in_range:
		return false
	var my_distance: float = node.distance_to_player()
	for other in node.get_tree().get_nodes_in_group(GROUP):
		if other == node or not other.player_in_range:
			continue
		var other_distance: float = other.distance_to_player()
		if other_distance < my_distance or (other_distance == my_distance and other.get_instance_id() < node.get_instance_id()):
			return false
	return true


func _init() -> void:
	name = "InteractPrompt"
	z_index = 10
	visible = false


func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	position = prompt_offset

	var key_cap := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = KEY_CAP_TEXTURE
	atlas.region = KEY_CAP_REGION
	key_cap.texture = atlas
	key_cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(key_cap)

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
	add_child(letter)


func _process(delta: float) -> void:
	if _shown:
		_time += delta
		position = prompt_offset + Vector2(0, round(sin(_time * 3.0)))


func is_shown() -> bool:
	return _shown


func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = on
	_time = 0.0
	position = prompt_offset
	if outline_target == null:
		return
	if on:
		# One art pixel thick, whatever the level's zoom is.
		_outline.set_shader_parameter("line_thickness", outline_target.get_global_transform_with_canvas().get_scale().x)
		outline_target.material = _outline
	else:
		outline_target.material = null
