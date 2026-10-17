extends RefCounted


func run(test: SceneTree) -> void:
	var checks: Array[Callable] = [_test_catalog, _test_layout, _test_cycle, _test_reward_once, _test_drag_worker, _test_drag_customer, _test_move_occupied_chair, _test_move_shop, _test_remove_chair, _test_social, _test_checkpoint, _test_legacy_save, _test_soak]
	for method: Callable in checks:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)


func _model(seed_value: int = 19) -> TavernSimulation:
	var model: TavernSimulation = TavernSimulation.new(seed_value)
	model.auto_spawn = false
	return model


func _until(model: TavernSimulation, predicate: Callable, duration: float = 150.0) -> bool:
	for tick: int in range(int(duration * 10.0)):
		if predicate.call():
			return true
		model.advance(0.1)
	return bool(predicate.call())


func _test_catalog(test: SceneTree) -> void:
	test.check(CastCatalog.all_ids().size() == 9, "六位顾客和三位猫齐全")
	var traits: Array[String] = []
	var builds: Array[String] = []
	for id: String in CastCatalog.all_ids():
		var profile: Dictionary = CastCatalog.profile(id)
		test.check(not str(profile["trait"]).is_empty() and not str(profile["gesture"]).is_empty(), "人物有性格和特征动作: " + id)
		traits.append(str(profile["trait"]))
		builds.append(str(profile["body"]))
	test.check(traits.size() == 9 and builds.size() == 9, "角色个性资料齐全")
	test.check(float(CastCatalog.profile("customer_dog")["height"]) > float(CastCatalog.profile("customer_squirrel")["height"]), "领带狗比松鼠瘦高")


func _test_layout(test: SceneTree) -> void:
	var layout: TavernLayout = TavernLayout.new()
	test.check(layout.chair_ids().size() == 4, "默认四个座位")
	var chair: String = layout.nearest_free_chair(Vector2.ZERO)
	layout.objects[chair]["occupant"] = "occupied"
	test.check(layout.nearest_free_chair(Vector2.ZERO) != chair, "已占用座位不再次预占")
	var point: Vector2 = layout.place_position(Vector2(-200.0, 180.0))
	test.check(point.x >= 52.0 and point.y == TavernLayout.GROUND, "横向摆位夹边界并固定地面线")
	test.check(layout.place_position(Vector2(300.0, 265.0)).y == TavernLayout.GROUND, "任意拖动高度均回到同一基线")
	for index: int in range(30):
		layout.add_furniture("chair")
	test.check(layout.objects.size() <= TavernLayout.MAX_FURNITURE, "家具数量有上限")


