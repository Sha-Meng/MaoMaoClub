extends Resource
class_name RecipeStepDefinition

@export var step_id: StringName = &""
@export var interaction_id: StringName = &""
@export var subject_id: StringName = &""
@export var target_id: StringName = &""
@export var expected_amount: float = 0.0
@export var tolerance: float = 0.0
@export var required: bool = true
@export var allowed_substitutes: Array[StringName] = []


func validate_definition(recipe_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if step_id.is_empty():
		errors.append("%s: step_id 不能为空" % recipe_id)
	if interaction_id.is_empty():
		errors.append("%s/%s: interaction_id 不能为空" % [recipe_id, step_id])
	if subject_id.is_empty():
		errors.append("%s/%s: subject_id 不能为空" % [recipe_id, step_id])
	if target_id.is_empty():
		errors.append("%s/%s: target_id 不能为空" % [recipe_id, step_id])
	if expected_amount < 0.0 or tolerance < 0.0:
		errors.append("%s/%s: 数量和容差不能为负数" % [recipe_id, step_id])
	return errors

