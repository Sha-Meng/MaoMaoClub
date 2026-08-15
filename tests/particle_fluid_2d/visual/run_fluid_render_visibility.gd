extends SceneTree

const LAB_SCENE_PATH: String = "res://features/particle_fluid_2d/demo/particle_fluid_test_lab.tscn"
const TEST_WINDOW_SIZE: Vector2i = Vector2i(1200, 700)
const LIQUID_REGION: Rect2i = Rect2i(670, 392, 180, 116)
const CONTINUITY_REGION: Rect2i = Rect2i(680, 420, 160, 72)
const SPARSE_INTERIOR_REGION: Rect2i = Rect2i(680, 382, 160, 112)
const COLLOID_UPPER_REGION: Rect2i = Rect2i(670, 390, 180, 62)
const CLEAR_LOWER_REGION: Rect2i = Rect2i(670, 452, 180, 56)
const MIN_OPTICAL_MEAN_DIFFERENCE: float = 0.014
const MIN_DIRECT_MEAN_DIFFERENCE: float = 0.020
const MIN_VISIBLE_PIXEL_RATIO: float = 0.20
const MIN_CONTINUOUS_PIXEL_RATIO: float = 0.95
const MAX_BRIDGEABLE_GAP_RATIO: float = 0.01
const GAP_SEARCH_RADIUS_PIXELS: int = 12
const PERFORMANCE_WARMUP_FRAMES: int = 30
const PERFORMANCE_SAMPLE_FRAMES: int = 180
const MIN_AVERAGE_FPS: float = 45.0
const MAX_P95_FRAME_MILLISECONDS: float = 22.22