func _test_cycle(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest("customer_dog")
	test.check(person != null and not person.seat_id.is_empty(), "顾客入店预占座位")
	var completed: bool = _until(model, func() -> bool: return model.served_total == 1 and not model.people.has(person.id))
	test.check(completed, "从到店到付款离开能完整完成")
	test.check(model.coins >= 5 and model.coins <= 12 and model.business_xp == 1, "一次消费奖励在既有范围内")
	_until(model, func() -> bool: return model.orders.is_empty())
	test.check(model.orders.is_empty(), "离店后空杯回收并清理完成订单")
	for chair_id: String in model.layout.chair_ids():
		test.check(not bool(model.layout.objects[chair_id]["dirty"]), "座位完成清理")
	for action: String in ["walk", "sit_down", "mix_drink", "pour_drink", "place_drink", "carry_tray", "serve_drink", "drink", "pay", "stand_up", "collect_glass"]:
		test.check(model.seen_actions.has(action), "完整流程包含动作: " + action)
	test.check(model.validate_invariants().is_empty(), "消费闭环无引用错误")


func _test_reward_once(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest()
	_until(model, func() -> bool: return person.order_id > 0)
	test.check(not model.settle_order(person.order_id), "送达前不可结算")
	_until(model, func() -> bool: return person.state == "drinking")
	var order_id: int = person.order_id
	test.check(model.settle_order(order_id), "已送达订单可结算")
	var balance: int = model.coins
	for index: int in range(10):
		test.check(not model.settle_order(order_id), "重复回调不结算")
	test.check(model.coins == balance and model.served_total == 1, "重放不改变经济")
	var resumed: TavernSimulation = _model()
	resumed.restore(model.to_snapshot())
	test.check(not resumed.settle_order(order_id), "重启后仍不可重复结算")


func _test_drag_worker(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var guest: TavernPerson = model.spawn_guest()
	_until(model, func() -> bool: return guest.order_id > 0 and (model.orders[guest.order_id] as TavernOrder).phase == "mixing")
	var order: TavernOrder = model.orders[guest.order_id] as TavernOrder
	test.check(not model.begin_drag("bartender"), "调酒员不可独立拖动")
	test.check(model.begin_drag("shop"), "可整体拖动调制中的店铺")
	var elapsed: float = order.elapsed
	model.advance(6.0)
	test.check(order.elapsed == elapsed and model.served_total == 0, "拖动期间不推进制作或发奖")
	model.drag_to(Vector2(410.0, 235.0))
	model.end_drag()
	test.check((model.layout.homes["bartender"] as Vector2).is_equal_approx(Vector2(410.0, TavernLayout.GROUND)), "调酒岗位随店铺横向移动")
	test.check(_until(model, func() -> bool: return model.served_total == 1), "店员放下后订单恢复完成")
	model = _model()
	guest = model.spawn_guest()
	_until(model, func() -> bool: return (model.people["server"] as TavernPerson).carrying)
	var server: TavernPerson = model.people["server"] as TavernPerson
	model.begin_drag("server")
	model.advance(4.0)
	test.check(server.carrying and model.served_total == 0, "端盘拖动保留饮品且不重复送达")
	model.drag_to(Vector2(200.0, 250.0))
	model.end_drag()
	test.check(_until(model, func() -> bool: return model.served_total == 1), "端盘拖动后可继续消费")


func _test_drag_customer(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest("customer_capybara")
	_until(model, func() -> bool: return person.state == "drinking")
	var order_id: int = person.order_id
	model.begin_drag(person.id)
	var consumed: float = person.drink_time
	model.drag_to(Vector2(340.0, 215.0))
	model.advance(8.0)
	test.check(person.drink_time == consumed and person.seat_id.is_empty(), "拖动顾客暂停饮用并释放座位")
	model.end_drag()
	test.check(person.position.y == TavernLayout.GROUND, "顾客拖动仅改变横向位置")
	test.check(_until(model, func() -> bool: return model.served_total == 1), "顾客重新入座后保留原订单完成")
	test.check(person.order_id == order_id, "重新找座不重复点单")
	test.check(model.validate_invariants().is_empty(), "顾客拖动后引用保持一致")


func _test_move_occupied_chair(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest()
	_until(model, func() -> bool: return person.state == "drinking")
	var chair_id: String = person.seat_id
	model.begin_drag(chair_id)
	model.drag_to(Vector2(360.0, 220.0))
	test.check(person.position.is_equal_approx(Vector2(360.0, TavernLayout.GROUND)), "拖动占用椅子时人物沿基线跟随")
	var consumed: float = person.drink_time
	model.advance(5.0)
	test.check(person.drink_time == consumed, "移动椅子期间饮用暂停")
	model.end_drag()
	test.check(_until(model, func() -> bool: return model.served_total == 1), "移动椅子后完整营业")


func _test_move_shop(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var old_bartender: Vector2 = (model.people["bartender"] as TavernPerson).position
	model.begin_drag("shop")
	model.drag_to(model.layout.shop_position() + Vector2(-80.0, -35.0))
	model.end_drag()
	test.check((model.people["bartender"] as TavernPerson).position.is_equal_approx(old_bartender + Vector2(-80.0, 0.0)), "店铺仅横向移动并带动吧台员工")
	model.spawn_guest()
	test.check(_until(model, func() -> bool: return model.served_total == 1), "取杯挂点随店铺改变后仍可送达")


func _test_remove_chair(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest()
	_until(model, func() -> bool: return person.state == "drinking")
	var chair_id: String = person.seat_id
	test.check(model.remove_furniture(chair_id), "占用椅子可以安全移除")
	test.check(person.seat_id.is_empty(), "移除椅子后清理人物引用")
	test.check(_until(model, func() -> bool: return model.served_total == 1), "删除椅子后可换座完成原单")
	test.check(not model.remove_furniture("shop"), "不会误删必需店铺")


func _test_social(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var person: TavernPerson = model.spawn_guest("customer_rabbit")
	_until(model, func() -> bool: return person.state == "waiting")
	var manager: TavernPerson = model.people["manager"] as TavernPerson
	manager.position = person.position + Vector2(60.0, 0.0)
	manager.state = "idle"
	manager.cooldown = 0.0
	person.cooldown = 0.0
	person.visit_time = 1.0
	test.check(not model.try_start_chat("manager", person.id), "害羞顾客可以暂不参与")
	test.check(model.chats_declined > 0 and person.chat_partner.is_empty(), "不参与不遗留社交锁")
	manager.cooldown = 0.0
	person.cooldown = 0.0
	person.visit_time = 20.0
	model.clock += 20.0
	test.check(model.try_start_chat("manager", person.id), "自在之后可以接受闲聊")
	model.advance(0.2)
	test.check(manager.action == "chat" and person.action == "listen", "双方分别说话和倾听")
	model.advance(1.3)
	test.check(manager.action == "listen" and person.action == "chat", "对话轮次交替")
	model.begin_drag(person.id)
	test.check(model.conversation.is_empty() and manager.chat_partner.is_empty(), "拖动中断对话并释放双方")
	model.end_drag()
	test.check(not model.try_start_chat("manager", person.id), "中断后不会立即重复追聊")


func _test_checkpoint(test: SceneTree) -> void:
	for phase: String in ["mixing", "pouring", "ready", "pickup", "delivering", "serving", "drinking", "paid"]:
		var model: TavernSimulation = _model()
		var guest: TavernPerson = model.spawn_guest()
		var found: bool = _until(model, func() -> bool: return guest.order_id > 0 and model.orders.has(guest.order_id) and (model.orders[guest.order_id] as TavernOrder).phase == phase)
		test.check(found, "可到达存档阶段: " + phase)
		var snapshot: Dictionary = model.to_snapshot()
		var resumed: TavernSimulation = _model(27)
		resumed.restore(snapshot)
		test.check(resumed.validate_invariants().is_empty(), "恢复阶段引用正确: " + phase)
		test.check(_until(resumed, func() -> bool: return resumed.served_total == 1 and resumed.guest_count() == 0), "恢复后消费完成且只结算一次: " + phase)
		resumed.advance(15.0)
		test.check(resumed.served_total == 1, "恢复后无重复奖励: " + phase)


func _test_legacy_save(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	model.restore({"coins": 123, "business_xp": 9, "served_customers_total": 8})
	test.check(model.coins == 123 and model.business_xp == 9 and model.served_total == 8, "旧版经济迁移保留")
	test.check(model.people.size() == 3 and model.layout.chair_ids().size() == 4, "旧档补齐新场景")


func _test_soak(test: SceneTree) -> void:
	var model: TavernSimulation = TavernSimulation.new(941)
	var visitor_profiles: Dictionary = {}
	for tick: int in range(18000):
		model.advance(0.1)
		for person: TavernPerson in model.people.values():
			visitor_profiles[person.profile_id] = true
		if tick % 100 == 0:
			test.check(model.validate_invariants().is_empty(), "长时模拟引用正确 %d" % tick)
		if tick % 613 == 0:
			var copy: Dictionary = model.to_snapshot()
			model.restore(copy)
	test.check(model.served_total > 40, "三十分钟营业持续有收益")
	test.check(model.chats_completed > 0, "长时营业有自然闲聊")
	test.check(visitor_profiles.size() == 9, "六位顾客与三猫都进入运行")
	test.check(model.orders.size() <= 12 and model.people.size() <= 7, "营业对象数量有界")
