extends RefCounted
class_name CatBarContentRegistry

var _tools: Dictionary[StringName, ToolDefinition] = {}
var _ingredients: Dictionary[StringName, IngredientDefinition] = {}
var _glasses: Dictionary[StringName, GlassDefinition] = {}
var _interactions: Dictionary[StringName, InteractionDefinition] = {}
var _recipes: Dictionary[StringName, RecipeDefinition] = {}
var _station_layout: StationLayoutDefinition


func build(catalog: CatBarContentCatalog) -> PackedStringArray:
	clear()
	var errors := PackedStringArray()
	if catalog == null:
		errors.append("内容目录不能为空")
		return errors
	_register_content(catalog.tools, _tools, "tool", errors)
	_register_content(catalog.ingredients, _ingredients, "ingredient", errors)
	_register_content(catalog.glasses, _glasses, "glass", errors)
	_register_interactions(catalog.interactions, errors)
	_register_content(catalog.recipes, _recipes, "recipe", errors)
	_station_layout = catalog.station_layout
	return errors


func clear() -> void:
	_tools.clear()
	_ingredients.clear()
	_glasses.clear()
	_interactions.clear()
	_recipes.clear()
	_station_layout = null


func get_tool(content_id: StringName) -> ToolDefinition:
	return _tools.get(content_id) as ToolDefinition


func get_ingredient(content_id: StringName) -> IngredientDefinition:
	return _ingredients.get(content_id) as IngredientDefinition


func get_glass(content_id: StringName) -> GlassDefinition:
	return _glasses.get(content_id) as GlassDefinition


func get_interaction(interaction_id: StringName) -> InteractionDefinition:
	return _interactions.get(interaction_id) as InteractionDefinition


func get_recipe(content_id: StringName) -> RecipeDefinition:
	return _recipes.get(content_id) as RecipeDefinition


func get_station_layout() -> StationLayoutDefinition:
	return _station_layout


func counts() -> Dictionary[StringName, int]:
	return {
		&"tools": _tools.size(),
		&"ingredients": _ingredients.size(),
		&"glasses": _glasses.size(),
		&"interactions": _interactions.size(),
		&"recipes": _recipes.size(),
	}


func _register_content(source: Array, target: Dictionary, kind: String, errors: PackedStringArray) -> void:
	for value: Variant in source:
		var definition := value as CatBarContentDefinition
		if definition == null:
			errors.append("%s: 包含空或错误类型定义" % kind)
			continue
		if target.has(definition.content_id):
			errors.append("%s: 重复 ID %s" % [kind, definition.content_id])
			continue
		target[definition.content_id] = definition


func _register_interactions(source: Array[InteractionDefinition], errors: PackedStringArray) -> void:
	for definition: InteractionDefinition in source:
		if definition == null:
			errors.append("interaction: 包含空定义")
			continue
		if _interactions.has(definition.interaction_id):
			errors.append("interaction: 重复 ID %s" % definition.interaction_id)
			continue
		_interactions[definition.interaction_id] = definition

