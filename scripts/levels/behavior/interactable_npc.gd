class_name InteractableNPC
extends "res://scenes/characters/character.gd"

signal interacted(npc_id: StringName)

@export var npc_id: StringName = &""
@export var interact_radius: float = 30.0 

var player_in_range: bool = false
var interact_area: Area2D

func _ready() -> void:
	super._ready()
	_create_interact_area()

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

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player left range.") 
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	# Check if the button was pressed at all, regardless of range
	if event.is_action_pressed("interact"):
		print("Interact button pressed. Player in range? ", player_in_range) # DEBUG LINE
		
		if player_in_range:
			interacted.emit(npc_id)
			get_viewport().set_input_as_handled()
