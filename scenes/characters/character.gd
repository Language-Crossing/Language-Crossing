@tool
class_name BaseCharacter
extends CharacterBody2D

const SPEED = 200.0

@export_enum("white", "yellow", "umber", "tan", "pink", "pale", "maroon", "light", "golden", "caramel", "brown") var body_type: String = "white":
	set(value):
		body_type = value
		update_appearance()

@export_enum("naked", "bikini", "blue_armor", "boxer", "emerald_tunic", "golden_tunic", "grey_armor", "grey_tunic", "light_blue_armor", "pink_tunic", "purple_armor", "white_tunic", "yellow_armor") var outfit_type: String = "blue_armor":
	set(value):
		outfit_type = value
		update_appearance()

@export_enum("bald", "aquamarine_barber", "black_pointy_hat", "blonder_barber", "blonde_bob", "bluesteel_barber", "blue_barber", "blue_bob", "blue_pointy_hat", "brown_barber", "brown_bob", "brown_hat", "brown_pointy_hat", "dark_grey_hat", "ginger_barber", "ginger_bob", "golden_pointy_hat", "green_hat", "green_pointy_hat", "grey_barber", "grey_bob", "grey_hat", "lagoon_blue_bob", "light_blonde_barber", "light_blone_bob", "pink_barber", "pink_bob", "pink_hat", "purple_barber", "purple_bob", "rosa_barber", "rosa_bob", "steel_barber", "steel_bob", "strawberry_barber", "strawberry_bob", "white_barber", "white_bob", "white_greenish_bob") var head_type: String = "white_bob":
	set(value):
		head_type = value
		update_appearance()

# Node references
@onready var body_sprite = $BodySprite
@onready var outfit_sprite = $OutfitSprite
@onready var head_sprite = $HeadSprite
@onready var anim_player = $AnimationPlayer

func _ready():
	update_appearance()

func update_appearance():
	# If the nodes aren't ready yet (like during initialization), abort
	if not is_node_ready(): return
	
	# Load the specific sprite sheets based on the selected strings
	# Ensure your file paths match your project structure
	var character_path = "res://assets/characterTextures/basicMovement/"
	var file_extension = ".png"
	body_sprite.texture = load(character_path + "body/" + body_type + file_extension)
	outfit_sprite.texture = load(character_path + "outfit/" + outfit_type + file_extension) if outfit_type != "naked" else null
	head_sprite.texture = load(character_path + "hair/" + head_type + file_extension) if head_type != "bald" else null

var last_direction: String = "down"
# Generic action function available to Player and NPC
func update_animation_state(input_dir: Vector2):
	if input_dir != Vector2.ZERO:
		if abs(input_dir.x) > abs(input_dir.y):
			last_direction = "right" if input_dir.x > 0 else "left"
		else:
			last_direction = "down" if input_dir.y > 0 else "up"
			
		var anim = "walk_" + last_direction
		if anim_player.has_animation(anim) and anim_player.current_animation != anim:
			anim_player.play(anim)
	else:
		var anim = "idle"
		if anim_player.has_animation(anim) and anim_player.current_animation != anim:
			anim_player.play(anim)
