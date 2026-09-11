extends RefCounted

const CATALOG: WechatContentCatalog = preload("res://features/phone/wechat/configs/default_wechat_catalog.tres")


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("微信初始联系人和事件幂等解锁", _test_contacts_and_idempotency.bind(suite))
	suite.run_case("微信生成相同事件序列可确定重放", _test_deterministic_replay.bind(suite))
	suite.run_case("微信无模板安全跳过且旧历史稳定", _test_no_candidate_and_history_stability.bind(suite))
	suite.run_case("微信历史容量淘汰保留最新内容", _test_capacity.bind(suite))
	suite.run_case("联系人配置完整且聊天秒回不影响事件游标", _test_profiles_and_instant_reply.bind(suite))
	suite.run_case("新存档朋友圈丰富且初始化可确定重放", _test_initial_moments.bind(suite))


func _test_contacts_and_idempotency(suite: CatBarTestSuite) -> void:
	var service := WechatService.new()
	suite.expect_equal(service.state.unlocked_contact_ids.size(), 3, "新存档必须恰好包含三个初始联系人")
	suite.expect_true(service.state.unlocked_contact_ids.has(&"manager_cat"), "初始联系人应包含店长猫")
	suite.expect_true(service.state.unlocked_contact_ids.has(&"worker_cat"), "初始联系人应包含打工猫")
	suite.expect_true(service.state.unlocked_contact_ids.has(&"regular_mingcai"), "初始联系人应包含酒吧常客名菜")
	suite.expect_true(service.consume_event(&"meet_001", &"meet_patron", &"traveler_cat"), "认识顾客事件应被消费")
	suite.expect_true(service.state.unlocked_contact_ids.has(&"traveler_cat"), "认识顾客应解锁新朋友")
	var cursor := service.state.cursor
	suite.expect_true(not service.consume_event(&"meet_001", &"meet_patron", &"traveler_cat"), "重复事件 ID 应被拒绝")
	suite.expect_equal(service.state.cursor, cursor, "重复事件不得推进生成游标")


func _test_deterministic_replay(suite: CatBarTestSuite) -> void:
	var first := WechatService.new()
	var second := WechatService.new()
	var events: Array[Array] = [
		[&"day_1", &"new_day"], [&"delivery_1", &"order_delivered"], [&"day_2", &"new_day"],
	]
	for event: Array in events:
		first.consume_event(event[0], event[1])
		second.consume_event(event[0], event[1])
	suite.expect_equal(JSON.stringify(first.state.to_save_data()), JSON.stringify(second.state.to_save_data()), "相同状态与事件序列必须生成相同实例")


func _test_no_candidate_and_history_stability(suite: CatBarTestSuite) -> void:
	var catalog := CATALOG.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as WechatContentCatalog
	var service := WechatService.new(catalog)
	service.consume_event(&"unknown_1", &"unknown")
	suite.expect_equal(service.state.messages.size(), 0, "无合格模板不得创建空消息")
	suite.expect_equal(service.last_diagnostic, "没有满足条件的模板", "无模板应留下可诊断原因")
	service.consume_event(&"delivery_1", &"order_delivered")
	var old_text := service.state.messages[0].text
	catalog.message_templates[0].text = "更新后的模板文案"
	suite.expect_equal(service.state.messages[0].text, old_text, "模板更新不得改变已生成历史")


func _test_capacity(suite: CatBarTestSuite) -> void:
	var catalog := CATALOG.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as WechatContentCatalog
	catalog.message_history_limit = 2
	catalog.moment_history_limit = 2
	for template: WechatMessageTemplate in catalog.message_templates:
		template.cooldown_events = 0
	for template: WechatMomentTemplate in catalog.moment_templates:
		template.cooldown_events = 0
	var service := WechatService.new(catalog)
	for index: int in range(8):
		service.consume_event(StringName("delivery_%d" % index), &"order_delivered")
	suite.expect_true(service.state.messages.size() <= 2, "消息历史必须受配置上限约束")
	suite.expect_true(service.state.moments.size() <= 2, "朋友圈历史必须受配置上限约束")
	suite.expect_true(service.state.messages.back().sequence >= 6, "容量淘汰应保留最新消息")


func _test_profiles_and_instant_reply(suite: CatBarTestSuite) -> void:
	var service := WechatService.new()
	for contact: WechatContactDefinition in service.catalog.contacts:
		suite.expect_equal(contact.validate_definition().size(), 0, "%s 的人格和回复配置必须完整" % contact.contact_id)
	var cursor_before := service.state.cursor
	var message_count_before := service.state.messages.size()
	var reply := service.send_player_message(&"manager_cat", "你好，今晚的经典鸡尾酒怎么练？")
	suite.expect_true(reply != null, "有效文本必须立即得到联系人回复")
	suite.expect_equal(service.state.messages.size(), message_count_before + 2, "发送一次应追加玩家消息与好友回复")
	var player_message := service.state.messages[-2]
	suite.expect_true(player_message.from_player and not reply.from_player, "聊天历史必须区分玩家与好友方向")
	suite.expect_equal(player_message.author_id, &"manager_cat", "玩家消息必须归入当前联系人会话")
	suite.expect_true(not reply.text.strip_edges().is_empty(), "秒回文本不能为空")
	suite.expect_equal(service.state.cursor, cursor_before, "玩家聊天不得改变外围事件游标")
	var sequence_after := service.state.next_message_sequence
	suite.expect_true(service.send_player_message(&"manager_cat", "   ") == null, "空白消息必须被拒绝")
	suite.expect_equal(service.state.next_message_sequence, sequence_after, "空白消息不得消耗聊天序列")

	var replay := WechatService.new()
	var replay_reply := replay.send_player_message(&"manager_cat", "你好，今晚的经典鸡尾酒怎么练？")
	suite.expect_equal(replay_reply.text, reply.text, "同一联系人、输入与状态必须得到确定性秒回")


func _test_initial_moments(suite: CatBarTestSuite) -> void:
	var first := WechatService.new()
	var second := WechatService.new()
	suite.expect_true(first.state.moments.size() >= 3, "新存档必须预生成至少三条朋友圈")
	var categories: Dictionary[StringName, bool] = {}
	for moment: WechatMomentInstance in first.state.moments:
		categories[moment.category] = true
		suite.expect_true(first.state.unlocked_contact_ids.has(moment.author_id), "初始朋友圈作者必须已解锁")
	suite.expect_true(categories.size() >= 2, "初始朋友圈至少应覆盖两个类别")
	suite.expect_equal(JSON.stringify(first.state.to_save_data()), JSON.stringify(second.state.to_save_data()), "初始朋友圈必须可确定重放")
