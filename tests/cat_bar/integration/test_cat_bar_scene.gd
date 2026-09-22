extends RefCounted

const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")


func run(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var before := suite.failures.size()
	await _test_mode_and_focus_continuity(suite, tree)
	_complete_async_case(suite, before, "CatBar 镜头、焦点与会话连续性")


func _test_mode_and_focus_continuity(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var cat_bar := CAT_BAR_SCENE.instantiate() as CatBarController
	tree.root.add_child(cat_bar)
	await tree.process_frame
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "CatBar 应从全景模式启动")
	suite.expect_equal(cat_bar.get_focus_owner(), &"world", "全景场景调酒应由世界焦点接管指针")
	var station := cat_bar.get_bartending_station()
	var station_id := station.get_instance_id()
	suite.expect_true(station.visible, "全景启动后应立即显示可直接抓取的场景调酒实体")
	suite.expect_true(station.get_scene_grab_source_count() >= 2, "全景应直接绑定调酒师与打工猫作为场景抓取来源")
	suite.expect_true(cat_bar.enter_mixing(true), "旧进入调用应兼容为无转场的场景直取入口")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "兼容入口不得切换调酒近景")
	suite.expect_true(station.begin_drag_for_test(&"bartender_cat"), "调酒师猫猫应可从场景原位抓起")
	suite.expect_true(station.is_scene_source_displaced(&"bartender_cat"), "抓取期间真实调酒师节点应从原位消失")
	station.cancel_drag_for_test()
	suite.expect_true(not station.is_scene_source_displaced(&"bartender_cat"), "取消抓取后调酒师应恢复原位")
	suite.expect_true(station.begin_drag_for_test(&"bartender_cat"), "应能再次抓起调酒师猫猫")
	suite.expect_true(station.finish_active_drag_on_target_for_test(), "释放到 Shake 杯应启动动物原料表现序列")
	suite.expect_true(station.is_animal_sequence_playing(), "掉落与埋猫砂期间应保持动画锁定")
	suite.expect_true(station.is_scene_source_displaced(&"bartender_cat"), "动画结束前真实调酒师节点应保持离位")
	suite.expect_near(station.get_session().get_draft_snapshot().get_contents(&"shaker").get(&"animal_droppings", 0.0), 1.0, 0.001, "动物掉落物应以稳定原料 ID 进入会话")
	await tree.create_timer(1.8).timeout
	suite.expect_true(not station.is_animal_sequence_playing(), "排泄物落杯与埋猫砂动画应按时结束")
	suite.expect_true(not station.is_scene_source_displaced(&"bartender_cat"), "埋猫砂结束后调酒师应回到原场景位置")
	var old_session_id := station.get_session().session_id
	station.click_content(&"moon_gin")
	suite.expect_true(station.request_exit_for_test(true), "Esc 应发出安全清空请求")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "清空当前杯后应继续留在全景")
	suite.expect_equal(station.get_session().state, BartendingSessionState.State.PREPARING, "清空后应立即创建干净会话")
	suite.expect_true(station.get_session().session_id != old_session_id, "清空后应使用新的会话 ID")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"shaker"), 0.0, 0.001, "新会话不得继承旧配料")

	suite.expect_true(cat_bar.open_phone(), "准备阶段应允许打开手机")
	suite.expect_true(cat_bar.is_phone_visible(), "手机层应在打开后可见")
	suite.expect_equal(cat_bar.get_focus_owner(), &"phone", "手机打开时应独占指针焦点")
	suite.expect_true(cat_bar.close_phone(), "手机应能返回原模式")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "关闭手机应恢复全景场景调酒")
	suite.expect_equal(cat_bar.get_bartending_station().get_instance_id(), station_id, "手机往返不得重建活动会话")

	station.click_content(&"moon_gin")
	station.toggle_seal()
	suite.expect_true(station.begin_shake(), "封盖后应进入 Shake 指针捕获")
	suite.expect_true(not cat_bar.open_phone(), "Shake 期间必须拒绝手机覆盖")
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	station._input(cancel_event)
	await tree.create_timer(0.4).timeout
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "Shake 中按 Esc 后仍应留在全景")
	suite.expect_equal(cat_bar.get_focus_owner(), &"world", "清空后世界应继续持有焦点")
	cat_bar.queue_free()
	await tree.process_frame


func _complete_async_case(suite: CatBarTestSuite, failure_count_before: int, test_name: String) -> void:
	if suite.failures.size() == failure_count_before:
		suite.passed += 1
		print("PASS: %s" % test_name)
	else:
		suite.failed += 1
		print("FAIL: %s" % test_name)
