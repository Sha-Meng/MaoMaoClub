extends Resource
class_name CatBarContentDefinition

@export var content_id: StringName = &""
@export var display_name: String = ""
@export var asset_id: StringName = &""
@export var icon_texture: Texture2D
@export var placeholder: bool = true


func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if content_id.is_empty():
		errors.append("content_id 不能为空")
	if display_name.strip_edges().is_empty():
		errors.append("%s: display_name 不能为空" % content_id)
	if asset_id.is_empty():
		errors.append("%s: asset_id 不能为空" % content_id)
	return errors
