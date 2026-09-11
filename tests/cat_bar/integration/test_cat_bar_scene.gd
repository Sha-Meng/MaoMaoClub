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
	suite.expect_equal(cat_bar.get_focus_owner(), &"world", "全景模式应独占世界指针焦点")
	var station := cat_bar.get_bartending_station()
	var station_id := station.get_instance_id()
	suite.expect_true(not station.visible, "全景模式不应显示调酒工作台")

	suite.expect_true(cat_bar.enter_mixing(true), "首次点击吧台应进入调酒近景")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.MIXING, "即时镜头完成后应进入调酒模式")
	suite.expect_equal(cat_bar.get_focus_owner(), &"bartending", "调酒模式应独占工作台指针焦点")
	suite.expect_true(station.visible, "调酒模式应显示工作台")
	suite.expect_true(not cat_bar.enter_mixing(true), "重复点击不应启动第二次转场")
	var old_session_id := station.get_session().session_id
	station.click_content(&"moon_gin")
	suite.expect_true(station.request_exit_for_test(true), "调酒台返回按钮应发出安全退出请求")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "调酒台退出请求应返回全景")
	suite.expect_equal(station.get_session().state, BartendingSessionState.State.CANCELLED, "退出应取消未提交会话")
	suite.expect_true(cat_bar.enter_mixing(true), "取消后应能再次进入调酒台")
	suite.expect_equal(station.get_session().state, BartendingSessionState.State.PREPARING, "重新进入应创建准备中的干净会话")
	suite.expect_true(station.get_session().session_id != old_session_id, "重新进入应使用新的会话 ID")
	suite.expect_near(station.get_session().get_draft_snapshot().total_amount(&"shaker"), 0.0, 0.001, "新会话不得继承旧配料")

	suite.expect_true(cat_bar.open_phone(), "准备阶段应允许打开手机")
	suite.expect_true(cat_bar.is_phone_visible(), "手机层应在打开后可见")
	suite.expect_equal(cat_bar.get_focus_owner(), &"phone", "手机打开时应独占指针焦点")
	suite.expect_true(cat_bar.close_phone(), "手机应能返回原模式")
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.MIXING, "关闭手机应恢复调酒模式")
	suite.expect_equal(cat_bar.get_bartending_station().get_instance_id(), station_id, "镜头和手机往返不得重建活动会话")

	station.click_content(&"moon_gin")
	station.toggle_seal()
	suite.expect_true(station.begin_shake(), "封盖后应进入 Shake 指针捕获")
	suite.expect_true(not cat_bar.open_phone(), "Shake 期间必须拒绝手机覆盖")
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	station._input(cancel_event)
	await tree.create_timer(0.4).timeout
	suite.expect_equal(cat_bar.get_mode(), CatBarModeController.Mode.OVERVIEW, "返回镜头完成后应恢复全景")
	suite.expect_equal(cat_bar.get_focus_owner(), &"world", "返回全景后世界应重新获得焦点")
	cat_bar.queue_free()
	await tree.process_frame


func _complete_async_case(suite: CatBarTestSuite, failure_count_before: int, test_name: String) -> void:
	if suite.failures.size() == failure_count_before:
		suite.passed += 1
		print("PASS: %s" % test_name)
	else:
		suite.failed += 1
		print("FAIL: %s" % test_name)
