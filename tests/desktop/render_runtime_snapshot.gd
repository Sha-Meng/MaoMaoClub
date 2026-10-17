extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 30
	root.unfocusable = true
	var main: Node = preload("res://app/main.tscn").instantiate()
	main.save_path = "user://maomao_horizontal_render_test.cfg"
	main.session_port = 44332
	root.add_child(main)
	root.position = Vector2i(-10000, -10000)
	var loop: TavernLoopController = main.get_node("TavernLoop") as TavernLoopController
	loop.simulation.advance(28.0)
	var worst_ms: float = 0.0
	var total_ms: float = 0.0
	for frame: int in range(90):
		await process_frame
		if frame >= 30:
			var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			total_ms += ms
			worst_ms = maxf(worst_ms, ms)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png("res://production/qa/full_character_walk/runtime_scene.png")
	var errors: Array[String] = loop.simulation.validate_invariants()
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "invariants": errors,
		"frames": 90, "average_process_ms": total_ms / 60.0, "worst_process_ms": worst_ms,
		"borderless": root.borderless, "transparent": root.transparent and root.transparent_bg,
		"native_topmost": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
		"transparent_corner": image.get_pixel(0, 0).a == 0.0, "seen_actions": loop.simulation.seen_actions.keys()}
	var output: FileAccess = FileAccess.open("res://production/qa/full_character_walk/runtime_render.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	var passed: bool = errors.is_empty() and root.borderless and root.transparent and bool(report["native_topmost"]) and bool(report["transparent_corner"])
	main.free()
	quit(0 if passed else 1)
