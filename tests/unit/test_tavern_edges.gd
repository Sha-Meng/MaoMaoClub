extends RefCounted


func run(test: SceneTree) -> void:
	var methods: Array[Callable] = [_test_malformed_data, _test_dirty_chair_checkpoint, _test_drag_checkpoint, _test_no_seats, _test_reset_and_delete, _test_table_mount, _test_personalities, _test_natural_social_end, _test_invalid_time, _test_random_edits, _test_files_and_backup, _test_session_guard, _test_staff_social_preemption, _test_idle_work, _test_determinism]
	for method: Callable in methods:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)


func _advance_until(model: TavernSimulation, predicate: Callable, seconds: float = 150.0) -> bool:
	for tick: int in range(int(seconds * 10.0)):
		if predicate.call():
			return true
		model.advance(0.1)
	return bool(predicate.call())


func _single() -> TavernSimulation:
	var model: TavernSimulation = TavernSimulation.new(411)
	model.auto_spawn = false
	return model


func _test_malformed_data(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	for bad: Variant in [null, [], "broken", NAN, INF, -100.0, {}]:
		model.restore({"coins": bad, "business_xp": bad, "served_customers_total": bad,
			"tavern": {"clock": bad, "next_order": bad, "next_guest": bad, "rng_state": bad, "settled": [bad],
			"layout": {"next_id": bad, "objects": {"manager": {"kind": "chair", "position": Vector2(NAN, INF)}, "chair_bad": {"kind": "chair", "position": bad}}},
			"people": [{"id": "guest_1", "profile": "customer_dog", "position": bad, "state_time": bad, "visit_time": bad, "order": bad, "drink_time": bad, "facing": bad}],
			"orders": [{"id": bad, "elapsed": bad, "coins": bad}]}})
		test.check(model.validate_invariants().is_empty(), "损坏字段安全恢复: " + str(bad))
		model.advance(1.0)
	model.restore({"tavern": "wrong type"})
	test.check(model.people.size() == 3, "错误检查点类型安全回到默认布局")


func _test_dirty_chair_checkpoint(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	var person: TavernPerson = model.spawn_guest()
	_advance_until(model, func() -> bool: return person.state == "leaving")
	var server: TavernPerson = model.people["server"] as TavernPerson
	model.begin_drag("server")
	model.advance(10.0)
	var copy: Dictionary = model.to_snapshot()
	var resumed: TavernSimulation = _single()
	resumed.restore(copy)
	resumed.advance(45.0)
	test.check(resumed.orders.is_empty(), "带空杯检查点恢复后订单可被彻底回收")
	for seat: String in resumed.layout.chair_ids():
		test.check(not bool(resumed.layout.objects[seat]["dirty"]), "恢复后座位清洁: " + seat)
	test.check(not (resumed.people["server"] as TavernPerson).dragging, "恢复不遗留店员拖动锁")
	test.check(server.dragging, "原模型保持隔离")


func _test_drag_checkpoint(test: SceneTree) -> void:
	for phase: String in ["mixing", "pouring", "ready", "pickup", "delivering", "serving", "drinking", "paid"]:
		var model: TavernSimulation = _single()
		var person: TavernPerson = model.spawn_guest()
		_advance_until(model, func() -> bool: return person.order_id > 0 and model.orders.has(person.order_id) and (model.orders[person.order_id] as TavernOrder).phase == phase)
		model.begin_drag(person.id)
		model.drag_to(Vector2(600.0, 220.0))
		var resumed: TavernSimulation = _single()
		resumed.restore(model.to_snapshot())
		test.check(resumed.dragged_object.is_empty(), "保存于拖动时不会恢复拖动锁: " + phase)
		test.check(_advance_until(resumed, func() -> bool: return resumed.served_total == 1 and resumed.guest_count() == 0), "拖动检查点消费恢复: " + phase)
		test.check(resumed.validate_invariants().is_empty(), "拖动检查点引用正确: " + phase)


func _test_no_seats(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	for seat: String in model.layout.chair_ids():
		model.remove_furniture(seat)
	for index: int in range(4):
		model.spawn_guest(CastCatalog.CUSTOMER_IDS[index])
	model.advance(20.0)
	test.check(model.orders.is_empty() and model.served_total == 0, "无座位时等待而不凭空消费")
	test.check(model.spawn_guest() == null, "满员时不继续生成")
	model.layout.add_furniture("chair")
	test.check(_advance_until(model, func() -> bool: return model.served_total > 0, 180.0), "新增座椅后等待中的顾客继续营业")


func _test_reset_and_delete(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	var person: TavernPerson = model.spawn_guest()
	_advance_until(model, func() -> bool: return person.state == "paying")
	model.remove_furniture(person.seat_id)
	test.check(_advance_until(model, func() -> bool: return model.guest_count() == 0), "付款期间删除椅子不会重新消费")
	test.check(model.served_total == 1, "删除付款椅子仍只计一次")
	model.reset_layout()
	test.check(model.orders.is_empty() and model.validate_invariants().is_empty(), "恢复布局清理孤立已完成订单")


func _test_table_mount(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	var person: TavernPerson = model.spawn_guest()
	_advance_until(model, func() -> bool: return person.state == "drinking")
	var before: Vector2 = model.layout.cup_position(person.seat_id)
	for id: String in ["table_0", "table_1"]:
		model.begin_drag(id)
		model.drag_to(Vector2(450.0, 200.0))
		model.end_drag()
	var after: Vector2 = model.layout.cup_position(person.seat_id)
	test.check(before != after, "桌子移动后杯子挂点重新计算")
	test.check(_advance_until(model, func() -> bool: return model.served_total == 1), "移动桌子不丢失饮品和收益")


func _test_personalities(test: SceneTree) -> void:
	for profile_id: String in CastCatalog.CUSTOMER_IDS:
		var model: TavernSimulation = _single()
		model.spawn_guest(profile_id)
		(model.people["manager"] as TavernPerson).cooldown = 500.0
		model.advance(60.0)
		test.check(model.seen_actions.has(str(CastCatalog.profile(profile_id)["gesture"])), "顾客实际演出性格动作: " + profile_id)
	for id: String in CastCatalog.STAFF_IDS:
		var model: TavernSimulation = _single()
		model.advance(30.0)
		test.check(model.seen_actions.has(str(CastCatalog.profile(id)["gesture"])), "员工实际演出性格动作: " + id)
	var model: TavernSimulation = _single()
	model.click_person("manager")
	model.advance(0.1)
	test.check((model.people["manager"] as TavernPerson).action == "react_click", "点击店长反馈保持可见")


func _test_natural_social_end(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	var person: TavernPerson = model.spawn_guest("customer_squirrel")
	_advance_until(model, func() -> bool: return person.state == "drinking")
	model.end_conversation()
	var manager: TavernPerson = model.people["manager"] as TavernPerson
	manager.position = person.position + Vector2(55.0, 0.0)
	manager.cooldown = 0.0
	manager.state = "idle"
	person.cooldown = 0.0
	person.drink_time = 3.0
	model.clock += 45.0
	test.check(model.try_start_chat("manager", person.id), "可以自然开始一次闲聊")
	model.advance(5.5)
	test.check(model.conversation.is_empty() and model.chats_completed > 0, "闲聊按时自然结束")
	test.check(manager.chat_partner.is_empty() and person.chat_partner.is_empty(), "自然结束解除双方占用")


func _test_invalid_time(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	for value: float in [-1.0, 0.0, INF, NAN]:
		model.advance(value)
	test.check(model.clock == 0.0, "非法时间步不会推进或破坏状态")


func _test_random_edits(test: SceneTree) -> void:
	var model: TavernSimulation = TavernSimulation.new(81)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 610
	var rewards: Dictionary = {}
	model.reward_earned.connect(func(order_id: int, amount: int, _xp: int, _point: Vector2) -> void:
		test.check(not rewards.has(order_id), "随机编辑中同单不重复发奖")
		rewards[order_id] = amount)
	for tick: int in range(12000):
		if tick % 31 == 0:
			var ids: Array = model.people.keys() + model.layout.objects.keys()
			var id: String = str(ids[random.randi_range(0, ids.size() - 1)])
			if model.begin_drag(id):
				model.drag_to(Vector2(random.randf_range(60.0, 900.0), random.randf_range(160.0, 270.0)))
				model.advance(0.4)
				model.end_drag()
		if tick % 313 == 0:
			var chairs: Array[String] = model.layout.chair_ids()
			if chairs.size() > 2:
				model.remove_furniture(chairs[0])
			model.layout.add_furniture("chair")
		if tick % 919 == 0:
			model.reset_layout()
		if tick % 503 == 0:
			model.restore(model.to_snapshot())
		model.advance(0.1)
		if tick % 50 == 0:
			var errors: Array[String] = model.validate_invariants()
			test.check(errors.is_empty(), "随机编辑后不变量: %d %s" % [tick, str(errors)])
	var total: int = 0
	for amount: int in rewards.values():
		total += amount
	test.check(total == model.coins and rewards.size() == model.served_total, "随机编辑经济等于唯一订单奖励之和")
	test.check(model.served_total > 10 and model.orders.size() < 16, "持续随机编辑时营业仍能前进且对象有界")


func _test_files_and_backup(test: SceneTree) -> void:
	var directory: String = "user://maomao_test_saves"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var save: SaveService = SaveService.new()
	save.save_path = directory + "/atomic.cfg"
	var model: TavernSimulation = _single()
	model.coins = 43
	test.check(save.save_game(model.to_snapshot()) == OK, "首次原子保存成功")
	model.coins = 57
	test.check(save.save_game(model.to_snapshot()) == OK, "再次保存保留上一份备份")
	var damaged: ConfigFile = ConfigFile.new()
	damaged.set_value("meta", "save_version", 2)
	damaged.save(save.save_path)
	var loaded: Dictionary = save.load_game()
	test.check(save.recovered_from_backup and int(loaded["coins"]) == 43, "主档结构损坏时恢复最后有效备份")
	model.coins = 61
	test.check(save.save_game(model.to_snapshot()) == OK, "损坏主档后可安全重新保存")
	test.check(int(save.load_game()["coins"]) == 61, "重新保存后读取新档")
	var old: ConfigFile = ConfigFile.new()
	for key: String in ["coins", "business_xp", "served_customers_total"]:
		old.set_value("economy", key, 25)
	old.set_value("meta", "save_version", 1)
	old.save(directory + "/legacy.cfg")
	save.save_path = directory + "/legacy.cfg"
	loaded = save.load_game()
	test.check(int(loaded["coins"]) == 25 and int(loaded["save_version"]) == 1, "真实旧版 cfg 能迁移读取")
	var failures: Array[String] = []
	save.save_failed.connect(func(message: String) -> void: failures.append(message))
	save.save_path = directory + "/does_not_exist/never.cfg"
	test.check(save.save_game(model.to_snapshot()) != OK and not failures.is_empty(), "保存失败返回错误且通知用户")
	save.free()


func _test_session_guard(test: SceneTree) -> void:
	var first: SessionGuard = SessionGuard.new()
	var second: SessionGuard = SessionGuard.new()
	test.check(first.acquire(44330), "首个实例可获取运行锁")
	test.check(not second.acquire(44330), "第二实例不能并发写入同一存档")
	first.release()
	test.check(second.acquire(44330), "实例退出后锁可重获")
	second.release()


func _test_staff_social_preemption(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	var manager: TavernPerson = model.people["manager"] as TavernPerson
	manager.position = Vector2(455.0, 270.0)
	test.check(model.try_start_chat("manager", "bartender"), "空闲店员可与店长简短闲聊")
	model.advance(0.1)
	var person: TavernPerson = model.spawn_guest()
	person.position = model.layout.objects[person.seat_id]["position"] as Vector2
	model.advance(1.0)
	test.check((model.people["bartender"] as TavernPerson).order_id > 0, "有订单时调酒优先于闲聊")
	test.check((model.people["bartender"] as TavernPerson).chat_partner.is_empty(), "工作抢占清理店员社交锁")
	test.check(_advance_until(model, func() -> bool: return model.served_total == 1), "店员闲聊不会阻断营业")


func _test_idle_work(test: SceneTree) -> void:
	var model: TavernSimulation = _single()
	for index: int in range(6):
		model.advance(60.0)
	for action: String in ["wipe_table", "wipe_glass", "wipe_counter", "pickup_bottle", "align_glass", "apron"]:
		test.check(model.seen_actions.has(action), "空闲岗位行为实际可达: " + action)
	model.spawn_guest()
	test.check(_advance_until(model, func() -> bool: return model.served_total == 1), "清洁与整理可被营业任务抢占")


func _test_determinism(test: SceneTree) -> void:
	var first: TavernSimulation = TavernSimulation.new(566)
	var second: TavernSimulation = TavernSimulation.new(566)
	for index: int in range(1800):
		first.advance(0.1)
		second.advance(0.1)
	test.check(first.to_snapshot() == second.to_snapshot(), "固定种子和时间步产生相同营业结果")
	for action: String in first.seen_actions:
		test.check(action in TavernArt.SUPPORTED_ACTIONS, "实际行为均有动画映射: " + action)
