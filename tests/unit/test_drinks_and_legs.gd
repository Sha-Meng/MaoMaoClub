extends RefCounted


func run(test: SceneTree) -> void:
	for method: Callable in [_test_held_cup, _test_walk_registration, _test_drinking_frames, _test_drinking_sequence]:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)


func _area(points: PackedVector2Array) -> float:
	var value: float = 0.0
	for index: int in range(points.size()):
		value += points[index].cross(points[(index + 1) % points.size()])
	return absf(value) * 0.5


func _test_held_cup(test: SceneTree) -> void:
	var art: TavernArt = TavernArt.new()
	var person: TavernPerson = TavernPerson.new()
	person.profile_id = "manager"
	person.action = "walk"
	person.walking = true
	for frame: int in range(8):
		person.walk_phase = (frame + 0.5) / 8.0
		test.check(art.uses_walk_animation(person), "持杯走路使用完整人物: %d" % frame)
		test.check(art.walk_animation.frame_for(person) == 8, "持杯走路单图连续: %d" % frame)
	person.walking = false
	person.action = "idle"
	test.check(art.uses_walk_animation(person) and art.walk_animation.frame_for(person) == 8, "停止后仍为完整持杯待机")
	person.action = "toast"
	test.check(art.walk_animation.frame_for(person) == 8, "招呼保持完整手杯人物图")

func _test_walk_registration(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	for key: String in TavernWalkArt.SHEETS:
		var reference: Dictionary = art.frames[key][TavernWalkArt.IDLE_FRAME]
		var height: float = (reference["bounds"] as Rect2).size.y
		for index: int in range(10):
			var pose: Dictionary = art.frames[key][index]
			var bounds: Rect2 = pose["bounds"] as Rect2
			test.check(bounds.size.y > height * 0.85 and bounds.size.y < height * 1.15, "走路不改变人物体型: %s/%d" % [key,index])
			test.check(is_zero_approx(bounds.end.y), "完整人物支撑脚注册在地面: %s/%d" % [key,index])
			test.check(is_equal_approx(bounds.size.y, height) and is_equal_approx(bounds.size.x / bounds.size.y, (pose["source_bounds"] as Rect2).size.x / (pose["source_bounds"] as Rect2).size.y), "整人高度注册且保留每帧宽高比例: %s/%d" % [key,index])
			var source: Rect2 = pose["source_bounds"] as Rect2
			var image_bounds: Rect2 = pose["image_bounds"] as Rect2
			test.check(source.position.x >= 1.0 and source.end.x <= image_bounds.end.x - 1.0 and source.position.y >= 1.0 and source.end.y <= image_bounds.end.y - 1.0, "完整轮廓不被图像边缘裁断: %s/%d" % [key,index])

func _test_drinking_frames(test: SceneTree) -> void:
	var art: TavernArt = TavernArt.new()
	for id: String in CastCatalog.CUSTOMER_IDS:
		var poses: Array = art.drinks.frames[id]
		test.check(poses.size() == 6, "六个手杯一体饮用阶段: " + id)
		for index: int in range(poses.size()):
			var pose: Dictionary = poses[index]
			var bounds: Rect2 = pose["bounds"] as Rect2
			test.check(bounds.size.y > 40.0 and bounds.size.y < 130.0 and _area(pose["points"] as PackedVector2Array) > 500.0, "完整角色轮廓: %s/%d" % [id, index])
			test.check(is_zero_approx(bounds.end.y), "饮用脚底不下滑: %s/%d" % [id, index])
			test.check((pose["points"] as PackedVector2Array).size() == (pose["uvs"] as PackedVector2Array).size(), "轮廓贴图一致: %s/%d" % [id, index])
	for sheet: Texture2D in TavernDrinkArt.SHEETS:
		test.check(sheet.get_image().get_pixel(0, 0).a == 0.0, "饮用素材透明底")


func _test_drinking_sequence(test: SceneTree) -> void:
	var art: TavernArt = TavernArt.new()
	for id: String in CastCatalog.CUSTOMER_IDS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.action = "drink"
		for index: int in range(6):
			person.action_time = (index + 0.5) * TavernDrinkArt.DURATION / 6.0
			test.check(art.drinks.supports(person) and art.drinks.frame_for(person) == index, "按时间抬杯入口放下: %s/%d" % [id, index])
			var right: Rect2 = art.body_bounds(person)
			person.facing = -1.0
			var left: Rect2 = art.body_bounds(person)
			test.check(left.size == right.size and is_equal_approx(left.position.x, -right.end.x), "饮用朝向与点击轮廓同步: %s/%d" % [id, index])
			person.facing = 1.0
		person.action_time = 100.0
		test.check(art.drinks.frame_for(person) == 5, "越界时间固定最后帧: " + id)
		person.action = "idle_sit"
		test.check(not art.drinks.supports(person), "结束回到坐姿待机: " + id)
