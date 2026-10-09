@tool
extends TextureButton

@export var button_text: String = "":
	set(value):
		button_text = value
		if is_node_ready():
			label.text = button_text


@export_range(4, 144) var font_size: int = 16:
		set(value):
			font_size = value
			print("Setter triggered! Node ready? ", label)
			if label != null:
				label.label_settings.font_size = font_size

@onready var label: Label = $Label

func _ready() -> void: 
		label.label_settings = label.label_settings.duplicate()
		label.text = button_text
		label.add_theme_font_size_override("font_size", font_size)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
