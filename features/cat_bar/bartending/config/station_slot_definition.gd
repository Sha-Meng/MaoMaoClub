extends Resource
class_name StationSlotDefinition

@export var slot_id: StringName = &""
@export var content_kind: StringName = &""
@export var content_id: StringName = &""
@export var allowed_categories: Array[StringName] = []
@export var anchor_pixels: Vector2i = Vector2i.ZERO
@export var sort_order: int = 0
@export var enabled: bool = true


func validate_definition(zone_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if slot_id.is_empty():
		errors.append("%s: slot_id 不能为空" % zone_id)
	if content_kind.is_empty():
		errors.append("%s/%s: content_kind 不能为空" % [zone_id, slot_id])
	if content_id.is_empty():
		errors.append("%s/%s: content_id 不能为空" % [zone_id, slot_id])
	if allowed_categories.is_empty():
		errors.append("%s/%s: allowed_categories 不能为空" % [zone_id, slot_id])
	return errors

