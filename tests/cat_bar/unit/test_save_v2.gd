extends RefCounted

const CONTENT_CATALOG: CatBarContentCatalog = preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("v2 新存档与 v1 迁移保留旧字段", _test_default_and_migration.bind(suite))
	suite.run_case("调酒会话 v2 往返与未知 ID 过滤", _test_bartending_round_trip.bind(suite))
	suite.run_case("微信 v2 往返、局部损坏回退与历史不重复", _test_wechat_round_trip.bind(suite))


func _test_default_and_migration(suite: CatBarTestSuite) -> void:
	var saves := SaveService.new()
	var defaults := saves.make_default_save()
	suite.expect_equal(defaults["save_version"], 2, "新存档版本必须为 v2")
	suite.expect_true(defaults["bartending"] is Dictionary and defaults["wechat"] is Dictionary and defaults["content_unlocks"] is Dictionary, "v2 应包含三个独立扩展分区")
	var migrated := saves.normalize_save_data({
		"save_version": 1, "coins": 41, "business_xp": 7, "served_customers_total": 3,
		"window_position": Vector2i(10, 20), "window_size": Vector2i(900, 400),
	})
	suite.expect_equal(migrated["coins"], 41, "v1 迁移必须保留金币")
	suite.expect_equal(migrated["window_size"], Vector2i(900, 400), "v1 迁移必须保留窗口尺寸")
	var wechat := WechatService.new()
	wechat.restore(migrated["wechat"])
	suite.expect_equal(wechat.state.unlocked_contact_ids.size(), 3, "v1 迁移应补齐三个初始联系人")
	var damaged := saves.normalize_save_data({"coins": 5, "wechat": "bad", "content_unlocks": 9})
	suite.expect_equal(damaged["coins"], 5, "一个损坏分区不得影响经济字段")
	suite.expect_true(damaged["wechat"] is Dictionary and damaged["content_unlocks"] is Dictionary, "损坏分区应局部回退默认值")
	saves.free()


func _test_bartending_round_trip(suite: CatBarTestSuite) -> void:
	var registry := CatBarContentRegistry.new()
	registry.build(CONTENT_CATALOG)
	var executors := InteractionExecutorRegistry.new()
	var session := BartendingSessionState.new()
	session.start(&"save_session", 12, &"moonlit_meow", &"booth_a", registry, executors)
	var command := InteractionCommand.new(&"moon_gin", &"shaker", &"pour_direct", 30.0, InteractionDefinition.Gesture.CLICK)
	suite.expect_true(session.submit_command(command).success, "测试会话应写入一项合法步骤")
	var data := session.to_save_data()
	data["draft"]["container_contents"]["shaker"]["retired_liquid"] = 99999.0
	var restored := BartendingSessionState.new()
	suite.expect_true(restored.restore_from_save(data, registry, executors, SaveService.DEPRECATED_CONTENT_IDS), "合法活动会话应可恢复")
	suite.expect_equal(restored.session_id, &"save_session", "恢复后会话绑定应保持")
	suite.expect_near(restored.get_draft_snapshot().total_amount(&"shaker"), 30.0, 0.001, "未知内容 ID 应被过滤且合法剂量保留")


func _test_wechat_round_trip(suite: CatBarTestSuite) -> void:
	var first := WechatService.new()
	first.consume_event(&"day_1", &"new_day")
	first.consume_event(&"delivery_1", &"order_delivered")
	first.send_player_message(&"worker_cat", "你好，冰块补好了吗？")
	var data := first.to_save_data()
	data["unlocked_contact_ids"].append("unknown_contact")
	data["messages"].append({"instance_id": "bad", "author_id": "unknown_contact", "text": "不应恢复"})
	var second := WechatService.new()
	second.restore(data, SaveService.DEPRECATED_CONTENT_IDS)
	suite.expect_equal(second.state.messages.size(), first.state.messages.size(), "未知联系人消息应过滤，合法历史应恢复")
	suite.expect_equal(second.state.cursor, first.state.cursor, "确定性游标应恢复")
	suite.expect_equal(second.state.next_message_sequence, first.state.next_message_sequence, "独立聊天序列应恢复")
	var restored_player_messages := 0
	for restored_message: WechatMessageInstance in second.state.messages:
		if restored_message.from_player:
			restored_player_messages += 1
	suite.expect_equal(restored_player_messages, 1, "玩家消息方向应在 v2 微信分区中往返保存")
	var before_instances: Dictionary[StringName, bool] = {}
	for message: WechatMessageInstance in second.state.messages:
		before_instances[message.instance_id] = true
	second.consume_event(&"day_2", &"new_day")
	var after_instances: Dictionary[StringName, bool] = {}
	for message: WechatMessageInstance in second.state.messages:
		after_instances[message.instance_id] = true
	for instance_id: StringName in before_instances:
		suite.expect_true(after_instances.has(instance_id), "恢复后不得删除、复制或改写旧随机历史")
