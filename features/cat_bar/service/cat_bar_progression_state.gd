extends RefCounted
class_name CatBarProgressionState

var materials: Dictionary[StringName, int] = {}
var researched_recipes: Array[StringName] = [&"moonlit_meow"]
var today_menu: Array[StringName] = [&"moonlit_meow"]
var delivered_total: int = 0
var last_quality: int = 0


func award_delivery(result: DrinkResult) -> void:
	delivered_total += 1
	last_quality = result.quality
	materials[&"catnip_leaf"] = int(materials.get(&"catnip_leaf", 0)) + 1


func research(recipe_id: StringName, material_id: StringName = &"catnip_leaf", cost: int = 1) -> bool:
	if recipe_id.is_empty() or researched_recipes.has(recipe_id):
		return false
	var owned := int(materials.get(material_id, 0))
	if owned < cost:
		return false
	materials[material_id] = owned - cost
	researched_recipes.append(recipe_id)
	return true


func add_to_menu(recipe_id: StringName) -> bool:
	if not researched_recipes.has(recipe_id) or today_menu.has(recipe_id):
		return false
	today_menu.append(recipe_id)
	return true


func reward_multiplier() -> float:
	return 1.0 + 0.08 * float(maxi(today_menu.size() - 1, 0))


func to_save_data() -> Dictionary:
	var serialized_materials: Dictionary = {}
	for material_id: StringName in materials:
		serialized_materials[String(material_id)] = materials[material_id]
	return {
		"materials": serialized_materials,
		"researched_recipes": _names_to_strings(researched_recipes),
		"today_menu": _names_to_strings(today_menu),
		"delivered_total": delivered_total,
		"last_quality": last_quality,
	}


func restore(data: Dictionary, known_recipe_ids: Array[StringName], deprecated_ids: Dictionary = {}) -> void:
	materials.clear()
	var raw_materials: Variant = data.get("materials", {})
	if raw_materials is Dictionary:
		for raw_id: Variant in raw_materials:
			var material_id := StringName(deprecated_ids.get(raw_id, raw_id))
			var amount := clampi(int(raw_materials[raw_id]), 0, 9999)
			if not material_id.is_empty() and amount > 0:
				materials[material_id] = amount
	researched_recipes = [&"moonlit_meow"]
	for raw_id: Variant in data.get("researched_recipes", []):
		var recipe_id := StringName(deprecated_ids.get(raw_id, raw_id))
		if known_recipe_ids.has(recipe_id) and not researched_recipes.has(recipe_id):
			researched_recipes.append(recipe_id)
	today_menu = []
	for raw_id: Variant in data.get("today_menu", []):
		var recipe_id := StringName(deprecated_ids.get(raw_id, raw_id))
		if researched_recipes.has(recipe_id) and not today_menu.has(recipe_id):
			today_menu.append(recipe_id)
	if today_menu.is_empty():
		today_menu = [&"moonlit_meow"]
	delivered_total = clampi(int(data.get("delivered_total", 0)), 0, 100000000)
	last_quality = clampi(int(data.get("last_quality", 0)), 0, 100)


func _names_to_strings(values: Array[StringName]) -> PackedStringArray:
	var result := PackedStringArray()
	for value: StringName in values:
		result.append(String(value))
	return result
