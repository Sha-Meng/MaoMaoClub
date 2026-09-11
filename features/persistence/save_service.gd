extends Node
class_name SaveService

const SAVE_PATH: String = "user://maomao_club_save.cfg"
const SAVE_VERSION: int = 2
const DEPRECATED_CONTENT_IDS: Dictionary = {
	"moon_gin_v0": "moon_gin",
	"old_manager_cat": "manager_cat",
}

func load_game() -> Dictionary:
	var config_file: ConfigFile = ConfigFile.new()
	var error: Error = config_file.load(SAVE_PATH)
	if error != OK:
		return make_default_save()
	var raw: Dictionary = {
		"save_version": int(config_file.get_value("meta", "save_version", 1)),
		"last_saved_unix_time": int(config_file.get_value("meta", "last_saved_unix_time", Time.get_unix_time_from_system())),
		"coins": config_file.get_value("economy", "coins", 0),
		"business_xp": config_file.get_value("economy", "business_xp", 0),
		"served_customers_total": config_file.get_value("economy", "served_customers_total", 0),
		"window_position": config_file.get_value("window", "position", Vector2i.ZERO),
		"window_size": config_file.get_value("window", "size", Vector2i(960, 540)),
	}
	if int(raw["save_version"]) >= 2:
		raw["bartending"] = config_file.get_value("cat_bar", "bartending", {})
		raw["wechat"] = config_file.get_value("phone", "wechat", {})
		raw["content_unlocks"] = config_file.get_value("cat_bar", "content_unlocks", {})
	return normalize_save_data(raw)


func save_game(save_data: Dictionary) -> void:
	var normalized := normalize_save_data(save_data)
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value("meta", "save_version", SAVE_VERSION)
	config_file.set_value("meta", "last_saved_unix_time", int(Time.get_unix_time_from_system()))
	config_file.set_value("economy", "coins", normalized["coins"])
	config_file.set_value("economy", "business_xp", normalized["business_xp"])
	config_file.set_value("economy", "served_customers_total", normalized["served_customers_total"])
	config_file.set_value("window", "position", normalized["window_position"])
	config_file.set_value("window", "size", normalized["window_size"])
	config_file.set_value("cat_bar", "bartending", normalized["bartending"])
	config_file.set_value("cat_bar", "content_unlocks", normalized["content_unlocks"])
	config_file.set_value("phone", "wechat", normalized["wechat"])

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
		"window_size": Vector2i(960, 540),
		"last_saved_unix_time": Time.get_unix_time_from_system(),
		"bartending": {"active": false},
		"wechat": WechatService.new().to_save_data(),
		"content_unlocks": CatBarProgressionState.new().to_save_data(),
	}


func normalize_save_data(raw: Dictionary) -> Dictionary:
	var result := make_default_save()
	result["coins"] = clampi(int(raw.get("coins", 0)), 0, 2000000000)
	result["business_xp"] = clampi(int(raw.get("business_xp", 0)), 0, 2000000000)
	result["served_customers_total"] = clampi(int(raw.get("served_customers_total", 0)), 0, 2000000000)
	var position: Variant = raw.get("window_position", result["window_position"])
	if position is Vector2i:
		result["window_position"] = position
	var window_size: Variant = raw.get("window_size", result["window_size"])
	if window_size is Vector2i and window_size.x >= 320 and window_size.y >= 240:
		result["window_size"] = window_size
	result["last_saved_unix_time"] = maxi(int(raw.get("last_saved_unix_time", Time.get_unix_time_from_system())), 0)
	# v1 不含以下分区；各分区类型损坏时只回退该分区。
	for section_name: String in ["bartending", "wechat", "content_unlocks"]:
		var section: Variant = raw.get(section_name, result[section_name])
		if section is Dictionary:
			result[section_name] = section.duplicate(true)
	result["save_version"] = SAVE_VERSION
	return result
