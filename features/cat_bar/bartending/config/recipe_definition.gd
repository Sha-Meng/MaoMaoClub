extends CatBarContentDefinition
class_name RecipeDefinition

@export var target_glass_id: StringName = &""
@export var steps: Array[RecipeStepDefinition] = []
@export var minimum_quality_to_serve: int = 35
@export var ingredient_weight: float = 0.55
@export var action_weight: float = 0.30
@export var glass_weight: float = 0.15


func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if target_glass_id.is_empty():
		errors.append("%s: target_glass_id 不能为空" % content_id)
	if steps.is_empty():
		errors.append("%s: 配方至少需要一个步骤" % content_id)
	if minimum_quality_to_serve < 0 or minimum_quality_to_serve > 100:
		errors.append("%s: minimum_quality_to_serve 必须在 0..100" % content_id)
	if ingredient_weight < 0.0 or action_weight < 0.0 or glass_weight < 0.0:
		errors.append("%s: 评价权重不能为负数" % content_id)
	if not is_equal_approx(ingredient_weight + action_weight + glass_weight, 1.0):
		errors.append("%s: 评价权重之和必须为 1" % content_id)
	var seen_steps: Dictionary[StringName, bool] = {}
	for step: RecipeStepDefinition in steps:
		if step == null:
			errors.append("%s: 包含空步骤" % content_id)
			continue
		for error: String in step.validate_definition(content_id):
			errors.append(error)
		if seen_steps.has(step.step_id):
			errors.append("%s: 重复 step_id %s" % [content_id, step.step_id])
		seen_steps[step.step_id] = true
	return errors

