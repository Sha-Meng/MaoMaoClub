extends RefCounted


func run(test: SceneTree) -> void:
	for method: Callable in [_test_whole_body_contact, _test_held_frame_mirroring, _test_seating_anchor]:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)


func _area(points: PackedVector2Array) -> float:
	var value: float = 0.0
	for index: int in range(points.size()):
		value += points[index].cross(points[(index + 1) % points.size()])
	return absf(value) * 0.5


func _test_whole_body_contact(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	for key: String in TavernWalkArt.SHEETS:
		for index: int in range(10):
			var pose: Dictionary = art.frames[key][index]
			var points: PackedVector2Array = pose["points"] as PackedVector2Array
			test.check(_area(points) > 500.0, "走路使用完整身体轮廓，非独立肢体: %s/%d" % [key,index])
			test.check(int(pose["sheet_components"]) == 10, "源图十个完整连通人物，无大块悬浮肢体: %s/%d" % [key,index])

func _test_held_frame_mirroring(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	for key: String in ["manager", "server_carry"]:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = "manager" if key == "manager" else "server"
		person.carrying = key == "server_carry"
		person.walking = true
		person.action = "carry_tray" if person.carrying else "walk"
		for index: int in range(8):
			person.walk_phase = (index + 0.5) / 8.0
			test.check(art.supports(person) and art.key_for(person) == key, "持杯/盘由完整人物帧包含: %s/%d" % [key,index])
			var right: Rect2 = art.bounds_for(person)
			person.facing = -1.0
			var left: Rect2 = art.bounds_for(person)
			test.check(left.size == right.size and is_equal_approx(left.position.x,-right.end.x), "持物随整个人物同步镜像: %s/%d" % [key,index])
			person.facing = 1.0

func _test_seating_anchor(test: SceneTree) -> void:
	var art: TavernArt = TavernArt.new()
	for id: String in CastCatalog.CUSTOMER_IDS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.position = Vector2(300.0, TavernLayout.GROUND)
		person.state = "seating"
		person.action = "sit_down"
		var foot_y: float = -INF
		for frame: int in range(12):
			person.state_time = float(frame) * 0.05
			var bottom: float = -INF
			for point: Vector2 in art.body_polygon(person):
				bottom = maxf(bottom, point.y)
			foot_y = bottom if frame == 0 else foot_y
			test.check(is_equal_approx(bottom, foot_y), "入座不整身下滑，脚底高度固定: %s/%d" % [id, frame])
			test.check(art.posture_point(person, Vector2(0.0, -27.0)) == Vector2(0.0, -27.0), "座面接触点固定: %s/%d" % [id, frame])
		var settled: PackedVector2Array = art.body_polygon(person)
		person.action = "idle_sit"
		person.state = "waiting"
		test.check(settled == art.body_polygon(person), "坐下收稳后切待机无姿势跳变: " + id)
		person.action = "stand_up"
		for frame: int in range(11):
			person.state_time = float(frame) * 0.05
			test.check(art.posture_point(person, Vector2(0.0, 0.0)) == Vector2.ZERO, "起身不通过整身上浮模拟: " + id)
