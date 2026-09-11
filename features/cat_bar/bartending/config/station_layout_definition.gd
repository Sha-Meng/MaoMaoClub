extends Resource
class_name StationLayoutDefinition

@export var layout_id: StringName = &"default_bar_station"
@export var zones: Array[StationZoneDefinition] = []


func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if layout_id.is_empty():
		errors.append("layout_id 不能为空")
	var seen_zones: Dictionary[StringName, bool] = {}
	for zone: StationZoneDefinition in zones:
		if zone == null:
			errors.append("%s: 包含空分区" % layout_id)
			continue
		for error: String in zone.validate_definition():
			errors.append(error)
		if seen_zones.has(zone.zone_id):
			errors.append("%s: 重复 zone_id %s" % [layout_id, zone.zone_id])
		seen_zones[zone.zone_id] = true
	return errors

