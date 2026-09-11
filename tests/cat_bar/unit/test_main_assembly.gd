extends RefCounted

const MAIN_SCENE: PackedScene = preload("res://app/main.tscn")
const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")
const TAVERN_SCENE: PackedScene = preload("res://features/tavern_loop/tavern_loop.tscn")


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("主场景 CatBar 开关与旧 TavernLoop 回退可装配", _test_feature_switch.bind(suite))
	suite.run_case("桌面窗口和经济旧行为兼容", _test_window_and_economy.bind(suite))


func _test_feature_switch(suite: CatBarTestSuite) -> void:
	var main := MAIN_SCENE.instantiate()
	suite.expect_true(bool(main.get("cat_bar_enabled")), "主场景应默认启用 CatBar")
	main.set("cat_bar_enabled", false)
	suite.expect_true(not bool(main.get("cat_bar_enabled")), "功能开关应允许回退旧 TavernLoop")
	suite.expect_true(CAT_BAR_SCENE.can_instantiate(), "CatBar 场景应可独立装配")
	suite.expect_true(TAVERN_SCENE.can_instantiate(), "旧 TavernLoop 场景应继续可实例化")
	main.free()


func _test_window_and_economy(suite: CatBarTestSuite) -> void:
	var window_config := DesktopWindowConfig.new()
	suite.expect_equal(window_config.default_window_size, Vector2i(960, 540), "桌面窗口默认值应匹配 CatBar 世界画布")
	var economy := EconomyState.new()
	economy.restore({"coins": 4, "business_xp": 2, "served_customers_total": 1})
	economy.award_service_reward(6, 3)
	suite.expect_equal(economy.to_save_data(), {"coins": 10, "business_xp": 5, "served_customers_total": 2}, "旧经济累计与存档字段必须兼容")
	economy.free()
