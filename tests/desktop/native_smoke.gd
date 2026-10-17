extends SceneTree

var loop: TavernLoopController
var save: SaveService
var windows: DesktopWindowController
var observer: DesktopObserver


class DesktopObserver:
	extends Node
	var loop: TavernLoopController
	var events: Array[Dictionary] = []
	var elapsed: float = 0.0
	var last_signature: String = ""
	var last_panel: bool = false
	var normal_captured: bool = false
	var panel_captured: bool = false
	var arrangement_captured: bool = false
	var capture_pending: bool = false
	var last_metrics: Dictionary = {}


	func _process(delta: float) -> void:
		elapsed += delta
		var window: Window = get_window()
		var status: Dictionary = {"focused": window.has_focus(), "mode": window.mode, "always_on_top": window.always_on_top,
			"native_topmost": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), "position": [window.position.x, window.position.y], "size": [window.size.x, window.size.y], "panel": loop.hud.panel_open}
		var signature: String = JSON.stringify(status)
		if signature != last_signature:
			last_signature = signature
			status["at"] = elapsed
			events.append(status)
			if events.size() > 200:
				events.pop_front()
		if elapsed > 1.5 and not normal_captured and not capture_pending:
			normal_captured = true
			capture("runtime_scene.png")
		if loop.hud.panel_open and not panel_captured and not capture_pending:
			panel_captured = true
			capture("runtime_panel.png")
		if loop.world.edit_mode and not arrangement_captured and not capture_pending:
			arrangement_captured = true
			capture("runtime_arrangement.png")
		if Engine.get_process_frames() % 15 == 0:
			write_report()


	func capture(filename: String) -> void:
		capture_pending = true
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		if frame != null:
			frame.save_png("res://production/qa/personality_tavern/" + filename)
			last_metrics["transparent_corner"] = frame.get_pixel(0, 0).a == 0.0
		capture_pending = false


	func write_report() -> void:
		var window: Window = get_window()
		var positions: Dictionary = {}
		for id: String in loop.simulation.layout.objects:
			var point: Vector2 = loop.simulation.layout.objects[id]["position"] as Vector2
			positions[id] = [point.x, point.y]
		last_metrics.merge({"engine": Engine.get_version_info()["string"], "borderless": window.borderless,
			"transparent": window.transparent and window.transparent_bg, "topmost": window.always_on_top,
			"native_topmost": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
			"fps": Engine.get_frames_per_second(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS), "served": loop.simulation.served_total,
			"chats": loop.simulation.chats_completed, "invariants": loop.simulation.validate_invariants(), "events": events,
			"layout": positions, "seen_actions": loop.simulation.seen_actions.keys()}, true)
		var output: FileAccess = FileAccess.open("res://production/qa/personality_tavern/native_runtime.json", FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(last_metrics, "\t"))


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://production/qa/personality_tavern"))
	save = SaveService.new()
	save.save_path = "user://maomao_native_qa.cfg"
	root.add_child(save)
	windows = DesktopWindowController.new()
	root.add_child(windows)
	windows.apply_desktop_window(save.make_default_save())
	root.title = "猫猫 Club · 自动验收"
	loop = preload("res://features/tavern_loop/tavern_loop.tscn").instantiate() as TavernLoopController
	root.add_child(loop)
	loop.setup(save, windows, save.make_default_save())
	loop.simulation.advance(28.0)
	observer = DesktopObserver.new()
	observer.loop = loop
	root.add_child(observer)
	auto_accept_quit = false
	root.close_requested.connect(_close)
	loop.quit_requested.connect(_close)


func _close() -> void:
	loop.save_now()
	observer.write_report()
	quit()
