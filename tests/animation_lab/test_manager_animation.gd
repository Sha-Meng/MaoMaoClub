extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var actor: ManagerAnimationPlayer = ManagerAnimationPlayer.new()
	check(actor.data["clips"].size() == 8, "空手和持杯各有站立、起步、行走、停步")
	actor.advance(2.7)
	check(actor.clip == "idle" and actor.position_x == 0.0, "站立循环不移动")
	actor.request_motion(1, false)
	check(actor.clip == "start", "移动先进入起步")
	actor.advance(float(actor.current_clip()["duration"]))
	check(actor.clip == "walk" and is_equal_approx(actor.position_x, 7.4), "起步完成衔接步行并累计源动画位移")
	var start_x: float = actor.position_x
	actor.advance(2.0)
	check(is_equal_approx(actor.position_x - start_x, 44.0), "两个前后交替周期实际移动 44 逻辑像素")
	actor.request_motion(0, true)
	check(not actor.held, "行走中换杯先等待停步，避免手臂瞬间换姿")
	actor.advance(2.0)
	check(actor.clip == "idle" and actor.held, "完成停步后进入持杯站立")
	var settled: float = actor.position_x
	actor.advance(4.0)
	check(is_equal_approx(actor.position_x, settled), "停步后不会继续滑移")
	actor.request_motion(-1, true)
	actor.advance(1.8)
	check(actor.facing == -1 and actor.position_x < settled, "向左用镜像与负位移，动作帧仍正序")
	var unchanged: float = actor.position_x
	actor.advance(0.0)
	actor.advance(-1.0)
	actor.advance(INF)
	check(actor.position_x == unchanged, "无效时间步不会移动角色")
	_test_timestep_consistency()
	_test_authored_contacts(actor.data)
	_test_interrupted_start()
	await _test_controls()
	var texture: Texture2D = load(str(actor.data["atlas"])) as Texture2D
	for held: bool in [false, true]:
		actor.held = held
		for clip: String in ["idle", "start", "walk", "stop"]:
			actor.clip = clip
			var entry: Dictionary = actor.current_clip()
			for frame: int in range(int(entry["count"])):
				actor.elapsed = float(frame) / (int(entry["count"]) if bool(entry["loop"]) else int(entry["count"]) - 1) * float(entry["duration"])
				var rect: Rect2 = actor.source_rect()
				check(Rect2(Vector2.ZERO, texture.get_size()).encloses(rect), "图集区域合法 %s/%d" % [actor.clip_key(), frame])
	var report: Dictionary = {"engine": Engine.get_version_info(), "assertions": assertions, "failures": failures, "success": failures.is_empty()}
	var output: FileAccess = FileAccess.open("res://production/qa/manager_blender/unit_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _test_interrupted_start() -> void:
	var actor: ManagerAnimationPlayer = ManagerAnimationPlayer.new()
	actor.request_motion(1, false)
	actor.advance(0.1)
	actor.request_motion(0, false)
	actor.advance(1.5)
	check(actor.clip == "idle", "起步中取消移动直接衔接停步，不强制再走完整周期")
	check(is_equal_approx(actor.position_x, 17.0), "取消起步只包含起步和停步的必要位移")


func _test_controls() -> void:
	var lab: Node2D = load("res://features/animation_lab/manager_lab.tscn").instantiate() as Node2D
	lab.set("capture_mode", true)
	root.add_child(lab)
	await process_frame
	var buttons: Dictionary = {}
	for row: Node in lab.get_children():
		for child: Node in row.get_children():
			if child is Button:
				buttons[(child as Button).text] = child
	check(buttons.size() == 8, "预览界面八项控件均已连接")
	(buttons["向左"] as Button).pressed.emit()
	var actor: ManagerAnimationPlayer = lab.get("player") as ManagerAnimationPlayer
	check(not bool(lab.get("automatic")) and actor.requested_direction == -1, "向左控件进入手动模式")
	(buttons["暂停 / 继续"] as Button).pressed.emit()
	lab.call("advance_demo", 0.5)
	check(actor.position_x == 0.0, "暂停控件冻结位移与动画")
	(buttons["暂停 / 继续"] as Button).pressed.emit()
	lab.call("advance_demo", 0.5)
	check(actor.position_x < 0.0, "继续控件恢复动作")
	(buttons["停步"] as Button).pressed.emit()
	lab.call("advance_demo", 2.0)
	check(actor.clip == "idle", "停步控件最终进入站立")
	(buttons["空手 / 持杯"] as Button).pressed.emit()
	check(actor.held, "持杯控件在站立时正确换装")
	(buttons["0.5× / 1×"] as Button).pressed.emit()
	check(is_equal_approx(float(lab.get("playback_speed")), 0.5), "半速控件正确")
	(buttons["浅底 / 深底"] as Button).pressed.emit()
	check(bool(lab.get("dark")), "深底控件正确")
	(buttons["自动演示"] as Button).pressed.emit()
	check(bool(lab.get("automatic")), "自动演示可恢复")
	lab.queue_free()
	await process_frame


func _test_timestep_consistency() -> void:
	var reference: ManagerAnimationPlayer = ManagerAnimationPlayer.new()
	reference.request_motion(1, false)
	reference.advance(3.0)
	reference.request_motion(-1, true)
	reference.advance(4.0)
	for fps: int in [15, 30, 60, 144]:
		var actor: ManagerAnimationPlayer = ManagerAnimationPlayer.new()
		actor.request_motion(1, false)
		for _i: int in range(fps * 3):
			actor.advance(1.0 / fps)
		actor.request_motion(-1, true)
		for _i: int in range(fps * 4):
			actor.advance(1.0 / fps)
		check(absf(actor.position_x - reference.position_x) < 0.0001, "不同帧率位移一致 %d FPS" % fps)
		check(actor.clip_key() == reference.clip_key() and actor.facing == reference.facing, "不同帧率动作衔接一致 %d FPS" % fps)


func _test_authored_contacts(data: Dictionary) -> void:
	for key: String in data["clips"]:
		var clip: Dictionary = data["clips"][key]
		var frames: Array = clip["frames"]
		for frame: Dictionary in frames:
			check(bool(frame["feet"][0][3]) or bool(frame["feet"][1][3]), "行走始终至少一脚支撑 %s" % key)
		if key.begins_with("walk"):
			var cross_count: int = 0
			var near_ahead: bool = false
			var far_ahead: bool = false
			for index: int in frames.size():
				var a: float = float(frames[index]["feet"][0][0]) - float(frames[index]["feet"][1][0])
				var next: int = (index + 1) % frames.size()
				var b: float = float(frames[next]["feet"][0][0]) - float(frames[next]["feet"][1][0])
				near_ahead = near_ahead or a > 2.0
				far_ahead = far_ahead or a < -2.0
				if a * b < 0.0:
					cross_count += 1
			check(near_ahead and far_ahead and cross_count == 2, "正常步行每周期两次经过，双腿前后交替 %s" % key)
		for index: int in range(1, frames.size()):
			for foot: int in range(2):
				var previous: Dictionary = frames[index - 1]
				var current: Dictionary = frames[index]
				if bool(previous["feet"][foot][3]) and bool(current["feet"][foot][3]):
					var a: float = float(previous["root_x"]) + float(previous["feet"][foot][0])
					var b: float = float(current["root_x"]) + float(current["feet"][foot][0])
					check(absf(a - b) < 0.00001, "制作数据中的支撑脚锁地 %s/%d/%d" % [key, index, foot])
	for suffix: String in ["", "_cup"]:
		for pair: Array in [["start", "walk"], ["stop", "idle"]]:
			var from: Array = data["clips"][str(pair[0]) + suffix]["frames"]
			var to: Array = data["clips"][str(pair[1]) + suffix]["frames"]
			for foot: int in range(2):
				for axis: int in range(3):
					check(absf(float(from[-1]["feet"][foot][axis]) - float(to[0]["feet"][foot][axis])) < 0.00001, "起停衔接脚姿连续 %s→%s" % pair)
