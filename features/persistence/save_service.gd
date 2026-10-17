extends Node
class_name SaveService

signal save_failed(message: String)

const SAVE_PATH: String = "user://maomao_club_save.cfg"
const SAVE_VERSION: int = 2

var save_path: String = SAVE_PATH
var recovered_from_backup: bool = false
var last_error: Error = OK


func load_game() -> Dictionary:
	recovered_from_backup = false
	var file: ConfigFile = ConfigFile.new()
	var error: Error = file.load(save_path)
	if error != OK or not _file_is_valid(file):
		error = file.load(save_path + ".bak")
		if error != OK or not _file_is_valid(file):
			return make_default_save()
		recovered_from_backup = true
	var result: Dictionary = make_default_save()
	for key: String in ["coins", "business_xp", "served_customers_total"]:
		result[key] = TavernData.integer(file.get_value("economy", key, 0), 0, 0, 2000000000)
	result["save_version"] = TavernData.integer(file.get_value("meta", "save_version", 1), 1, 1, SAVE_VERSION)
	result["last_saved_unix_time"] = TavernData.integer(file.get_value("meta", "last_saved_unix_time", 0), 0)
	var saved_position: Variant = file.get_value("window", "position", Vector2i.ZERO)
	var saved_size: Variant = file.get_value("window", "size", Vector2i(960, 280))
	result["window_position"] = saved_position if saved_position is Vector2i else Vector2i.ZERO
	result["window_size"] = saved_size if saved_size is Vector2i else Vector2i(960, 280)
	result["window_layout_version"] = TavernData.integer(file.get_value("window", "layout_version", 0), 0, 0, 2)
	var checkpoint: Variant = file.get_value("tavern", "checkpoint", {})
	result["tavern"] = checkpoint if checkpoint is Dictionary else {}
	return result


func save_game(save_data: Dictionary) -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "save_version", SAVE_VERSION)
	file.set_value("meta", "last_saved_unix_time", int(Time.get_unix_time_from_system()))
	for key: String in ["coins", "business_xp", "served_customers_total"]:
		file.set_value("economy", key, TavernData.integer(save_data.get(key, 0), 0, 0, 2000000000))
	file.set_value("window", "position", save_data.get("window_position", Vector2i.ZERO))
	file.set_value("window", "size", save_data.get("window_size", Vector2i(960, 280)))
	file.set_value("window", "layout_version", save_data.get("window_layout_version", 2))
	file.set_value("tavern", "checkpoint", save_data.get("tavern", {}))
	var temporary_path: String = save_path + ".tmp"
	last_error = file.save(temporary_path)
	if last_error != OK:
		return _report_failure(last_error)
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var backup_path: String = absolute_path + ".bak"
	var existing: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(save_path):
		if existing.load(save_path) == OK and _file_is_valid(existing):
			if FileAccess.file_exists(backup_path):
				last_error = DirAccess.remove_absolute(backup_path)
				if last_error != OK:
					return _report_failure(last_error)
			last_error = DirAccess.rename_absolute(absolute_path, backup_path)
		else:
			last_error = DirAccess.remove_absolute(absolute_path)
		if last_error != OK:
			return _report_failure(last_error)
	last_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), absolute_path)
	if last_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(absolute_path):
			DirAccess.copy_absolute(backup_path, absolute_path)
		return _report_failure(last_error)
	return OK


func _report_failure(error: Error) -> Error:
	save_failed.emit("保存失败：" + error_string(error))
	return error


func _file_is_valid(file: ConfigFile) -> bool:
	for key: String in ["coins", "business_xp", "served_customers_total"]:
		if not file.has_section_key("economy", key):
			return false
		var value: Variant = file.get_value("economy", key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	return true


func make_default_save() -> Dictionary:
	return {"save_version": SAVE_VERSION, "coins": 0, "business_xp": 0, "served_customers_total": 0,
		"window_position": Vector2i.ZERO, "window_size": Vector2i(960, 280), "window_layout_version": 0,
		"tavern": {}, "last_saved_unix_time": int(Time.get_unix_time_from_system())}
