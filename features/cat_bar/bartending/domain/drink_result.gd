extends RefCounted
class_name DrinkResult

var recipe_id: StringName = &""
var valid: bool = false
var quality: int = 0
var tags: Array[StringName] = []
var differences: PackedStringArray = PackedStringArray()
var glass_id: StringName = &""
var appearance: Dictionary[StringName, Variant] = {}


func copy() -> DrinkResult:
	var result := DrinkResult.new()
	result.recipe_id = recipe_id
	result.valid = valid
	result.quality = quality
	result.tags = tags.duplicate()
	result.differences = differences.duplicate()
	result.glass_id = glass_id
	result.appearance = appearance.duplicate(true)
	return result


func to_save_data() -> Dictionary:
	var tag_strings: PackedStringArray = PackedStringArray()
	for tag: StringName in tags:
		tag_strings.append(String(tag))
	return {
		"recipe_id": String(recipe_id),
		"valid": valid,
		"quality": quality,
		"tags": tag_strings,
		"differences": differences,
		"glass_id": String(glass_id),
		"appearance": appearance.duplicate(true),
	}


static func from_save_data(data: Dictionary, content: CatBarContentRegistry) -> DrinkResult:
	var result := DrinkResult.new()
	result.recipe_id = StringName(data.get("recipe_id", ""))
	result.glass_id = StringName(data.get("glass_id", ""))
	if content.get_recipe(result.recipe_id) == null or content.get_glass(result.glass_id) == null:
		return null
	result.valid = bool(data.get("valid", false))
	result.quality = clampi(int(data.get("quality", 0)), 0, 100)
	for tag: Variant in data.get("tags", []):
		result.tags.append(StringName(tag))
	for difference: Variant in data.get("differences", []):
		result.differences.append(String(difference))
	var raw_appearance: Variant = data.get("appearance", {})
	if raw_appearance is Dictionary:
		result.appearance = raw_appearance.duplicate(true)
	return result