var _output_directory: String = "user://fluid_render_visibility"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_arguments()
	DisplayServer.window_set_size(TEST_WINDOW_SIZE)
	var packed_scene := load(LAB_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Render visibility: failed to load lab scene")
		quit(1)
		return
	var lab := packed_scene.instantiate() as Node2D
	root.add_child(lab)
	await _wait_physics_frames(18)
	var fluid := lab.find_child("ParticleFluid", true, false)
	if fluid == null:
		push_error("Render visibility: ParticleFluid node was not found")
		quit(1)
		return
	var performance := await _sample_frame_performance()
	fluid.simulate = false
	var field_viewport := lab.find_child("OpticalFieldViewport", true, false) as SubViewport
	if field_viewport != null:
		var field_image := field_viewport.get_texture().get_image()
		var field_statistics := _measure_field(field_image)
		print("OPTICAL_FIELD max_rgb=%.5f max_alpha=%.5f nonzero_ratio=%.3f" % [
			field_statistics.x,
			field_statistics.y,
			field_statistics.z,
		])
	await _wait_process_frames(3)
	var optical_image := _capture_frame()
	fluid.set_rendering_enabled(false)
	await _wait_process_frames(3)
	var optical_baseline := _capture_frame()
	var optical_metrics := _measure_difference(optical_image, optical_baseline, LIQUID_REGION)
	var continuity_metrics := _measure_difference(
		optical_image,
		optical_baseline,
		CONTINUITY_REGION
	)
	var bridgeable_gap_ratio := _measure_bridgeable_gap_ratio(
		optical_image,
		optical_baseline,
		SPARSE_INTERIOR_REGION,
		GAP_SEARCH_RADIUS_PIXELS
	)
	_save_image(optical_image, "optical.png")
	_save_image(optical_baseline, "optical_hidden.png")

	fluid.set_rendering_enabled(true)
	fluid.call("set_render_mode", 1)
	fluid.simulate = true
	await _wait_physics_frames(2)
	fluid.simulate = false
	await _wait_process_frames(3)
	var direct_image := _capture_frame()
	fluid.set_rendering_enabled(false)
	await _wait_process_frames(3)
	var direct_baseline := _capture_frame()
	var direct_metrics := _measure_difference(direct_image, direct_baseline, LIQUID_REGION)
	_save_image(direct_image, "direct.png")
	_save_image(direct_baseline, "direct_hidden.png")

	fluid.set_rendering_enabled(true)
	fluid.call("set_render_mode", 0)
	lab.call("_load_scenario", 3)
	await _wait_physics_frames(12)
	fluid.simulate = false
	await _wait_process_frames(3)
	var colloid_image := _capture_frame()
	fluid.set_rendering_enabled(false)
	await _wait_process_frames(3)
	var colloid_baseline := _capture_frame()
	var clear_metrics := _measure_difference(
		colloid_image,
		colloid_baseline,
		CLEAR_LOWER_REGION
	)
	var colloid_metrics := _measure_difference(
		colloid_image,
		colloid_baseline,
		COLLOID_UPPER_REGION
	)
	_save_image(colloid_image, "colloid.png")
	_save_image(colloid_baseline, "colloid_hidden.png")
	var clear_color := _measure_average_color(colloid_image, CLEAR_LOWER_REGION)
	var colloid_color := _measure_average_color(colloid_image, COLLOID_UPPER_REGION)
	var clear_rgb := Vector3(clear_color.r, clear_color.g, clear_color.b)
	var colloid_rgb := Vector3(colloid_color.r, colloid_color.g, colloid_color.b)
	var colloid_color_distance := clear_rgb.distance_to(colloid_rgb)

	print("COLLOID_VISIBILITY clear_mean=%.5f clear_visible=%.3f colloid_mean=%.5f colloid_visible=%.3f" % [
		clear_metrics.x,
		clear_metrics.y,
		colloid_metrics.x,
		colloid_metrics.y,
	])
	print("COLLOID_COLOR_DISTANCE %.5f" % colloid_color_distance)
	print("RENDER_VISIBILITY optical_mean=%.5f optical_visible=%.3f direct_mean=%.5f direct_visible=%.3f" % [
		optical_metrics.x,
		optical_metrics.y,
		direct_metrics.x,
		direct_metrics.y,
	])
	print("SURFACE_CONTINUITY mean=%.5f covered=%.3f" % [
		continuity_metrics.x,
		continuity_metrics.y,
	])
	print("SPARSE_INTERIOR bridgeable_gap_ratio=%.4f" % bridgeable_gap_ratio)
	print("RENDER_PERFORMANCE average_fps=%.2f p95_ms=%.3f" % [
		performance.x,
		performance.y,
	])

	var failed := false
	if optical_metrics.x < MIN_OPTICAL_MEAN_DIFFERENCE or optical_metrics.y < MIN_VISIBLE_PIXEL_RATIO:
		push_error("Render visibility: optical field is not visibly distinct from the dark background")
		failed = true
	if direct_metrics.x < MIN_DIRECT_MEAN_DIFFERENCE or direct_metrics.y < MIN_VISIBLE_PIXEL_RATIO:
		push_error("Render visibility: direct particles are not visibly distinct from the dark background")
		failed = true
	if continuity_metrics.y < MIN_CONTINUOUS_PIXEL_RATIO:
		push_error("Render visibility: optical surface contains visible interior gaps")
		failed = true
	if bridgeable_gap_ratio > MAX_BRIDGEABLE_GAP_RATIO:
		push_error("Render visibility: sparse liquid interior still contains background holes")
		failed = true
	if performance.x < MIN_AVERAGE_FPS or performance.y > MAX_P95_FRAME_MILLISECONDS:
		push_error("Render visibility: optical surface did not sustain the 45 FPS gate")
		failed = true
	if clear_metrics.x < 0.01 or clear_metrics.y < 0.15:
		push_error("Render visibility: clear liquid color is not visible")
		failed = true
	if colloid_metrics.x < 0.01 or colloid_metrics.y < 0.15 or colloid_color_distance < 0.04:
		push_error("Render visibility: colloid color must remain visible and distinct from clear liquid")
		failed = true
	lab.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output_directory = argument.trim_prefix("--output=")

func _wait_physics_frames(frame_count: int) -> void:
	for _index: int in range(frame_count):
		await physics_frame

func _wait_process_frames(frame_count: int) -> void:
	for _index: int in range(frame_count):
		await process_frame

func _sample_frame_performance() -> Vector2:
	await _wait_process_frames(PERFORMANCE_WARMUP_FRAMES)
	var frame_milliseconds := PackedFloat32Array()
	var previous_ticks := Time.get_ticks_usec()
	for _index: int in range(PERFORMANCE_SAMPLE_FRAMES):
		await process_frame
		var current_ticks := Time.get_ticks_usec()
		frame_milliseconds.append(float(current_ticks - previous_ticks) / 1000.0)
		previous_ticks = current_ticks
	frame_milliseconds.sort()
	var total_milliseconds := 0.0
	for duration: float in frame_milliseconds:
		total_milliseconds += duration
	var average_milliseconds := total_milliseconds / float(frame_milliseconds.size())
	var p95_index := clampi(
		ceili(float(frame_milliseconds.size()) * 0.95) - 1,
		0,
		frame_milliseconds.size() - 1
	)
	return Vector2(
		1000.0 / maxf(average_milliseconds, 0.001),
		frame_milliseconds[p95_index]
	)

func _capture_frame() -> Image:
	return root.get_viewport().get_texture().get_image()

func _measure_difference(visible: Image, hidden: Image, region: Rect2i) -> Vector2:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, visible.get_size()))
	var difference_sum := 0.0
	var visible_pixels := 0
	var sample_count := 0
	for y: int in range(clipped.position.y, clipped.end.y, 2):
		for x: int in range(clipped.position.x, clipped.end.x, 2):
			var before := hidden.get_pixel(x, y)
			var after := visible.get_pixel(x, y)
			var difference := (
				absf(after.r - before.r)
				+ absf(after.g - before.g)
				+ absf(after.b - before.b)
			) / 3.0
			difference_sum += difference
			if difference >= 0.025:
				visible_pixels += 1
			sample_count += 1
	if sample_count == 0:
		return Vector2.ZERO
	return Vector2(
		difference_sum / float(sample_count),
		float(visible_pixels) / float(sample_count)
	)

