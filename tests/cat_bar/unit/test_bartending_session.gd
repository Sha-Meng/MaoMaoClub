extends RefCounted

const DEFAULT_CATALOG := preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("标准配方完成与幂等送达", _test_complete_recipe.bind(suite))
	suite.run_case("失败命令事务无副作用", _test_failed_transaction.bind(suite))
	suite.run_case("不完美但可饮用成品", _test_imperfect_drink.bind(suite))
	suite.run_case("非法状态与安全取消", _test_illegal_state_and_cancel.bind(suite))


func _make_session() -> BartendingSessionState:
	var catalog := DEFAULT_CATALOG as CatBarContentCatalog
	var content := CatBarContentRegistry.new()
	content.build(catalog)
	var session := BartendingSessionState.new()
	session.start(&"session_1", 101, &"moonlit_meow", &"booth_a", content, InteractionExecutorRegistry.new())
	return session


func _submit_standard_recipe(session: BartendingSessionState, gin_amount: float = 30.0) -> void:
	session.submit_command(InteractionCommand.new(&"moon_gin", &"jigger", &"pour_direct", gin_amount))
	session.submit_command(InteractionCommand.new(&"jigger", &"shaker", &"measure", 0.0, InteractionDefinition.Gesture.DRAG))
	session.submit_command(InteractionCommand.new(&"dusk_liqueur", &"shaker", &"pour_direct", 30.0))
	session.submit_command(InteractionCommand.new(&"clear_ice", &"shaker", &"drop_ice", 1.0))
	session.submit_command(InteractionCommand.new(&"clear_ice", &"shaker", &"drop_ice", 1.0))
	session.submit_command(InteractionCommand.new(&"catnip_spice", &"shaker", &"sprinkle", 1.0))
	session.submit_command(InteractionCommand.new(&"shaker", &"shaker", &"toggle_seal", 1.0, InteractionDefinition.Gesture.TOGGLE))
	session.begin_shake()
	session.submit_command(InteractionCommand.new(
		&"shaker",
		&"shaker",
		&"shake",
		4.0,
		InteractionDefinition.Gesture.SHAKE,
		{&"duration": 4.0, &"distance": 320.0, &"reversals": 8.0, &"peak_speed": 420.0}
	))
	session.begin_pour()
	session.submit_command(InteractionCommand.new(
		&"shaker", &"coupe_glass", &"strain_pour", 60.0, InteractionDefinition.Gesture.POUR
	))


func _test_complete_recipe(suite: CatBarTestSuite) -> void:
	var session := _make_session()
	_submit_standard_recipe(session)
	var result := session.evaluate_current()
	suite.expect_true(result != null and result.valid, "标准配方应产生可交付成品")
	suite.expect_equal(result.quality, 100, "标准配方品质应为 100")
	suite.expect_equal(session.state, BartendingSessionState.State.READY_TO_SERVE, "评价后应进入待送达")
	var delivery_key := session.make_delivery_key()
	suite.expect_true(session.mark_delivered(delivery_key), "第一次合法送达应成功")
	suite.expect_true(not session.mark_delivered(delivery_key), "重复送达必须被拒绝")
	suite.expect_equal(session.order_id, 101, "送达结果应保持订单绑定")
	suite.expect_equal(session.booth_id, &"booth_a", "送达结果应保持卡座绑定")


func _test_failed_transaction(suite: CatBarTestSuite) -> void:
	var session := _make_session()
	var before := session.get_draft_snapshot()
	var result := session.submit_command(InteractionCommand.new(&"moon_gin", &"shaker", &"pour_direct", 400.0))
	suite.expect_true(not result.success, "超过容量的加液必须失败")
	suite.expect_near(session.get_draft_snapshot().total_amount(&"shaker"), before.total_amount(&"shaker"), 0.001, "失败命令不得改变容器")
	suite.expect_equal(session.get_step_log().size(), 0, "失败命令不得追加步骤日志")


func _test_imperfect_drink(suite: CatBarTestSuite) -> void:
	var session := _make_session()
	_submit_standard_recipe(session, 38.0)
	var result := session.evaluate_current()
	suite.expect_true(result != null and result.valid, "包含核心成分的轻微偏差应仍可饮用")
	suite.expect_true(result.quality < 100 and result.quality >= 35, "偏差成品应降低品质但高于送达门槛")
	suite.expect_true(result.tags.has(&"amount_deviation"), "偏差成品应提供具体标签")


func _test_illegal_state_and_cancel(suite: CatBarTestSuite) -> void:
	var session := _make_session()
	suite.expect_true(not session.mark_delivered(&"early"), "未评价成品不得直接送达")
	suite.expect_true(not session.begin_shake().success, "未封盖不得开始 Shake")
	session.submit_command(InteractionCommand.new(&"moon_gin", &"shaker", &"pour_direct", 30.0))
	suite.expect_true(session.cancel(), "提交前应可安全取消")
	suite.expect_equal(session.state, BartendingSessionState.State.CANCELLED, "取消后状态必须明确")
	suite.expect_equal(session.get_step_log().size(), 0, "取消应清理临时步骤")
	suite.expect_near(session.get_draft_snapshot().total_amount(&"shaker"), 0.0, 0.001, "取消应清空临时容器")

