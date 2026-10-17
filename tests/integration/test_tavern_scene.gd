extends RefCounted


func run(test: SceneTree) -> void:
	var before: int = test.failures.size()
	var save: SaveService = SaveService.new()
	save.save_path = "user://tavern_test_isolated.cfg"
	test.root.add_child(save)
	var window_controller: DesktopWindowController = DesktopWindowController.new()
	test.root.add_child(window_controller)
	var scene: TavernLoopController = preload("res://features/tavern_loop/tavern_loop.tscn").instantiate() as TavernLoopController
	test.root.add_child(scene)
	scene.setup(save, window_controller, save.make_default_save())
	await test.process_frame
	scene.set_process(false)
	scene.world.set_process(false)
	test.check(scene.world != null and scene.hud != null, "完整场景有世界与 HUD")
	test.check(scene.world.art.frames.size() == 9, "九个人物均有运行时图集")
	for id: String in CastCatalog.all_ids():
		var regions: Array = scene.world.art.frames[id]
		test.check(regions.size() == 6, "每位人物六种基础姿势: " + id)
		for region: Rect2 in regions:
			test.check(region.size.x > 0.0 and region.size.y > 0.0, "姿势不是空图: " + id)
	var balance: int = scene.simulation.coins
	scene.simulation.advance(130.0)
	test.check(scene.simulation.coins > balance, "场景接线后可自动营业")
	scene.hud.set_panel_open(true)
	test.check(scene.hud.panel_open, "小面板可展开")
	scene.hud.set_panel_open(false)
	var snapshot: Dictionary = scene.make_save_snapshot()
	test.check(save.save_game(snapshot) == OK, "检查点可写入隔离存档")
	var loaded: Dictionary = save.load_game()
	test.check(int(loaded["coins"]) == scene.simulation.coins and loaded.has("tavern"), "真实文件往返保留经济与布局")
	# Exercise actual panel signals, including the transitions that build their controls.
	var before_chairs: int = scene.simulation.layout.chair_ids().size()
	(scene.hud.find_child("Tab摆放", true, false) as Button).pressed.emit()
	(scene.hud.find_child("AddChair", true, false) as Button).pressed.emit()
	test.check(scene.simulation.layout.chair_ids().size() == before_chairs + 1, "添加座椅按钮接入模型")
	(scene.hud.find_child("RemoveSelected", true, false) as Button).pressed.emit()
	test.check(scene.simulation.layout.chair_ids().size() == before_chairs, "移除所选家具按钮接入模型")
	(scene.hud.find_child("AddTable", true, false) as Button).pressed.emit()
	test.check(scene.world.edit_mode, "添加家具后进入摆放状态")
	(scene.hud.find_child("ResetLayout", true, false) as Button).pressed.emit()
	test.check(scene.simulation.layout.objects.size() == 7, "重置按钮恢复默认布局")
	var picker: OptionButton = scene.hud.find_child("ScaleSelector", true, false) as OptionButton
	picker.item_selected.emit(0)
	test.check(is_equal_approx(scene.simulation.display_scale, 0.8), "缩放控件接入设置与保存")
	(scene.hud.find_child("Tab人物", true, false) as Button).pressed.emit()
	test.check(scene.hud.find_child("CharacterPicker", true, false) != null, "人物面板提供九位人物选择")
	var quit_calls: Array[int] = []
	scene.quit_requested.connect(func() -> void: quit_calls.append(1))
	(scene.hud.find_child("Quit", true, false) as Button).pressed.emit()
	test.check(quit_calls.size() == 1, "保存退出按钮正确转发")
	scene.hud.set_panel_open(false)
	scene.world.edit_mode = false
	scene.simulation = TavernSimulation.new(137)
	scene.world.simulation = scene.simulation
	scene.simulation.auto_spawn = false
	scene.simulation.reset_layout()
	var manager: TavernPerson = scene.simulation.people["manager"] as TavernPerson
	var initial: Vector2 = manager.position
	var click_point: Vector2 = scene.world.object_bounds("manager").get_center()
	var clicks: Array[String] = []
	scene.world.object_clicked.connect(func(id: String) -> void: clicks.append(id))
	_pointer(test, click_point, true)
	_motion(test, click_point + Vector2(2.0, 0.0))
	test.check(scene.simulation.dragged_object.is_empty(), "小于阈值的移动不是拖动")
	_pointer(test, click_point + Vector2(2.0, 0.0), false)
	test.check(clicks.has("manager"), "单击店长产生点击事件")
	var click_count: int = clicks.size()
	_pointer(test, click_point, true)
	_motion(test, click_point + Vector2(60.0, -20.0))
	test.check(scene.simulation.dragged_object == "manager", "超过阈值由真实视口输入启动拖动")
	_pointer(test, click_point + Vector2(60.0, -20.0), false)
	test.check(clicks.size() == click_count, "拖动释放不误触单击")
	test.check(manager.position.distance_to(initial) > 20.0 and not manager.dragging, "视口拖动完成并清理锁定")
	test.check(manager.position.y == TavernLayout.GROUND, "真实斜向拖动不会改变 Y")
	scene.hud.set_panel_open(false)
	# The bartender remains clickable, but a drag attempt must neither move him nor click.
	var bartender: TavernPerson = scene.simulation.people["bartender"] as TavernPerson
	var bartender_initial: Vector2 = bartender.position
	var bar_point: Vector2 = Vector2(bartender.position.x, TavernLayout.GROUND - 77.0)
	test.check(scene.world.hit_test(bar_point) == "bartender", "吧台可见上半身命中调酒员")
	click_count = clicks.size()
	_pointer(test, bar_point, true)
	_motion(test, bar_point + Vector2(-170.0, -40.0))
	_pointer(test, bar_point + Vector2(-170.0, -40.0), false)
	test.check(bartender.position == bartender_initial and not bartender.dragging and scene.simulation.dragged_object.is_empty(), "真实输入无法拖出调酒员")
	test.check(clicks.size() == click_count, "调酒员拒绝拖动后不误触单击")
	_pointer(test, bar_point, true)
	_pointer(test, bar_point, false)
	test.check(clicks.size() == click_count + 1 and clicks.back() == "bartender", "调酒员仍可单击查看")
	scene.hud.set_panel_open(false)
	scene.world.edit_mode = true
	for id: String in scene.simulation.layout.chair_ids():
		if id != "chair_0":
			scene.simulation.remove_furniture(id)
	var empty_point: Vector2 = scene.world.object_bounds("chair_0").get_center()
	_pointer(test, empty_point, true)
	_motion(test, empty_point + Vector2(70.0, -70.0))
	var newcomer: TavernPerson = scene.simulation.spawn_guest()
	scene.simulation.advance(1.0)
	test.check(scene.simulation.dragged_object == "chair_0" and newcomer.seat_id.is_empty(), "真实拖动中的空椅子不会分配给新顾客")
	_pointer(test, empty_point + Vector2(70.0, -70.0), false)
	test.check(scene.simulation.dragged_object.is_empty() and (scene.simulation.layout.objects["chair_0"]["position"] as Vector2).y == TavernLayout.GROUND, "真实家具释放清理锁并保持基线")
	for texture: Texture2D in TavernArt.SHEETS:
		test.check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "运行图集保留透明 alpha")
	scene.free()
	window_controller.free()
	save.free()
	test.case_done("场景、资源、HUD、存档集成", before)
	before = test.failures.size()
	var main: Node = preload("res://app/main.tscn").instantiate()
	main.save_path = "user://maomao_main_entry_test.cfg"
	main.session_port = 44331
	test.root.add_child(main)
	await test.process_frame
	var actual_loop: TavernLoopController = main.get_node("TavernLoop") as TavernLoopController
	test.check(actual_loop != null and actual_loop.simulation.people.size() >= 3, "正式主入口加载完整酒馆")
	actual_loop.set_process(false)
	actual_loop.simulation.advance(60.0)
	test.check(main.save_before_quit() == OK, "正式主入口退出前保存成功")
	var service: SaveService = main.get_node("SaveService") as SaveService
	test.check(int(service.load_game()["coins"]) == actual_loop.simulation.coins, "主入口保存的是当前完整营业状态")
	service.save_path = "user://does_not_exist/maomao_never.cfg"
	test.check(main.save_before_quit() != OK and actual_loop.hud.panel_open, "保存失败保留窗口并展示错误，避免静默丢失")
	main.free()
	test.case_done("正式启动入口及退出保存", before)


func _pointer(test: SceneTree, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	test.root.push_input(event, true)


func _motion(test: SceneTree, point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	test.root.push_input(event, true)
