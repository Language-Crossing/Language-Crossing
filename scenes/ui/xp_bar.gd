extends CanvasLayer
## The player's XP along the bottom of the screen: their level, a bar toward the next
## level (PlayerState.XP_PER_LEVEL) and "40 / 100 XP". Earning XP pops a "+10 XP" above
## the bar and fills it smoothly; crossing into a new level flashes "Level up!".
## Story levels only (fishing gives no XP).

const FILL_SECONDS := 0.5
const POPUP_SECONDS := 1.2
## How see-through the bar gets while the player walks behind it.
const BEHIND_ALPHA := 0.35

@onready var _level_label: Label = %LevelLabel
@onready var _bar: ProgressBar = %XPProgress
@onready var _amount_label: Label = %AmountLabel
@onready var _popup: Label = %GainPopup
@onready var _level_up: Label = %LevelUpLabel
@onready var _panel: Control = $Panel

var _fill_tween: Tween
var _popup_tween: Tween
var _level_up_tween: Tween
## The level the bar is currently showing, so a gain knows whether it crossed a level.
var _shown_level := 1
var _popup_start_y := 0.0


func _ready() -> void:
	_bar.max_value = PlayerState.XP_PER_LEVEL
	_popup.visible = false
	_popup_start_y = _popup.position.y
	_level_up.visible = false
	PlayerState.xp_changed.connect(_on_xp_changed)
	PlayerState.state_loaded.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	# Fade out while the player is behind the bar, so they never disappear under it.
	var target := BEHIND_ALPHA if _player_is_behind() else 1.0
	_panel.modulate.a = move_toward(_panel.modulate.a, target, delta * 4.0)


func _player_is_behind() -> bool:
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as CanvasItem if scene else null
	if player == null:
		return false
	var feet := player.get_global_transform_with_canvas().origin
	# The character art reaches about 40px above its origin at the level's zoom.
	return _panel.get_global_rect().grow(8.0).intersects(Rect2(feet + Vector2(-16, -40), Vector2(32, 56)))


func is_faded() -> bool:
	return _panel.modulate.a < 0.99


## Shows the current XP straight away, without animating.
func refresh() -> void:
	if _fill_tween:
		_fill_tween.kill()
	_shown_level = PlayerState.get_player_level()
	_bar.value = PlayerState.get_xp_into_level()
	_update_labels()


func _on_xp_changed(gained: int) -> void:
	if gained <= 0:
		refresh()
		return
	_show_popup("+%d XP" % gained)

	var new_level: int = PlayerState.get_player_level()
	var target: float = PlayerState.get_xp_into_level()
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween()
	if new_level > _shown_level:
		# Fill to the end, flash the new level, then fill from empty to what's left over.
		_fill_tween.tween_property(_bar, "value", _bar.max_value, FILL_SECONDS)
		_fill_tween.tween_callback(_on_level_up.bind(new_level))
		_fill_tween.tween_property(_bar, "value", 0.0, 0.0)
	else:
		# Text right away; only the bar animates. (Waiting for the tween left the text
		# behind when a second gain arrived before the first finished.)
		_update_labels()
	_fill_tween.tween_property(_bar, "value", target, FILL_SECONDS)
	_fill_tween.tween_callback(_update_labels)


func _on_level_up(new_level: int) -> void:
	_shown_level = new_level
	_update_labels()
	_level_up.text = "Level up!  Lv %d" % new_level
	_level_up.visible = true
	_level_up.modulate.a = 1.0
	_level_up.scale = Vector2(0.6, 0.6)
	if _level_up_tween:
		_level_up_tween.kill()
	_level_up_tween = create_tween()
	_level_up_tween.tween_property(_level_up, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_level_up_tween.tween_interval(1.6)
	_level_up_tween.tween_property(_level_up, "modulate:a", 0.0, 0.5)
	_level_up_tween.tween_callback(_level_up.hide)


func _update_labels() -> void:
	_level_label.text = "Lv %d" % _shown_level
	var into_level: int = PlayerState.get_xp_into_level() if _shown_level == PlayerState.get_player_level() else int(_bar.value)
	_amount_label.text = "%d / %d XP" % [into_level, PlayerState.XP_PER_LEVEL]


func _show_popup(text: String) -> void:
	_popup.text = text
	_popup.visible = true
	_popup.modulate.a = 1.0
	var start_y := _popup_start_y
	_popup.position.y = start_y
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween().set_parallel()
	_popup_tween.tween_property(_popup, "position:y", start_y - 26.0, POPUP_SECONDS).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, POPUP_SECONDS * 0.5).set_delay(POPUP_SECONDS * 0.5)
	_popup_tween.chain().tween_callback(_popup.hide)


func popup_text() -> String:
	return _popup.text if _popup.visible else ""


func level_text() -> String:
	return _level_label.text


func amount_text() -> String:
	return _amount_label.text


func bar_value() -> float:
	return _bar.value
