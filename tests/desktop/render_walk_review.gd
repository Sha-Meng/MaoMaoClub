extends SceneTree

const FOLDER: String = "res://production/qa/full_character_walk/review"

class Background:
	extends Node2D
	var light: bool = true
	var title: String = ""
	var font: SystemFont = SystemFont.new()
	func _draw() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei UI"])
		var ink: Color = Color("463c33") if light else Color("eadbc3")
		draw_rect(Rect2(0, 0, 640, 300), Color("f5f1e9") if light else Color("252d37"))
		draw_line(Vector2(15, 265), Vector2(625, 265), Color("9b917f"), 1.0)
		draw_string(font, Vector2(20, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		draw_string(font, Vector2(20, 290), "常驻原尺寸", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		draw_string(font, Vector2(290, 290), "2 倍检查 · 反向", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

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
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: Background = Background.new()
	viewport.add_child(background)
	var native: Actor = Actor.new()
	native.simulation = TavernSimulation.new(123)
	viewport.add_child(native)
	native.set_process(false)
	var zoomed: Actor = Actor.new()
	zoomed.scale = Vector2(2.0, 2.0)
	zoomed.position = Vector2(230.0, 5.0)
	zoomed.simulation = native.simulation
	viewport.add_child(zoomed)
	zoomed.set_process(false)
	for key: String in TavernWalkArt.SHEETS:
		for dark: int in range(2):
			var person: TavernPerson = TavernPerson.new()
			person.profile_id = "server" if key == "server_carry" else key
			person.id = key
			person.action = "carry_tray" if key == "server_carry" else "walk"
			person.carrying = key == "server_carry"
			person.walking = true
			person.gait_lift = 1.0
			person.walk_cycles = 2.0
			person.position = Vector2(105.0, 264.0)
			native.person = person
			var mirror: TavernPerson = TavernPerson.new()
			mirror.profile_id = person.profile_id
			mirror.id = "mirror_" + key
			mirror.action = person.action
			mirror.carrying = person.carrying
			mirror.walking = true
			mirror.gait_lift = 1.0
			mirror.walk_cycles = 2.0
			mirror.facing = -1.0
			mirror.position = Vector2(110.0, 129.5)
			zoomed.person = mirror
			background.light = dark == 0
			background.title = str(CastCatalog.profile(person.profile_id)["name"]) + (" · 持盘" if person.carrying else "")
			background.queue_redraw()
			for frame: int in range(10):
				person.walk_phase = (frame + 0.5) / 8.0
				person.walking = frame < 8
				person.action = ("carry_tray" if person.carrying else "walk") if frame < 8 else ("idle" if frame == 8 else "greet")
				mirror.walk_phase = person.walk_phase
				mirror.walking = person.walking
				mirror.action = person.action
				native.queue_redraw()
				zoomed.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(FOLDER + "/%s_%s_%02d.png" % [key, "dark" if dark else "light", frame])
	print(JSON.stringify({"variants": 10, "review_frames": 200, "native_and_mirrored_2x": true, "light_and_dark": true}))
	quit()
