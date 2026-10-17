extends SceneTree

class Gallery:
	extends Node2D
	var art: TavernArt = TavernArt.new()
	var font: SystemFont = SystemFont.new()

	func _ready() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
		queue_redraw()

	func _draw() -> void:
		var ids: Array[String] = CastCatalog.all_ids()
		for row: int in range(ids.size()):
			for column: int in range(6):
				var person: TavernPerson = TavernPerson.new()
				person.id = ids[row]
				person.profile_id = ids[row]
				person.action = ["idle", "walk", "walk", "idle_sit", "drink", "chat"][column]
				person.animation_time = 0.01 if column == 1 else 0.24
				person.action_time = 0.5
				if row < 6:
					person.state = "waiting" if column > 2 else "entering"
				else:
					person.action = [["idle", "walk", "walk", "chat", "listen", "greet"], ["idle_work", "walk", "walk", "mix_drink", "pour_drink", "place_drink"], ["idle_work", "walk", "walk", "carry_tray", "carry_tray", "serve_drink"]][row - 6][column]
				var position: Vector2 = Vector2(90.0 + 170.0 * column, 112.0 + 120.0 * row)
				draw_set_transform(position)
				draw_polygon(art.body_polygon(person), PackedColorArray([Color.WHITE]), art.texture_uvs[person.profile_id][art.pose_for(person)] as PackedVector2Array, art.texture_for(person.profile_id))
				draw_set_transform(Vector2.ZERO)
				draw_string(font, Vector2(12.0 + 170.0 * column, 119.0 + 120.0 * row), str(CastCatalog.profile(ids[row])["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("a88b62"))


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	root.transparent_bg = true
	root.unfocusable = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1020, 1080)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Gallery.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var errors: Array[String] = []
	for row: int in range(9):
		for column: int in range(6):
			var bounds: Rect2i = image.get_region(Rect2i(column * 170, row * 120, 170, 112)).get_used_rect()
			if bounds.size.y < 35 or bounds.size.x < 20:
				errors.append("空姿势: %d,%d" % [row, column])
	image.save_png("res://production/qa/personality_tavern/rendered_poses.png")
	print(JSON.stringify({"rendered_poses": 54, "errors": errors, "transparent": image.get_pixel(0, 0).a == 0.0}))
	quit(0 if errors.is_empty() else 1)
