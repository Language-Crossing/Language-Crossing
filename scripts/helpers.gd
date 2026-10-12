class_name ConfigHelpers
extends RefCounted

const CONFIG_ROOT := "res://configs"
const SAVE_ROOT := "user://saves"


static func read_config(relative_path: String, fallback: Variant = null) -> Variant:
	var path := CONFIG_ROOT.path_join(relative_path)
	if not FileAccess.file_exists(path):
		push_error("Config file does not exist: %s" % path)
		return _copy_fallback(fallback)
	return read_json(path, fallback)


static func read_save(file_name: String, fallback: Variant = null) -> Variant:
	return read_json(SAVE_ROOT.path_join(file_name), fallback)


static func read_json(path: String, fallback: Variant = null) -> Variant:
	if not FileAccess.file_exists(path):
		return _copy_fallback(fallback)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return _copy_fallback(fallback)

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_error("Invalid JSON in %s at line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return _copy_fallback(fallback)
	return parser.data


static func write_save(file_name: String, data: Variant) -> bool:
	var absolute_save_root := ProjectSettings.globalize_path(SAVE_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_save_root)
	if directory_error != OK and not DirAccess.dir_exists_absolute(absolute_save_root):
		push_error("Could not create save directory: %s" % error_string(directory_error))
		return false

	var path := SAVE_ROOT.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func _copy_fallback(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
