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
	suite.expect_equal(station.get_content_button_count(), 8, "工作台应构建八个内容交互入口")
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

	station.click_content(&"jigger")
	station.click_content(&"moon_gin")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"jigger"), 30.0, 0.001, "酒液应先进入量酒杯")
	station.click_content(&"jigger")
	station.click_content(&"dusk_liqueur")
	station.click_content(&"clear_ice")
	station.click_content(&"clear_ice")
	station.click_content(&"catnip_spice")
	station.submit_stir_gesture(120.0, 2.0)
	station.toggle_seal()
	var shake_result := station.complete_shake_for_test({
		&"duration": 4.0,
		&"distance": 320.0,
		&"reversals": 8.0,
		&"peak_speed": 420.0,
	})
	suite.expect_true(shake_result.success, "工作台应接受有效 Shake 指标")
	var pour_result := station.pour_to_glass()
	suite.expect_true(pour_result.success, "工作台应把成品倒入目标酒杯")
	var drink := station.get_session().get_last_result()
	suite.expect_true(drink != null and drink.valid, "代表性配方应得到可送达成品")
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
