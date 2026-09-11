extends RefCounted

const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")


func run(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var before := suite.failures.size()
	await _test_manual_drink_delivery_and_progression(suite, tree)
	_complete_async_case(suite, before, "调酒师放杯、打工猫送达与经营单次结算")


func _test_manual_drink_delivery_and_progression(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var cat_bar := CAT_BAR_SCENE.instantiate() as CatBarController
	tree.root.add_child(cat_bar)
	await tree.process_frame
	cat_bar.set_delivery_instant_for_test(true)
	cat_bar.get_worker_cat().instant_delivery = false
	cat_bar.get_worker_cat().movement_seconds = 0.05
	cat_bar.get_worker_cat().timeout_seconds = 1.0
	cat_bar.enter_mixing(true)
	var station := cat_bar.get_bartending_station()
	var delivery_count: Array[int] = [0]
	var service_events: PackedStringArray = PackedStringArray()
	cat_bar.bartender_placed_drink.connect(func(_delivery_key: StringName) -> void:
		service_events.append("bartender_placed")
	)
	cat_bar.worker_picked_drink.connect(func(_delivery_key: StringName) -> void:
		service_events.append("worker_picked")
	)
	cat_bar.drink_delivered.connect(func(_order_id: int, _drink: DrinkResult, _rewards: Dictionary) -> void:
		service_events.append("delivered")
		delivery_count[0] += 1
	)

	station.click_content(&"jigger")
	station.click_content(&"moon_gin")
	station.click_content(&"jigger")
	station.click_content(&"dusk_liqueur")
	station.click_content(&"clear_ice")
	station.click_content(&"clear_ice")
	station.click_content(&"catnip_spice")
	station.submit_stir_gesture(120.0, 2.0)
	station.toggle_seal()
	station.complete_shake_for_test({&"duration": 4.0, &"distance": 320.0, &"reversals": 8.0, &"peak_speed": 420.0})
	var pour_result := station.pour_to_glass()
	suite.expect_true(pour_result.success, "完整闭环应成功倒杯")
	suite.expect_true(cat_bar.get_counter_drink().has_drink(), "调酒师放杯后成品应暂时显示在吧台交接点")
	suite.expect_equal(service_events, PackedStringArray(["bartender_placed"]), "打工猫抵达前只能完成调酒师放杯阶段")
	await tree.create_timer(0.55).timeout
	suite.expect_equal(service_events, PackedStringArray(["bartender_placed", "worker_picked", "delivered"]), "服务阶段必须按调酒师放杯、打工猫取杯、卡座送达执行")
	suite.expect_equal(delivery_count[0], 1, "打工猫降级路径只应发出一次送达")
	suite.expect_true(not cat_bar.get_counter_drink().has_drink(), "打工猫取杯后吧台交接点不应残留成品")
	suite.expect_equal(cat_bar.get_economy().served_customers_total, 1, "奖励只能在送达后结算")
	suite.expect_true(cat_bar.get_economy().coins > 0, "送达品质应产生金币奖励")
	suite.expect_equal(cat_bar.get_progression().materials.get(&"catnip_leaf", 0), 1, "送达应掉落研发材料")
	suite.expect_true(cat_bar.get_progression().research(&"starlight_fizz"), "材料应可研发新酒水")
	var before_multiplier := cat_bar.get_progression().reward_multiplier()
	suite.expect_true(cat_bar.get_progression().add_to_menu(&"starlight_fizz"), "已研发酒水应可加入今日菜单")
	suite.expect_true(cat_bar.get_progression().reward_multiplier() > before_multiplier, "菜单变化应影响后续收益结果")
	suite.expect_true(not station.get_session().mark_delivered(station.get_session().make_delivery_key()), "重复送达不得再次提交")
	suite.expect_equal(cat_bar.get_economy().served_customers_total, 1, "重复送达不得重复结算")
	cat_bar.queue_free()
	await tree.process_frame


func _complete_async_case(suite: CatBarTestSuite, failure_count_before: int, test_name: String) -> void:
	if suite.failures.size() == failure_count_before:
		suite.passed += 1
		print("PASS: %s" % test_name)
	else:
		suite.failed += 1
		print("FAIL: %s" % test_name)
