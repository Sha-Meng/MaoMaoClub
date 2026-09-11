extends RefCounted
class_name RecipeEvaluator


func evaluate(
	recipe: RecipeDefinition,
	step_log: Array[BartendingStepLog],
	draft: BartendingSessionDraft,
	content: CatBarContentRegistry
) -> DrinkResult:
	var result := DrinkResult.new()
	result.recipe_id = recipe.content_id
	result.glass_id = draft.poured_glass_id
	var ingredient_scores: Array[float] = []
	var action_scores: Array[float] = []
	var missing_core_ingredient := false
	var previous_step_index := -1
	for step: RecipeStepDefinition in recipe.steps:
		if not step.required:
			continue
		var matches := _find_steps(step, step_log)
		var is_ingredient := content.get_ingredient(step.subject_id) != null
		if matches.is_empty():
			result.differences.append("缺少步骤：%s" % step.step_id)
			result.tags.append(&"missing_step")
			if is_ingredient:
				missing_core_ingredient = true
				ingredient_scores.append(0.0)
			else:
				action_scores.append(0.0)
			continue
		var first_index := step_log.find(matches[0])
		if first_index < previous_step_index:
			result.differences.append("步骤顺序错误：%s" % step.step_id)
			result.tags.append(&"wrong_order")
		previous_step_index = maxi(previous_step_index, step_log.find(matches[matches.size() - 1]))
		var actual_amount := 0.0
		for matched: BartendingStepLog in matches:
			actual_amount += matched.amount
		var step_score := _amount_score(actual_amount, step.expected_amount, step.tolerance)
		if step_score < 0.999:
			result.differences.append("步骤 %s 数量偏差：%.2f / %.2f" % [step.step_id, actual_amount, step.expected_amount])
			result.tags.append(&"amount_deviation")
		if is_ingredient:
			ingredient_scores.append(step_score)
		else:
			action_scores.append(step_score)
	var ingredient_score := _average_or_perfect(ingredient_scores)
	var action_score := _average_or_perfect(action_scores)
	var glass_score := 1.0 if draft.poured_glass_id == recipe.target_glass_id else 0.0
	if glass_score == 0.0:
		result.tags.append(&"wrong_glass")
		result.differences.append("目标酒杯应为 %s" % recipe.target_glass_id)
	var weighted := (
		ingredient_score * recipe.ingredient_weight
		+ action_score * recipe.action_weight
		+ glass_score * recipe.glass_weight
	)
	result.quality = clampi(roundi(weighted * 100.0), 0, 100)
	result.valid = not missing_core_ingredient and glass_score > 0.0 and result.quality >= recipe.minimum_quality_to_serve
	if result.valid:
		result.tags.append(&"excellent" if result.quality >= 90 else &"drinkable")
	else:
		result.tags.append(&"invalid")
	result.appearance = _make_appearance(draft.get_contents(recipe.target_glass_id), content)
	return result


func _find_steps(step: RecipeStepDefinition, log: Array[BartendingStepLog]) -> Array[BartendingStepLog]:
	var result: Array[BartendingStepLog] = []
	for entry: BartendingStepLog in log:
		if (
			entry.interaction_id == step.interaction_id
			and (entry.subject_id == step.subject_id or step.allowed_substitutes.has(entry.subject_id))
			and entry.target_id == step.target_id
		):
			result.append(entry)
	return result


func _amount_score(actual: float, expected: float, tolerance: float) -> float:
	if expected <= 0.0:
		return 1.0
	var difference := absf(actual - expected)
	if difference <= tolerance:
		return 1.0
	return clampf(1.0 - (difference - tolerance) / maxf(expected, 0.001), 0.0, 1.0)


func _average_or_perfect(values: Array[float]) -> float:
	if values.is_empty():
		return 1.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _make_appearance(
	contents: Dictionary[StringName, float],
	content: CatBarContentRegistry
) -> Dictionary[StringName, Variant]:
	var total := 0.0
	var weighted_color := Color(0.0, 0.0, 0.0, 0.0)
	for ingredient_id: StringName in contents:
		var ingredient := content.get_ingredient(ingredient_id)
		if ingredient == null or ingredient.category != IngredientDefinition.Category.LIQUID:
			continue
		var amount := contents[ingredient_id]
		total += amount
		weighted_color += ingredient.color * amount
	if total > 0.0:
		weighted_color /= total
	return {&"color": weighted_color, &"liquid_amount_ml": total}
