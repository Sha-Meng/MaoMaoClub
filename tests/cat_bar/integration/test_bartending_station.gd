extends RefCounted

const STATION_SCENE: PackedScene = preload("res://features/cat_bar/bartending/presentation/bartending_station.tscn")


func run(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var before := suite.failures.size()
	await _test_station_workflow(suite, tree)
	_complete_async_case(suite, before, "调酒工作台场景与代表性配方")


func _test_station_workflow(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var station := STATION_SCENE.instantiate() as BartendingStation
	tree.root.add_child(station)
	await tree.process_frame
	await tree.physics_frame
	suite.expect_equal(station.get_zone_count(), 5, "工作台应从配表构建五个分区")
	suite.expect_equal(station.get_content_button_count(), 11, "工作台应提供五种基酒、三种工具和三种辅料")
	suite.expect_true(not station.is_fullscreen_panel_present(), "实体调酒层不应包含完整工作台面板或分类菜单")
	suite.expect_equal(station.get_diegetic_item_count(), 13, "场景应摆放原料、工具、杯盖与成品杯实体")
	for spirit_id: StringName in [&"moon_gin", &"dusk_liqueur", &"sunset_whiskey", &"dawn_vodka", &"daybreak_white_rum"]:
		suite.expect_true(station.menu_entry_has_image_and_name(spirit_id), "%s 应同时拥有图片和名称" % spirit_id)
	suite.expect_true(station.get_context_text_for_test(&"moon_gin").contains("30 ml"), "基酒悬停信息应包含固定剂量")
	suite.expect_true(station.begin_drag_for_test(&"moon_gin"), "基酒应可从场景中拿起")
	suite.expect_equal(station.get_highlighted_target_id(), &"jigger", "拿起基酒时量酒器应成为高亮目标")
	station.cancel_drag_for_test()
	for content_id: StringName in [&"shaker", &"jigger", &"bar_spoon", &"clear_ice", &"catnip_spice", &"premium_fish_oil"]:
		suite.expect_true(station.menu_entry_has_image_and_name(content_id), "%s 应同时拥有图片和名称" % content_id)
	var invalid_before := station.get_session().get_draft_snapshot().total_amount(&"shaker")
	var invalid_drop := station.simulate_drop_for_test(&"moon_gin", &"shaker")
	suite.expect_true(not invalid_drop.success, "基酒绕过量酒器的非法落点应被拒绝")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"shaker"), invalid_before, 0.001, "非法落点不得修改会话草稿")
	station.reset_session()
	suite.expect_true(not station.begin_shake(), "未封盖时工作台不得开始 Shake")

	var outside_before := float(station.get_session().get_draft_snapshot().action_totals.get(&"stir_distance", 0.0))
	station.begin_spoon_drag_for_test(Vector2(90.0, 90.0))
	var outside_result := station.end_spoon_drag_for_test(Vector2(120.0, 100.0), 1.0)
	suite.expect_true(not outside_result.success and outside_result.reason.contains("拖入"), "容器外释放长柄勺应给出明确反馈")
	suite.expect_near(float(station.get_session().get_draft_snapshot().action_totals.get(&"stir_distance", 0.0)), outside_before, 0.001, "失败拖拽不得记录搅拌")

	station.click_content(&"moon_gin")
	var target := station.get_spoon_drop_target_rect()
	var center := target.get_center()
	station.begin_spoon_drag_for_test(center)
	for point: Vector2 in [
		center + Vector2(30.0, 0.0), center + Vector2(0.0, 45.0),
		center + Vector2(-30.0, 0.0), center + Vector2(0.0, -45.0), center,
	]:
		station.update_spoon_drag_for_test(point)
	var stir_result := station.end_spoon_drag_for_test(center, 2.0)
	suite.expect_true(stir_result.success, "长柄勺在开放且有内容的容器内完成足够轨迹后应成功：%s" % stir_result.reason)
	suite.expect_true(float(station.get_session().get_draft_snapshot().action_totals.get(&"stir_distance", 0.0)) >= 80.0, "有效空间拖拽应写入搅拌轨迹")
	station.reset_session()

	station.simulate_drop_for_test(&"moon_gin", &"jigger")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"jigger"), 30.0, 0.001, "酒液应先进入量酒杯")
	station.simulate_drop_for_test(&"jigger", &"shaker")
	var shaker_after_first_measure := station.get_session().get_draft_snapshot().total_amount(&"shaker")
	suite.expect_true(not station.begin_drag_for_test(&"jigger"), "倒空后的量酒器不得再次进入拖拽倾倒")
	var repeated_measure := station.simulate_drop_for_test(&"jigger", &"shaker")
	suite.expect_true(not repeated_measure.success, "空量酒器重复倾倒必须失败")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"shaker"), shaker_after_first_measure, 0.001, "重复倾倒不得增加 Shake 杯内容")
	suite.expect_near(station.get_shaker_fill_ratio(), 0.1, 0.001, "Shake 杯 30 ml 液位应匹配 300 ml 容量")
	station.simulate_drop_for_test(&"dusk_liqueur", &"jigger")
	station.simulate_drop_for_test(&"jigger", &"shaker")
	station.simulate_drop_for_test(&"clear_ice", &"shaker")
	station.simulate_drop_for_test(&"clear_ice", &"shaker")
	station.simulate_drop_for_test(&"catnip_spice", &"shaker")
	station.submit_stir_gesture(120.0, 2.0)
	station.simulate_drop_for_test(&"shaker_lid", &"shaker")
	suite.expect_true(station.is_shaker_lid_aligned(), "封盖后杯盖底沿应贴合 Shake 杯杯口")
	suite.expect_true(station.get_context_text_for_test(&"shaker").contains("月光金酒  30 ml"), "Shake 杯悬停信息应列出液体和毫升数")
	var shake_result := station.complete_shake_for_test({
		&"duration": 4.0,
		&"distance": 320.0,
		&"reversals": 8.0,
		&"peak_speed": 420.0,
	})
	suite.expect_true(shake_result.success, "工作台应接受有效 Shake 指标")
	var mixed_color := station.get_shaker_liquid_color()
	var pour_result := station.pour_to_glass()
	suite.expect_true(pour_result.success, "工作台应把成品倒入目标酒杯")
	var drink := station.get_session().get_last_result()
	suite.expect_true(drink != null and drink.valid, "代表性配方应得到可送达成品")
	suite.expect_near(station.get_serving_glass_fill_ratio(), 60.0 / 180.0, 0.001, "成品杯液位应匹配实际倒入量和杯容量")
	var served_color := station.get_serving_glass_liquid_color()
	suite.expect_true(
		absf(served_color.r - mixed_color.r) < 0.001
		and absf(served_color.g - mixed_color.g) < 0.001
		and absf(served_color.b - mixed_color.b) < 0.001,
		"成品杯与 Shake 杯应使用同一配方液体颜色"
	)
	suite.expect_true(station.get_status_text().begins_with("✓"), "成功反馈应展示在工作台")
	station.queue_free()
	await tree.process_frame


func _complete_async_case(suite: CatBarTestSuite, failure_count_before: int, test_name: String) -> void:
	if suite.failures.size() == failure_count_before:
		suite.passed += 1
		print("PASS: %s" % test_name)
	else:
		suite.failed += 1
		print("FAIL: %s" % test_name)
