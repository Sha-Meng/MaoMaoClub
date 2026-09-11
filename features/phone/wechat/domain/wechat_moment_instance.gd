extends RefCounted
class_name WechatMomentInstance

var instance_id: StringName = &""
var author_id: StringName = &""
var text: String = ""
var time_label: String = ""
var category: StringName = &"daily"
var image_ids: Array[StringName] = []
var sequence: int = 0


func to_save_data() -> Dictionary:
	var images := PackedStringArray()
	for image_id: StringName in image_ids:
		images.append(String(image_id))
	return {
		"instance_id": String(instance_id), "author_id": String(author_id), "text": text,
		"time_label": time_label, "category": String(category), "image_ids": images,
		"sequence": sequence,
	}


static func from_save_data(data: Dictionary) -> WechatMomentInstance:
	var value := WechatMomentInstance.new()
	value.instance_id = StringName(data.get("instance_id", ""))
	value.author_id = StringName(data.get("author_id", ""))
	value.text = String(data.get("text", ""))
	value.time_label = String(data.get("time_label", ""))
	value.category = StringName(data.get("category", "daily"))
	for image_id: Variant in data.get("image_ids", []):
		value.image_ids.append(StringName(image_id))
	value.sequence = maxi(int(data.get("sequence", 0)), 0)
	return value

