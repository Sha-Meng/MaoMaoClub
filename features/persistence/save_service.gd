extends Node
class_name SaveService

const SAVE_PATH: String = "user://maomao_club_save.cfg"
const SAVE_VERSION: int = 1

func load_game() -> Dictionary:
	var config_file: ConfigFile = ConfigFile.new()
	var error: Error = config_file.load(SAVE_PATH)
	if error != OK:
		return make_default_save()

	var save_data: Dictionary = make_default_save()
	save_data["save_version"] = int(config_file.get_value("meta", "save_version", SAVE_VERSION))
	save_data["last_saved_unix_time"] = int(config_file.get_value("meta", "last_saved_unix_time", Time.get_unix_time_from_system()))
	save_data["coins"] = int(config_file.get_value("economy", "coins", 0))
	save_data["business_xp"] = int(config_file.get_value("economy", "business_xp", 0))
	save_data["served_customers_total"] = int(config_file.get_value("economy", "served_customers_total", 0))
	save_data["window_position"] = config_file.get_value("window", "position", save_data["window_position"])
	save_data["window_size"] = config_file.get_value("window", "size", save_data["window_size"])
	return save_data


func save_game(save_data: Dictionary) -> void:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value("meta", "save_version", SAVE_VERSION)
	config_file.set_value("meta", "last_saved_unix_time", int(Time.get_unix_time_from_system()))
	config_file.set_value("economy", "coins", int(save_data.get("coins", 0)))
	config_file.set_value("economy", "business_xp", int(save_data.get("business_xp", 0)))
	config_file.set_value("economy", "served_customers_total", int(save_data.get("served_customers_total", 0)))
	config_file.set_value("window", "position", save_data.get("window_position", Vector2i.ZERO))
	config_file.set_value("window", "size", save_data.get("window_size", Vector2i(960, 360)))

	var error: Error = config_file.save(SAVE_PATH)
	if error != OK:
		push_warning("保存失败: %s" % error_string(error))


func make_default_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"coins": 0,
		"business_xp": 0,
		"served_customers_total": 0,
		"window_position": Vector2i.ZERO,
		"window_size": Vector2i(960, 360),
		"last_saved_unix_time": Time.get_unix_time_from_system()
	}
