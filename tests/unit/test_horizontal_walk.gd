extends RefCounted


func run(test: SceneTree) -> void:
	for method: Callable in [_test_stride, _test_walk_sequence, _test_walk_sheets, _test_horizontal_drag, _test_bartender_lock, _test_empty_chair, _test_reserved_chair, _test_old_layout]:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)


func _model() -> TavernSimulation:
	var model: TavernSimulation = TavernSimulation.new(137)
	model.auto_spawn = false
	return model


func _test_stride(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var a: TavernPerson = TavernPerson.new()
		a.profile_id = id
		a.position = Vector2(200.0, TavernLayout.GROUND)
		var b: TavernPerson = TavernPerson.new()
		b.profile_id = id
		b.position = a.position
		var distance: float = a.stride_length() * 0.25
		var duration: float = distance / a.walk_speed()
		a.walk_to(a.position + Vector2(distance, -100.0), duration)
		for index: int in range(10):
			b.walk_to(Vector2(200.0 + distance, 50.0), duration / 10.0)
		test.check(is_equal_approx(a.walk_phase, 0.25) and is_equal_approx(a.walk_phase, b.walk_phase), "按实际距离推进步态，帧长无关: " + id)
		test.check(a.position.y == TavernLayout.GROUND and b.position.y == TavernLayout.GROUND, "自动行走不改变 Y: " + id)
		var phase: float = a.walk_phase
		a.animation_time += 100.0
		a.walk_to(a.position, 5.0)
		test.check(a.walk_phase == phase and not a.walking, "停步不踏步: " + id)
		a.walk_to(a.position - Vector2(distance, 0.0), duration)
		test.check(a.facing == -1.0 and a.walking, "反向行走保持前进步态: " + id)


func _test_walk_sequence(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.action = "walk"
		person.walking = true
		for index: int in range(8):
			person.walk_phase = (index + 0.5) / 8.0
			test.check(art.frame_for(person) == TavernWalkArt.IDLE_FRAME, "实际位移驱动连续单图步态: %s/%d" % [id, index])
			person.facing = -1.0
			test.check(art.frame_for(person) == TavernWalkArt.IDLE_FRAME, "反向走路保持同一人物来源: %s/%d" % [id, index])
		person.walking = false
		test.check(art.frame_for(person) == TavernWalkArt.IDLE_FRAME, "停步不继续踏步: " + id)
	var server: TavernPerson = TavernPerson.new()
	server.profile_id = "server"
	server.carrying = true
	server.walking = true
	server.action = "carry_tray"
	test.check(art.key_for(server) == "server_carry", "端盘使用手盘同帧专用步行")
	server.dragging = true
	test.check(art.frame_for(server) == TavernWalkArt.IDLE_FRAME, "拖动暂停脚步但保留手盘接触")

func _test_horizontal_drag(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var guest: TavernPerson = model.spawn_guest()
	var ids: Array = model.layout.objects.keys() + ["manager", "server", guest.id]
	for id: String in ids:
		test.check(model.begin_drag(id), "对象可横向摆放: " + id)
		for y: float in [-1000.0, 50.0, 230.0, 5000.0]:
			model.drag_to(Vector2(350.0, y))
			var point: Vector2 = (model.people[id] as TavernPerson).position if model.people.has(id) else model.layout.objects[id]["position"] as Vector2
			test.check(point == Vector2(350.0, TavernLayout.GROUND), "拖动过程忽略 Y: " + id)
		model.end_drag()
	test.check(model.validate_invariants().is_empty(), "所有对象摆放后保持基线及占用约束")


func _test_walk_sheets(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	for key: String in TavernWalkArt.SHEETS:
		test.check((art.frames[key] as Array).size() == 10, "完整人物八走路加待机招呼: " + key)
		var image: Image = (TavernWalkArt.SHEETS[key] as Texture2D).get_image()
		test.check(image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, "完整人物透明背景: " + key)
		for pose: Dictionary in art.frames[key]:
			test.check((pose["points"] as PackedVector2Array).size() >= 20 and (pose["bounds"] as Rect2).size.y > 40.0, "每帧完整身体: " + key)

func _test_bartender_lock(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var bartender: TavernPerson = model.people["bartender"] as TavernPerson
	for index: int in range(3):
		test.check(not model.can_drag("bartender") and not model.begin_drag("bartender"), "调酒员拖动被拒绝且无锁")
		model.drag_to(Vector2(80.0, 100.0))
		model.end_drag()
		test.check(model.dragged_object.is_empty() and not bartender.dragging and bartender.position == model.layout.shop_position(), "拒绝拖动不离岗")
	model.begin_drag("shop")
	model.drag_to(Vector2(700.0, 180.0))
	model.end_drag()
	test.check(bartender.position == Vector2(700.0, TavernLayout.GROUND) and bartender.home == bartender.position, "调酒员随店铺移动")


func _test_empty_chair(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	for id: String in model.layout.chair_ids():
		if id != "chair_0":
			model.remove_furniture(id)
	model.begin_drag("chair_0")
	var guest: TavernPerson = model.spawn_guest()
	var initial: Vector2 = guest.position
	for index: int in range(20):
		model.drag_to(Vector2(200.0 + index * 10.0, 100.0))
		model.advance(0.1)
		test.check(guest.seat_id.is_empty() and guest.position == initial and str(model.layout.objects["chair_0"]["occupant"]).is_empty(), "拖动中空座不接受新预占，不出现人 %d" % index)
	model.end_drag()
	model.advance(0.1)
	test.check(guest.seat_id == "chair_0" and guest.position.distance_to(initial) <= 7.0, "释放后正常步行找座，不瞬移")
	var remaining_distance: float = guest.position.distance_to(model.layout.objects["chair_0"]["position"] as Vector2)
	var arrival_steps: int = ceili((remaining_distance / guest.walk_speed() + 1.0) / 0.1)
	for index: int in range(arrival_steps):
		model.advance(0.1)
	test.check(guest.state not in ["entering", "reseating"] and guest.position.distance_to(model.layout.objects["chair_0"]["position"] as Vector2) < 0.5, "走近后正常坐下")


func _test_reserved_chair(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var guest: TavernPerson = model.spawn_guest()
	var chair: String = guest.seat_id
	var initial: Vector2 = guest.position
	test.check(guest.state == "entering" and not chair.is_empty(), "复现视觉空椅已被远处顾客预占")
	model.begin_drag(chair)
	model.drag_to(Vector2(450.0, 100.0))
	test.check(guest.seat_id.is_empty() and guest.position == initial, "拖动已预占但未入座的椅子不带走顾客")
	model.advance(0.1)
	test.check(guest.seat_id != chair and guest.position.distance_to(initial) < 7.0, "顾客改选其他座位并正常走动")
	model.end_drag()
	test.check(model.validate_invariants().is_empty(), "改选座位后引用正确")


func _test_old_layout(test: SceneTree) -> void:
	var model: TavernSimulation = _model()
	var data: Dictionary = model.to_snapshot()
	data["tavern"]["layout"]["objects"]["shop"]["position"] = Vector2(600.0, 180.0)
	data["tavern"]["layout"]["homes"]["bartender"] = Vector2(80.0, 140.0)
	for item: Dictionary in data["tavern"]["layout"]["objects"].values():
		item["position"] = (item["position"] as Vector2) - Vector2(0.0, 30.0)
	for person: Dictionary in data["tavern"]["people"]:
		person["position"] = Vector2(90.0, 130.0)
		person["home"] = Vector2(90.0, 160.0)
	model.restore(data)
	test.check(model.validate_invariants().is_empty(), "旧二维存档归一到基线")
	test.check((model.people["bartender"] as TavernPerson).position == Vector2(600.0, TavernLayout.GROUND), "已被拖离岗位的旧档调酒员回到店内")
	model.advance(30.0)
	test.check(model.validate_invariants().is_empty(), "恢复后自主移动仍遵守单基线")
