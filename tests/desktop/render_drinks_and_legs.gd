extends SceneTree

const FOLDER: String = "res://production/qa/full_character_walk/drinks_regression"

class DrinkGallery:
	extends TavernWorldView
	func _draw() -> void:
		for row: int in range(6):
			for column: int in range(6):
				var person: TavernPerson = TavernPerson.new()
				person.id = "drink_%d_%d" % [row, column]
				person.profile_id = CastCatalog.CUSTOMER_IDS[row]
				person.action = "drink"
				person.state = "drinking"
				person.action_time = (column + 0.5) * TavernDrinkArt.DURATION / 6.0
				person.facing = 1.0 if row % 2 == 0 else -1.0
				person.position = Vector2(90.0 + column * 180.0, 115.0 + row * 140.0)
				_draw_person(person)
				draw_line(person.position + Vector2(-65.0, 1.0), person.position + Vector2(65.0, 1.0), Color("8c846f"), 0.5)
				draw_string(font, person.position + Vector2(-65.0, 15.0), str(CastCatalog.profile(person.profile_id)["name"]) + " %d" % column, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d7bd8e"))

class ManagerGallery:
	extends TavernWorldView
	func _draw() -> void:
		for row: int in range(4):
			for column: int in range(8):
				var person: TavernPerson = TavernPerson.new()
				person.id = "manager_%d_%d" % [row, column]
				person.profile_id = "manager"
				person.action = "walk" if row < 2 else ("idle" if row == 2 else "toast")
				person.walking = row < 2
				person.walk_phase = float(column) / 8.0
				person.facing = -1.0 if row == 1 else 1.0
				person.position = Vector2(65.0 + column * 130.0, 110.0 + row * 125.0)
				_draw_person(person)
				draw_line(person.position + Vector2(-55.0, 1.0), person.position + Vector2(55.0, 1.0), Color("8c846f"), 0.5)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.transparent_bg = true
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(2160, 1680)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var drinks: DrinkGallery = DrinkGallery.new()
	drinks.simulation = TavernSimulation.new(731)
	viewport.add_child(drinks)
	drinks.set_process(false)
	await process_frame
	viewport.canvas_transform = Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2.ZERO)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.save_png(FOLDER + "/drinking_sequence.png")
	var errors: Array[String] = []
	for row: int in range(6):
		for column: int in range(6):
			var rect: Rect2i = image.get_region(Rect2i(column * 360, row * 280, 360, 224)).get_used_rect()
			if rect.size.y < 75 or rect.size.x < 45:
				errors.append("饮用姿势为空: %d/%d" % [row, column])
	drinks.queue_free()
	await process_frame
	viewport.size = Vector2i(2080, 1000)
	var manager: ManagerGallery = ManagerGallery.new()
	manager.simulation = TavernSimulation.new(732)
	viewport.add_child(manager)
	manager.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FOLDER + "/manager_held_cup.png")
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "drink_frames": 36, "manager_frames": 32, "transparent": image.get_pixel(0, 0).a == 0.0, "errors": errors}
	var output: FileAccess = FileAccess.open(FOLDER + "/render_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
