class_name InteractableNPC
extends "res://scenes/characters/character.gd"

signal interacted(npc_id: StringName)

@export var npc_id: StringName = &""


func _ready() -> void:
	super._ready()
	input_pickable = true
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if OS.is_debug_build():
			print("[Dialogue] NPC clicked: %s" % npc_id)
		interacted.emit(npc_id)