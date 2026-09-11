extends CatBarContentDefinition
class_name GlassDefinition

@export var capacity_ml: float = 180.0
@export var capability_tags: Array[StringName] = [&"drink_receiver"]


func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if capacity_ml <= 0.0:
		errors.append("%s: 酒杯容量必须大于 0" % content_id)
	if capability_tags.is_empty():
		errors.append("%s: capability_tags 不能为空" % content_id)
	return errors

