extends RefCounted

const DEFAULT_CATALOG := preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")


func run(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var before := suite.failures.size()
	await _test_embedded_vessel(suite, tree)
	_complete_async_case(suite, before, "产品适配器复用 Shake 与流体公开接口")
	suite.run_case("视觉粒子档位不改变业务评价", _test_visual_profile_independence.bind(suite))


func _test_embedded_vessel(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var adapter := MixingVesselAdapter.new()
	tree.root.add_child(adapter)
	await tree.physics_frame
	await tree.physics_frame
	suite.expect_true(adapter.add_fluid(0), "适配器应能加入现有 fluid_id=0")
	suite.expect_equal(adapter.add_ice(2), 2, "适配器应逐块加入两块冰")
	adapter.set_sealed(true)
	suite.expect_true(adapter.begin_shake(), "封盖后应能通过适配器开始 Shake")
	var before_positions := adapter.visual_snapshot().fluid_positions_local_meters.duplicate()
	for index: int in range(8):
		var direction := -1.0 if index % 2 == 0 else 1.0
		adapter.apply_shake_delta(Vector2(90.0 * direction, -45.0 * direction), 0.5)
		await tree.physics_frame
	var metrics := adapter.end_shake()
	for _index: int in range(4):
		await tree.physics_frame
	var snapshot := adapter.visual_snapshot()
	suite.expect_true(float(metrics[&"duration"]) >= 4.0, "适配器应记录 Shake 持续时间")
	suite.expect_true(float(metrics[&"distance"]) > 240.0, "适配器应记录累计拖拽距离")
	suite.expect_true(float(metrics[&"reversals"]) >= 6.0, "适配器应记录方向反转")
	suite.expect_equal(snapshot.ice_count, 2, "只读快照应报告冰块数量")
	suite.expect_true(snapshot.sealed, "只读快照应报告封盖状态")
	suite.expect_true(snapshot.fluid_contained and snapshot.ice_contained, "封盖 Shake 后内容必须保持在杯内")
	suite.expect_equal(snapshot.fluid_positions_local_meters.size(), snapshot.particle_count, "产品快照应转发全部流体粒子位置")
	suite.expect_equal(snapshot.ice_positions_local_meters.size(), snapshot.ice_count, "产品快照应转发全部冰块位置")
	suite.expect_true(_positions_changed(before_positions, snapshot.fluid_positions_local_meters), "Shake 后至少一部分液体粒子局部位置必须变化")
	adapter.queue_free()
	await tree.process_frame


func _test_visual_profile_independence(suite: CatBarTestSuite) -> void:
	var coarse_result := _make_business_result(36)
	var detailed_result := _make_business_result(136)
	suite.expect_equal(coarse_result.valid, detailed_result.valid, "粒子档位不得改变有效性")
	suite.expect_equal(coarse_result.quality, detailed_result.quality, "粒子档位不得改变品质")
	suite.expect_equal(coarse_result.differences, detailed_result.differences, "粒子档位不得改变偏差列表")


func _make_business_result(_visual_particle_budget: int) -> DrinkResult:
	var catalog := DEFAULT_CATALOG as CatBarContentCatalog
	var registry := CatBarContentRegistry.new()
	registry.build(catalog)
	var session := BartendingSessionState.new()
	session.start(&"profile_test", 7, &"moonlit_meow", &"booth_a", registry, InteractionExecutorRegistry.new())
	session.submit_command(InteractionCommand.new(&"moon_gin", &"jigger", &"pour_direct", 30.0))
	session.submit_command(InteractionCommand.new(&"jigger", &"shaker", &"measure", 0.0, InteractionDefinition.Gesture.DRAG))
	session.submit_command(InteractionCommand.new(&"dusk_liqueur", &"jigger", &"pour_direct", 30.0))
	session.submit_command(InteractionCommand.new(&"jigger", &"shaker", &"measure", 0.0, InteractionDefinition.Gesture.DRAG))
	session.submit_command(InteractionCommand.new(&"clear_ice", &"shaker", &"drop_ice", 2.0))
	session.submit_command(InteractionCommand.new(&"catnip_spice", &"shaker", &"sprinkle", 1.0))
	session.submit_command(InteractionCommand.new(&"shaker", &"shaker", &"toggle_seal", 1.0, InteractionDefinition.Gesture.TOGGLE))
	session.begin_shake()
	session.submit_command(InteractionCommand.new(&"shaker", &"shaker", &"shake", 4.0, InteractionDefinition.Gesture.SHAKE, {&"duration": 4.0, &"distance": 320.0}))
	session.begin_pour()
	session.submit_command(InteractionCommand.new(&"shaker", &"coupe_glass", &"strain_pour", 60.0, InteractionDefinition.Gesture.POUR))
	return session.evaluate_current()


func _positions_changed(before: PackedVector2Array, after: PackedVector2Array) -> bool:
	if before.size() != after.size() or before.is_empty():
		return before.size() != after.size()
	for index: int in range(before.size()):
		if before[index].distance_to(after[index]) > 0.001:
			return true
	return false


func _complete_async_case(suite: CatBarTestSuite, failure_count_before: int, test_name: String) -> void:
	if suite.failures.size() == failure_count_before:
		suite.passed += 1
		print("PASS: %s" % test_name)
	else:
		suite.failed += 1
		print("FAIL: %s" % test_name)
