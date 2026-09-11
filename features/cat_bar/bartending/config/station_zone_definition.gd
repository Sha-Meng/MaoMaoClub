extends Resource
class_name StationZoneDefinition

@export var zone_id: StringName = &""
@export var display_name: String = ""
@export var allowed_categories: Array[StringName] = []
@export var sort_order: int = 0
@export var slots: Array[StationSlotDefinition] = []


func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if zone_id.is_empty():
		errors.append("zone_id 不能为空")
	if display_name.strip_edges().is_empty():
		errors.append("%s: display_name 不能为空" % zone_id)
	if allowed_categories.is_empty():
		errors.append("%s: allowed_categories 不能为空" % zone_id)
	var seen_slots: Dictionary[StringName, bool] = {}
	for slot: StationSlotDefinition in slots:
		if slot == null:
			errors.append("%s: 包含空槽位" % zone_id)
			continue
		for error: String in slot.validate_definition(zone_id):
			errors.append(error)
		if seen_slots.has(slot.slot_id):
			errors.append("%s: 重复 slot_id %s" % [zone_id, slot.slot_id])
		seen_slots[slot.slot_id] = true
	return errors

