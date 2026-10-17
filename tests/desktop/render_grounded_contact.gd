extends SceneTree

const FOLDER: String = "res://production/qa/grounded_walk"

class Actor:
	extends Node2D
	var art: TavernWalkArt = TavernWalkArt.new()
	var person: TavernPerson
	var camera_offset: Vector2 = Vector2.ZERO
	func _draw() -> void:
		draw_set_transform(Vector2(300.0 + person.position.x * 4.0, 448.0)+camera_offset, 0.0, Vector2(4.0 * person.facing, 4.0))
		art.draw_on(self, person)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 480)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor: Actor = Actor.new()
	viewport.add_child(actor)
	var errors: Array[String] = []
	var report: Dictionary = {"variants": {}, "samples": 0}
	for key: String in TavernWalkArt.SHEETS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = "server" if key == "server_carry" else key
		person.carrying = key == "server_carry"
		person.action = "walk"
		person.walking = true
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		actor.person = person
		actor.camera_offset = Vector2.ZERO
		var worst_drift: float = 0.0
		var drift_details: Dictionary = {}
		for direction: float in [-1.0, 1.0]:
			person.facing = direction
			for side: int in range(2):
				var first: float = 0.0
				for step: int in range(8):
					var progress: float = step * 0.2 / 7.0
					person.walk_phase = fposmod(0.9 + side * 0.5 + progress, 1.0)
					person.position.x = direction * person.stride_length() * progress
					actor.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var rendered: Image = viewport.get_texture().get_image()
					# During the middle 60% of stance the other foot is clear of this
					# bottom raster strip. Measure actual alpha, not calculated markers.
					var mass: float = 0.0
					var sum_x: float = 0.0
					# Sample the actual contact line (last 1/4 logical pixel), not a
					# 3-row band that can include the other foot's raised toe/heel.
					for y: int in range(447, 448):
						for x: int in range(120, 500):
							var alpha: float = rendered.get_pixel(x, y).a
							mass += alpha
							sum_x += x * alpha
					if mass < 2.0:
						errors.append("脚底像素缺失: %s/%s/%d/%d" % [key,direction,side,step])
					else:
						var center: float = sum_x / mass
						if step == 0:
							first = center
						var drift: float = absf(center-first) / 4.0
						if drift > worst_drift:
							worst_drift = drift
							drift_details = {"side":side,"direction":direction,"step":step,"first_x":first,"x":center}
					report.samples += 1
					if direction == 1.0 and side == 0 and step in [0, 4, 7]:
						rendered.save_png(FOLDER + "/contact_%s_%d.png" % [key,step])
					if direction == 1.0 and side == 1 and step in [0, 4, 7]:
						rendered.save_png(FOLDER + "/far_contact_%s_%d.png" % [key,step])
		if worst_drift > 0.3:
			errors.append("支撑脚实际像素漂移超过 0.3 逻辑像素: %s %.3f" % [key,worst_drift])
		person.position.x = 0.0
		person.facing = 1.0
		var height: float = float(CastCatalog.profile(person.profile_id).height)
		var head_end: float = -height * 0.625
		for arm: Rect2 in TavernGroundedGait.ARMS[person.profile_id]:
			if arm.has_area():
				# Exclude the animated shoulder and its 2px mesh interpolation band.
				head_end = minf(head_end, arm.position.y - 3.0)
		var head_top: int = floori(448.0-height*4.0)
		var head_rect: Rect2i = Rect2i(80, head_top, 440, floori(448.0+head_end*4.0)-head_top)
		var first_head: PackedByteArray = PackedByteArray()
		var head_changes: int = 0
		for phase: int in range(32):
			person.walk_phase = float(phase)/32.0
			person.action = "idle_stand" if phase % 2 else "walk"
			# Register the deliberate weight shift; the head must retain its pixels,
			# not remain frozen in world space as the previous stiff walk required.
			actor.camera_offset = -(TavernWalkPose.evaluate(person).body as Vector2)*4.0
			actor.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var head: PackedByteArray = viewport.get_texture().get_image().get_region(head_rect).get_data()
			if phase == 0:
				first_head = head
			else:
				for byte: int in range(head.size()):
					if absi(int(head[byte])-int(first_head[byte]))>1:
						head_changes += 1
						break
			report.samples += 1
		if head_changes != 0:
			errors.append("站走/完整循环头部像素改变: %s/%d" % [key,head_changes])
		report.variants[key] = {"maximum_raster_foot_drift": worst_drift, "head_region_changes": head_changes,"drift_details":drift_details}
	report.errors = errors
	report.success = errors.is_empty()
	var output: FileAccess = FileAccess.open(FOLDER + "/pixel_contact.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
