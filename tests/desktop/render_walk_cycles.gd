extends SceneTree

class Gallery:
	extends TavernWorldView
	var phase_offset: float = 0.0
	var moving_preview: bool = false

	func _draw() -> void:
		var ids: Array[String] = CastCatalog.all_ids()
		ids.append("server")
		for row: int in range(ids.size()):
			for column: int in range(8 if not moving_preview else 1):
				var person: TavernPerson = TavernPerson.new()
				person.id = ids[row] + str(row) + str(column)
				person.profile_id = ids[row]
				person.action = "carry_tray" if row == 9 else "walk"
				person.walking = true
				person.gait_lift = 1.0
				person.walk_cycles = 2.0
				person.carrying = row == 9
				person.walk_phase = fposmod(float(column) / 8.0 + phase_offset, 1.0)
				person.position = Vector2(80.0 + 150.0 * column, 113.0 + 120.0 * row)
				if moving_preview:
					person.position = Vector2(120.0 + fmod(phase_offset * person.stride_length(), 220.0), 113.0 + 120.0 * row)
				_draw_person(person)
				draw_line(Vector2(6.0 + 150.0 * column, 114.0 + 120.0 * row), Vector2(148.0 + 150.0 * column, 114.0 + 120.0 * row), Color("776c57"), 0.5)
				draw_string(font, Vector2(8.0 + 150.0 * column, 124.0 + 120.0 * row), str(CastCatalog.profile(ids[row])["name"]) + (" 端盘" if row == 9 else "") + " %d" % column, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d7bd8e"))


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	root.transparent_bg = true
	root.unfocusable = true
	var folder: String = "res://production/qa/full_character_walk"
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1200, 1200)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery: Gallery = Gallery.new()
	gallery.simulation = TavernSimulation.new()
	viewport.add_child(gallery)
	gallery.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var errors: Array[String] = []
	for row: int in range(10):
		for column: int in range(8):
			var bounds: Rect2i = image.get_region(Rect2i(column * 150, row * 120, 150, 112)).get_used_rect()
			if bounds.size.y < 35 or bounds.size.x < 20:
				errors.append("空步态: %d,%d" % [row, column])
	image.save_png(folder + "/walk_cycle_gallery.png")
	# Eight landmarks per gait are inspected in the gallery; render real intermediate frames too.
	var started: int = Time.get_ticks_usec()
	gallery.moving_preview = true
	viewport.size = Vector2i(500, 1200)
	DirAccess.make_dir_recursive_absolute(folder + "/frames")
	for index: int in range(32):
		gallery.phase_offset = float(index) / 32.0
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder + "/frames/walk_%02d.png" % index)
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "gait_landmarks": 80, "intermediate_frames": 32, "errors": errors, "transparent": image.get_pixel(0, 0).a == 0.0, "render_and_save_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	var output: FileAccess = FileAccess.open(folder + "/walk_render.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
