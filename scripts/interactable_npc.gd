class_name InteractableNPC
extends CharacterBody2D

signal interacted(npc_id: StringName)

@export var npc_id: StringName = &""


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interacted.emit(npc_id)