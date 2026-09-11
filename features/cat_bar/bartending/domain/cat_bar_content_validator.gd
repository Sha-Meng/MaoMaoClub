extends RefCounted
class_name CatBarContentValidator

const CONTENT_KINDS: Array[StringName] = [&"tool", &"ingredient", &"glass"]


func validate(catalog: CatBarContentCatalog, registered_strategy_ids: Array[StringName]) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog == null:
		errors.append("内容目录不能为空")
		return errors
	var registry := CatBarContentRegistry.new()
	for error: String in registry.build(catalog):
		errors.append(error)
	_validate_definitions(catalog, registered_strategy_ids, registry, errors)
	_validate_layout(catalog, registry, errors)
	_validate_recipes(catalog, registry, errors)
	_validate_deprecated_ids(catalog, registry, errors)
	return errors


func _validate_definitions(
	catalog: CatBarContentCatalog,
	registered_strategy_ids: Array[StringName],
	registry: CatBarContentRegistry,
	errors: PackedStringArray
) -> void:
	for tool: ToolDefinition in catalog.tools:
		if tool == null:
			continue
		_append_prefixed(errors, "tool", tool.validate_definition())
		for interaction_id: StringName in tool.interaction_ids:
			if registry.get_interaction(interaction_id) == null:
				errors.append("tool/%s: 未知 interaction_id %s" % [tool.content_id, interaction_id])
	for ingredient: IngredientDefinition in catalog.ingredients:
		if ingredient == null:
			continue
		_append_prefixed(errors, "ingredient", ingredient.validate_definition())
		if registry.get_interaction(ingredient.interaction_id) == null:
			errors.append("ingredient/%s: 未知 interaction_id %s" % [ingredient.content_id, ingredient.interaction_id])
	for glass: GlassDefinition in catalog.glasses:
		if glass != null:
			_append_prefixed(errors, "glass", glass.validate_definition())
	for interaction: InteractionDefinition in catalog.interactions:
		if interaction == null:
			continue
		_append_prefixed(errors, "interaction", interaction.validate_definition())
		if not registered_strategy_ids.has(interaction.strategy_id):
			errors.append("interaction/%s: 未注册 strategy_id %s" % [interaction.interaction_id, interaction.strategy_id])
	for recipe: RecipeDefinition in catalog.recipes:
		if recipe != null:
			_append_prefixed(errors, "recipe", recipe.validate_definition())


func _validate_layout(
	catalog: CatBarContentCatalog,
	registry: CatBarContentRegistry,
	errors: PackedStringArray
) -> void:
	if catalog.station_layout == null:
		errors.append("station_layout 不能为空")
		return
	_append_prefixed(errors, "layout", catalog.station_layout.validate_definition())
	for zone: StationZoneDefinition in catalog.station_layout.zones:
		if zone == null:
			continue
		for slot: StationSlotDefinition in zone.slots:
			if slot == null:
				continue
			if not CONTENT_KINDS.has(slot.content_kind):
				errors.append("layout/%s/%s: 未知 content_kind %s" % [zone.zone_id, slot.slot_id, slot.content_kind])
				continue
			var category := _resolve_content_category(slot, registry)
			if category.is_empty():
				errors.append("layout/%s/%s: 找不到内容 %s" % [zone.zone_id, slot.slot_id, slot.content_id])
				continue
			if not zone.allowed_categories.has(category) or not slot.allowed_categories.has(category):
				errors.append("layout/%s/%s: 内容类别 %s 与分区/槽位不兼容" % [zone.zone_id, slot.slot_id, category])


func _validate_recipes(
	catalog: CatBarContentCatalog,
	registry: CatBarContentRegistry,
	errors: PackedStringArray
) -> void:
	for recipe: RecipeDefinition in catalog.recipes:
		if recipe == null:
			continue
		if registry.get_glass(recipe.target_glass_id) == null:
			errors.append("recipe/%s: 未知 target_glass_id %s" % [recipe.content_id, recipe.target_glass_id])
		for step: RecipeStepDefinition in recipe.steps:
			if step == null:
				continue
			if registry.get_interaction(step.interaction_id) == null:
				errors.append("recipe/%s/%s: 未知 interaction_id %s" % [recipe.content_id, step.step_id, step.interaction_id])
			if not _content_exists(step.subject_id, registry):
				errors.append("recipe/%s/%s: 未知 subject_id %s" % [recipe.content_id, step.step_id, step.subject_id])
			if not _content_exists(step.target_id, registry):
				errors.append("recipe/%s/%s: 未知 target_id %s" % [recipe.content_id, step.step_id, step.target_id])


func _validate_deprecated_ids(
	catalog: CatBarContentCatalog,
	registry: CatBarContentRegistry,
	errors: PackedStringArray
) -> void:
	for old_id: StringName in catalog.deprecated_ids:
		var new_id: StringName = catalog.deprecated_ids[old_id]
		if old_id.is_empty() or new_id.is_empty():
			errors.append("deprecated_ids: ID 不能为空")
		elif old_id == new_id:
			errors.append("deprecated_ids: %s 不能映射到自身" % old_id)
		elif not _content_exists(new_id, registry):
			errors.append("deprecated_ids: %s 映射到未知 ID %s" % [old_id, new_id])


func _resolve_content_category(slot: StationSlotDefinition, registry: CatBarContentRegistry) -> StringName:
	match slot.content_kind:
		&"tool":
			return &"tool" if registry.get_tool(slot.content_id) != null else &""
		&"ingredient":
			var ingredient := registry.get_ingredient(slot.content_id)
			return ingredient.category_id() if ingredient != null else &""
		&"glass":
			return &"glass" if registry.get_glass(slot.content_id) != null else &""
	return &""


func _content_exists(content_id: StringName, registry: CatBarContentRegistry) -> bool:
	return (
		registry.get_tool(content_id) != null
		or registry.get_ingredient(content_id) != null
		or registry.get_glass(content_id) != null
	)


func _append_prefixed(target: PackedStringArray, prefix: String, source: PackedStringArray) -> void:
	for error: String in source:
		target.append("%s/%s" % [prefix, error])
