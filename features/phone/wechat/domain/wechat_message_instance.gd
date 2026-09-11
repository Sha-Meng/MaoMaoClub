extends RefCounted
class_name WechatMessageInstance

var instance_id: StringName = &""
var author_id: StringName = &""
var text: String = ""
var time_label: String = ""
var sequence: int = 0
var unread: bool = true
var from_player: bool = false


func to_save_data() -> Dictionary:
	return {
		"instance_id": String(instance_id), "author_id": String(author_id), "text": text,
		"time_label": time_label, "sequence": sequence, "unread": unread,
		"from_player": from_player,
	}


static func from_save_data(data: Dictionary) -> WechatMessageInstance:
	var value := WechatMessageInstance.new()
	value.instance_id = StringName(data.get("instance_id", ""))
	value.author_id = StringName(data.get("author_id", ""))
	value.text = String(data.get("text", ""))
	value.time_label = String(data.get("time_label", ""))
	value.sequence = maxi(int(data.get("sequence", 0)), 0)
	value.unread = bool(data.get("unread", false))
	value.from_player = bool(data.get("from_player", false))
	return value
