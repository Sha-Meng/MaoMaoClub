extends RefCounted


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("CatBar 内容注册表与只读查询", _test_valid_registry.bind(suite))
	suite.run_case("共享 Resource 不承载运行时会话状态", _test_shared_resource_is_definition_only.bind(suite))
	suite.run_case("内容校验聚合多个错误", _test_aggregated_validation.bind(suite))


func make_valid_catalog() -> CatBarContentCatalog:
	var pour := InteractionDefinition.new()
	pour.interaction_id = &"pour"
	pour.strategy_id = &"pour_fixed_dose"
	pour.success_feedback_id = &"pour_ok"
	pour.failure_feedback_id = &"pour_fail"

	var shaker := ToolDefinition.new()
	shaker.content_id = &"shaker"
	shaker.display_name = "Shake 杯"
	shaker.asset_id = &"tool_shaker_placeholder"
	shaker.capability_tags = [&"liquid_receiver", &"shakeable"]
	shaker.interaction_ids = [&"pour"]
	shaker.capacity_ml = 300.0

	var spirit := IngredientDefinition.new()
	spirit.content_id = &"amber_spirit"
	spirit.display_name = "琥珀酒液"
	spirit.asset_id = &"ingredient_amber_placeholder"
	spirit.interaction_id = &"pour"
	spirit.default_dose = 30.0
	spirit.fluid_id = 1

	var glass := GlassDefinition.new()
	glass.content_id = &"coupe_glass"
	glass.display_name = "浅碟杯"
	glass.asset_id = &"glass_coupe_placeholder"
	glass.capacity_ml = 180.0

	var step := RecipeStepDefinition.new()
	step.step_id = &"add_amber"
	step.interaction_id = &"pour"
	step.subject_id = spirit.content_id
	step.target_id = shaker.content_id
	step.expected_amount = 30.0
	step.tolerance = 2.0

	var recipe := RecipeDefinition.new()
	recipe.content_id = &"moonlit_meow"
	recipe.display_name = "月夜猫语"
	recipe.asset_id = &"drink_moonlit_placeholder"
	recipe.target_glass_id = glass.content_id
	recipe.steps = [step]

	var slot := StationSlotDefinition.new()
	slot.slot_id = &"amber_slot"
	slot.content_kind = &"ingredient"
	slot.content_id = spirit.content_id
	slot.allowed_categories = [&"liquid"]

	var zone := StationZoneDefinition.new()
	zone.zone_id = &"liquid_zone"
	zone.display_name = "酒液区"
	zone.allowed_categories = [&"liquid"]
	zone.slots = [slot]

	var layout := StationLayoutDefinition.new()
	layout.zones = [zone]

	var catalog := CatBarContentCatalog.new()
	catalog.tools = [shaker]
	catalog.ingredients = [spirit]
	catalog.glasses = [glass]
	catalog.interactions = [pour]
	catalog.recipes = [recipe]
	catalog.station_layout = layout
	return catalog


func _test_valid_registry(suite: CatBarTestSuite) -> void:
	var catalog := make_valid_catalog()
	var validator := CatBarContentValidator.new()
	var errors := validator.validate(catalog, [&"pour_fixed_dose"])
	suite.expect_equal(errors.size(), 0, "合法目录不得产生校验错误")
	var registry := CatBarContentRegistry.new()
	suite.expect_equal(registry.build(catalog).size(), 0, "合法目录应完成注册")
	suite.expect_equal(registry.counts()[&"tools"], 1, "应注册一个器具")
	suite.expect_true(registry.get_ingredient(&"amber_spirit") != null, "应按稳定 ID 查询原料")
	suite.expect_true(registry.get_recipe(&"moonlit_meow") != null, "应按稳定 ID 查询配方")


func _test_shared_resource_is_definition_only(suite: CatBarTestSuite) -> void:
	var catalog := make_valid_catalog()
	var shared_recipe := catalog.recipes[0]
	var session_a: Dictionary[StringName, Variant] = {&"recipe_id": shared_recipe.content_id, &"steps": []}
	var session_b: Dictionary[StringName, Variant] = {&"recipe_id": shared_recipe.content_id, &"steps": []}
	var steps_a: Array = session_a[&"steps"]
	steps_a.append(&"runtime_step")
	suite.expect_equal((session_b[&"steps"] as Array).size(), 0, "隔离状态不得串改")
	suite.expect_equal(shared_recipe.steps.size(), 1, "运行时步骤不得写回共享配方 Resource")


func _test_aggregated_validation(suite: CatBarTestSuite) -> void:
	var catalog := make_valid_catalog()
	var duplicate := catalog.tools[0].duplicate() as ToolDefinition
	duplicate.content_id = catalog.tools[0].content_id
	catalog.tools.append(duplicate)
	catalog.interactions[0].strategy_id = &"missing_strategy"
	catalog.station_layout.zones[0].slots[0].allowed_categories = [&"spice"]
	catalog.recipes[0].target_glass_id = &"missing_glass"
	catalog.deprecated_ids = {&"old_spirit": &"old_spirit"}
	var errors := CatBarContentValidator.new().validate(catalog, [&"pour_fixed_dose"])
	suite.expect_true(errors.size() >= 5, "一次校验应聚合所有可发现错误")
	suite.expect_contains_text(errors, "重复 ID", "应报告重复 ID")
	suite.expect_contains_text(errors, "未注册 strategy_id", "应报告未知策略")
	suite.expect_contains_text(errors, "不兼容", "应报告槽位类别冲突")
	suite.expect_contains_text(errors, "未知 target_glass_id", "应报告缺失酒杯")
	suite.expect_contains_text(errors, "不能映射到自身", "应报告错误废弃映射")

