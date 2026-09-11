extends CatBarContentDefinition
class_name ToolDefinition

@export var capability_tags: Array[StringName] = []
@export var interaction_ids: Array[StringName] = []
@export var capacity_ml: float = 0.0


func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if capability_tags.is_empty():
		errors.append("%s: capability_tags 不能为空" % content_id)
	if interaction_ids.is_empty():
		errors.append("%s: interaction_ids 不能为空" % content_id)
	if capacity_ml < 0.0:
		errors.append("%s: capacity_ml 不能为负数" % content_id)
	return errors