func _measure_average_color(image: Image, region: Rect2i) -> Color:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var color_sum := Vector3.ZERO
	var sample_count := 0
	for y: int in range(clipped.position.y, clipped.end.y, 2):
		for x: int in range(clipped.position.x, clipped.end.x, 2):
			var sample := image.get_pixel(x, y)
			color_sum += Vector3(sample.r, sample.g, sample.b)
			sample_count += 1
	if sample_count == 0:
		return Color.BLACK
	var average := color_sum / float(sample_count)
	return Color(average.x, average.y, average.z, 1.0)

func _measure_bridgeable_gap_ratio(
	visible: Image,
	hidden: Image,
	region: Rect2i,
	search_radius_pixels: int
) -> float:
	var image_bounds := Rect2i(Vector2i.ZERO, visible.get_size())
	var clipped := region.intersection(image_bounds)
	var bridgeable_gaps := 0
	var sample_count := 0
	for y: int in range(clipped.position.y, clipped.end.y, 2):
		for x: int in range(clipped.position.x, clipped.end.x, 2):
			var point := Vector2i(x, y)
			sample_count += 1
			if _pixel_difference(visible, hidden, point) >= 0.025:
				continue
			var horizontal := _is_visible_pair(
				visible, hidden, point, Vector2i(search_radius_pixels, 0), image_bounds
			)
			var vertical := _is_visible_pair(
				visible, hidden, point, Vector2i(0, search_radius_pixels), image_bounds
			)
			var diagonal_down := _is_visible_pair(
				visible, hidden, point,
				Vector2i(search_radius_pixels, search_radius_pixels), image_bounds
			)
			var diagonal_up := _is_visible_pair(
				visible, hidden, point,
				Vector2i(search_radius_pixels, -search_radius_pixels), image_bounds
			)
			if horizontal or vertical or diagonal_down or diagonal_up:
				bridgeable_gaps += 1
	if sample_count == 0:
		return 0.0
	return float(bridgeable_gaps) / float(sample_count)

func _is_visible_pair(
	visible: Image,
	hidden: Image,
	point: Vector2i,
	offset: Vector2i,
	image_bounds: Rect2i
) -> bool:
	var first := point - offset
	var second := point + offset
	if not image_bounds.has_point(first) or not image_bounds.has_point(second):
		return false
	return (
		_pixel_difference(visible, hidden, first) >= 0.025
		and _pixel_difference(visible, hidden, second) >= 0.025
	)

func _pixel_difference(visible: Image, hidden: Image, point: Vector2i) -> float:
	var before := hidden.get_pixelv(point)
	var after := visible.get_pixelv(point)
	return (
		absf(after.r - before.r)
		+ absf(after.g - before.g)
		+ absf(after.b - before.b)
	) / 3.0

func _save_image(image: Image, file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	var output_path := _output_directory.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_warning("Render visibility: could not save %s (%s)" % [
			output_path,
			error_string(error),
		])

func _measure_field(image: Image) -> Vector3:
	var maximum_rgb := 0.0
	var maximum_alpha := 0.0
	var nonzero_pixels := 0
	var sample_count := 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var sample := image.get_pixel(x, y)
			maximum_rgb = maxf(maximum_rgb, maxf(sample.r, maxf(sample.g, sample.b)))
			maximum_alpha = maxf(maximum_alpha, sample.a)
			if sample.a > 0.001:
				nonzero_pixels += 1
			sample_count += 1
	if sample_count == 0:
		return Vector3.ZERO
	return Vector3(
		maximum_rgb,
		maximum_alpha,
		float(nonzero_pixels) / float(sample_count)
	)
