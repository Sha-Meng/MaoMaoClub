extends SceneTree

const FOLDER: String = "res://production/qa/articulated_walk"
const STEP: float = 1.0 / 30.0
const FRAME_COUNT: int = 132

class Background:
	extends Node2D
	var title: String
	var font: SystemFont = SystemFont.new()
	func _draw() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei UI"])
		draw_rect(Rect2(0, 0, 360, 300), Color("f5f1e9"))
		draw_rect(Rect2(360, 0, 600, 300), Color("252d37"))
		draw_line(Vector2(0, 265), Vector2(960, 265), Color("9b917f"), 1.0)
		draw_string(font, Vector2(18, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("463c33"))
		draw_string(font, Vector2(380, 28), "真实速度 · 30 FPS · 2 倍检查", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("eadbc3"))
		draw_string(font, Vector2(18, 288), "原尺寸：走动 → 停步 → 反向", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("463c33"))

class Actor:
	extends TavernWorldView
	var person: TavernPerson
	func _draw() -> void:
		if person != null:
			_draw_person(person)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(FOLDER + "/frames")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(960, 300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: Background = Background.new()
	viewport.add_child(background)
	var native: Actor = Actor.new()
	native.simulation = TavernSimulation.new(123)
	viewport.add_child(native)
	native.set_process(false)
	native.position.y = -6.0
	var zoomed: Actor = Actor.new()
	zoomed.simulation = native.simulation
	viewport.add_child(zoomed)
	zoomed.set_process(false)
	zoomed.scale = Vector2.ONE * 2.0
	zoomed.position = Vector2(380, -276)
	var report: Dictionary = {"fps": 30, "frames_per_variant": FRAME_COUNT, "variants": {}, "success": true}
	for key: String in TavernWalkArt.SHEETS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = "server" if key == "server_carry" else key
		person.id = key
		person.carrying = key == "server_carry"
		person.position = Vector2(80, TavernLayout.GROUND)
		native.person = person
		zoomed.person = person
		background.title = str(CastCatalog.profile(person.profile_id).name) + (" · 持盘" if person.carrying else "")
		background.queue_redraw()
		for frame: int in range(FRAME_COUNT):
			if frame < 60:
				person.walk_to(Vector2(900, TavernLayout.GROUND), STEP)
			elif frame < 72:
				person.walk_to(person.position, STEP)
			else:
				person.walk_to(Vector2(0, TavernLayout.GROUND), STEP)
			person.animation_time += STEP
			person.action_time += STEP
			person.settle_gait(STEP)
			native.queue_redraw()
			zoomed.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(FOLDER + "/frames/%s_%03d.png" % [key, frame])
		report.variants[key] = {"cycles_per_second": person.walk_speed() / person.stride_length(), "native_and_2x": true, "light_and_dark": true, "returned_x": person.position.x}
	var output: FileAccess = FileAccess.open(FOLDER + "/realtime_render.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
