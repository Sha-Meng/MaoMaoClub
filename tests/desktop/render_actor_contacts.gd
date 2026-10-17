extends SceneTree

const FOLDER: String = "res://production/qa/full_character_walk"
const CELL: Vector2i = Vector2i(400, 260)

class JointGallery:
	extends Node2D
	var art: TavernWalkArt = TavernWalkArt.new()

	func _draw() -> void:
		var ids: Array[String] = CastCatalog.all_ids()
		ids.append("server")
		for row: int in range(ids.size()):
			for column: int in range(16):
				var person: TavernPerson = TavernPerson.new()
				person.profile_id = ids[row]
				person.walking = true
				person.gait_lift = 1.0
				person.walk_cycles = 2.0
				person.action = "walk"
				person.walk_phase = float(column % 8) / 8.0
				person.carrying = row == 9
				var facing: float = -1.0 if column % 2 else 1.0
				draw_set_transform(Vector2(column * CELL.x + CELL.x * 0.5, row * CELL.y + CELL.y - 10.0), 0.0, Vector2(2.0 * facing, 2.0))
				art.draw_on(self, person)
			draw_set_transform(Vector2.ZERO)

class SeatGallery:
	extends TavernWorldView
	var show_chairs: bool = false

	func _draw() -> void:
		for row: int in range(6):
			for column: int in range(6):
				var person: TavernPerson = TavernPerson.new()
				person.id = "seat_%d_%d" % [row, column]
				person.profile_id = CastCatalog.CUSTOMER_IDS[row]
				person.action = "sit_down"
				person.state = "seating"
				person.state_time = 0.11 * column
				# Render at native size first, then use a viewport-level scale for inspection.
				person.position = Vector2(85.0 + 170.0 * column, 115.0 + 130.0 * row)
				if show_chairs:
					_draw_chair(person.position)
				_draw_person(person)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.transparent_bg = true
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var errors: Array[String] = []
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(CELL.x * 16, CELL.y * 10)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var joints: JointGallery = JointGallery.new()
	viewport.add_child(joints)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var largest_second_component: float = 0.0
	for row: int in range(10):
		for column: int in range(16):
			var sample: Image = image.get_region(Rect2i(Vector2i(column, row) * CELL, CELL))
			var bitmap: BitMap = BitMap.new()
			bitmap.create_from_image_alpha(sample, 0.18)
			var large_components: int = 0
			var areas: Array[float] = []
			for polygon: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, CELL), 1.0):
				var area: float = _area(polygon)
				areas.append(area)
				if area >= 64.0:
					large_components += 1
			areas.sort()
			if areas.size() >= 2:
				largest_second_component = maxf(largest_second_component, areas[-2])
			if large_components != 1:
				errors.append("完整人物 alpha 不连通: %d,%d (%d)" % [row, column, large_components])
	image.save_png(FOLDER + "/body_alpha_atlas.png")
	for group: int in range(3):
		image.get_region(Rect2i(0, group * 3 * CELL.y, CELL.x * 8, CELL.y * 3)).save_png(FOLDER + "/shoulders_%d.png" % group)
	joints.free()
	viewport.size = Vector2i(1020, 780)
	var seats: SeatGallery = SeatGallery.new()
	seats.simulation = TavernSimulation.new()
	viewport.add_child(seats)
	seats.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var seated_image: Image = viewport.get_texture().get_image()
	var foot_spreads: Array[int] = []
	for row: int in range(6):
		var min_y: int = 10000
		var max_y: int = -10000
		for column: int in range(6):
			var used: Rect2i = seated_image.get_region(Rect2i(column * 170, row * 130, 170, 125)).get_used_rect()
			min_y = mini(min_y, used.end.y)
			max_y = maxi(max_y, used.end.y)
		foot_spreads.append(max_y - min_y)
		if max_y - min_y > 1:
			errors.append("坐下整身下降或上浮: %d (%dpx)" % [row, max_y - min_y])
	seated_image.save_png(FOLDER + "/seating_sequence.png")
	seats.show_chairs = true
	seats.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FOLDER + "/seating_with_chairs.png")
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "whole_body_samples": 160, "seating_samples": 36, "foot_spread_pixels": foot_spreads, "largest_extra_alpha_component": largest_second_component, "errors": errors, "success": errors.is_empty()}
	var output: FileAccess = FileAccess.open(FOLDER + "/contact_render.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func _area(points: PackedVector2Array) -> float:
	var value: float = 0.0
	for index: int in range(points.size()):
		value += points[index].cross(points[(index + 1) % points.size()])
	return absf(value) * 0.5
