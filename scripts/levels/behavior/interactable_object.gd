class_name InteractableObject
extends Node2D

signal interacted(object_id: StringName, object_name: String)

@export var object_id: StringName = &""
@export var object_name := "Object"
@export var interact_radius := 30.0

var player_in_range := false


func _ready() -> void:
	var interact_area := Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 0
	interact_area.collision_mask = 1

	var shape_node := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = interact_radius
	shape_node.shape = circle_shape
	interact_area.add_child(shape_node)
	add_child(interact_area)

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not player_in_range:
		return

	for npc in get_tree().get_nodes_in_group("interactable_npcs"):
		if npc is InteractableNPC and npc.player_in_range:
			return

	interacted.emit(object_id, object_name)
	get_viewport().set_input_as_handled()
