extends CanvasLayer

const TASK_FONT := preload("res://assets/Fonts/pixel-game/Pixel Game.otf")
const HEADING_FONT := preload("res://assets/Fonts/berkshireSwash/BerkshireSwash-Regular.ttf")
const DESCRIPTION_FONT := preload("res://assets/UI/pixel-ui-free-1.0.2/addons/pixel_ui/font/pixel_ui_font.fnt")
const TASK_TITLE_COLOR := Color("fff0c8")
const TASK_DESCRIPTION_COLOR := Color("f5dca6")
const TASK_OUTLINE_COLOR := Color("2b1d16")

@export var level_controller_path: NodePath = NodePath("..")

@onready var task_panel: PanelContainer = $TaskPanel
@onready var heading: Label = $TaskPanel/Margin/Content/Heading
@onready var task_rows: VBoxContainer = $TaskPanel/Margin/Content/TaskRows
@onready var progress_bar: ProgressBar = $ProgressPanel/ProgressMargin/ProgressContent/ProgressBar
@onready var progress_label: Label = $ProgressPanel/ProgressMargin/ProgressContent/ProgressLabel

var level_controller: Node


func _ready() -> void:
	heading.add_theme_font_override("font", HEADING_FONT)
	level_controller = get_node_or_null(level_controller_path)
	if level_controller == null:
		push_error("Task list could not find its level controller")
		return
	if not level_controller.has_signal("task_progress_changed"):
		push_error("Level controller is missing signal 'task_progress_changed'")
		return
	if not level_controller.has_method("get_active_tasks"):
		push_error("Level controller cannot provide active tasks")
		return
	if not level_controller.has_method("get_task_completion_progress"):
		push_error("Level controller cannot provide task completion progress")
		return

	var task_changed := Callable(self, "_refresh_ui")
	if not level_controller.is_connected("task_progress_changed", task_changed):
		level_controller.connect("task_progress_changed", task_changed)
	call_deferred("_refresh_ui")


func _refresh_ui(_task: Dictionary = {}) -> void:
	_refresh_tasks()
	_refresh_progress()


func _refresh_tasks() -> void:
	for child in task_rows.get_children():
		task_rows.remove_child(child)
		child.queue_free()

	var active_tasks: Array = level_controller.call("get_active_tasks")
	task_panel.visible = not active_tasks.is_empty()
	for task in active_tasks:
		if not task is Dictionary:
			continue

		var task_entry := VBoxContainer.new()
		task_entry.add_theme_constant_override("separation", 2)

		var title := Label.new()
		title.text = str(task.get("taskName", "Task"))
		title.add_theme_font_override("font", TASK_FONT)
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", TASK_TITLE_COLOR)
		title.add_theme_color_override("font_outline_color", TASK_OUTLINE_COLOR)
		title.add_theme_constant_override("outline_size", 3)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_entry.add_child(title)

		var description := Label.new()
		description.text = str(task.get("taskDescription", ""))
		description.add_theme_font_override("font", DESCRIPTION_FONT)
		description.add_theme_font_size_override("font_size", 10)
		description.add_theme_color_override("font_color", TASK_OUTLINE_COLOR)
		description.add_theme_constant_override("outline_size", 0)
		description.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		description.add_theme_constant_override("shadow_offset_x", 0)
		description.add_theme_constant_override("shadow_offset_y", 0)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_entry.add_child(description)

		task_rows.add_child(task_entry)


func _refresh_progress(_task: Dictionary = {}) -> void:
	var progress: Dictionary = level_controller.call("get_task_completion_progress")
	var completed := int(progress.get("completed", 0))
	var total := int(progress.get("total", 0))

	progress_bar.max_value = maxi(total, 1)
	progress_bar.value = completed
	progress_label.text = "%d / %d tasks complete" % [completed, total]
