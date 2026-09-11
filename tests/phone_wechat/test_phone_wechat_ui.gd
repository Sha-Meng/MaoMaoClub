extends RefCounted

const PHONE_SCENE: PackedScene = preload("res://features/phone/shell/phone_shell.tscn")


func run(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var before := suite.failures.size()
	await _test_phone_and_tabs(suite, tree)
	if suite.failures.size() == before:
		suite.passed += 1
		print("PASS: 手机壳、微信三页签、双击聊天与秒回")
	else:
		suite.failed += 1
		print("FAIL: 手机壳、微信三页签、双击聊天与秒回")


func _test_phone_and_tabs(suite: CatBarTestSuite, tree: SceneTree) -> void:
	var service := WechatService.new()
	service.consume_event(&"day_1", &"new_day")
	service.consume_event(&"delivery_1", &"order_delivered")
	var cursor_before := service.state.cursor
	var phone := PHONE_SCENE.instantiate() as PhoneShell
	tree.root.add_child(phone)
	await tree.process_frame
	phone.bind_wechat(service)
	phone.set_open(true)
	phone.press_unavailable_app("打车")
	suite.expect_true(phone.get_status_text().contains("尚未开放"), "未实现应用应显示明确反馈")
	suite.expect_equal(phone.current_page(), &"home", "未实现应用不得破坏返回栈")
	phone.open_wechat()
	suite.expect_equal(phone.current_page(), &"wechat", "微信入口应打开真实页面")
	var view := phone.get_wechat_view()
	view.select_tab(WechatView.Tab.MESSAGES)
	suite.expect_true(view.visible_entry_count() > 0, "消息页应展示会话摘要")
	var unread_before := service.state.unread_total()
	view.open_conversation(service.state.messages.back().author_id)
	suite.expect_true(service.state.unread_total() < unread_before, "打开会话应清零该好友未读")
	view.select_tab(WechatView.Tab.CONTACTS)
	suite.expect_equal(view.visible_entry_count(), 3, "联系人页应展示三个初始朋友")
	var contact_button := view.find_child("Contact_manager_cat", true, false) as Button
	suite.expect_true(contact_button != null, "联系人页应创建可交互的店长猫条目")
	if contact_button != null:
		var double_click := InputEventMouseButton.new()
		double_click.button_index = MOUSE_BUTTON_LEFT
		double_click.pressed = true
		double_click.double_click = true
		contact_button.gui_input.emit(double_click)
		suite.expect_equal(view.current_tab(), WechatView.Tab.MESSAGES, "双击联系人应切换到消息页")
		suite.expect_equal(view.selected_contact_id(), &"manager_cat", "双击联系人应打开对应会话")
		var messages_before := service.state.messages.size()
		suite.expect_true(view.submit_chat_text("你好，今晚忙吗？"), "会话应允许发送非空文本")
		suite.expect_equal(service.state.messages.size(), messages_before + 2, "UI 发送后应立即显示玩家消息和秒回")
		suite.expect_true(not view.submit_chat_text("  "), "UI 不得发送空白文本")
	view.select_tab(WechatView.Tab.MOMENTS)
	suite.expect_true(view.visible_entry_count() >= service.state.moments.size(), "朋友圈页应展示现有卡片和分隔线")
	suite.expect_equal(service.state.cursor, cursor_before, "切换页签不得重新随机生成内容")
	phone.back()
	suite.expect_equal(phone.current_page(), &"home", "微信首页返回应回到应用网格")
	phone.queue_free()
	await tree.process_frame
