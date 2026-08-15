extends SceneTree

const SHAKER_SCENE := preload("res://features/cocktail_shaker_lab/cocktail_shaker_lab.tscn")
const TEST_WINDOW_SIZE := Vector2i(1200, 700)
const LIQUID_REGION := Rect2i(625, 340, 270, 215)
const OUTSIDE_LEFT_REGION := Rect2i(620, 165, 32, 340)
const OUTSIDE_RIGHT_REGION := Rect2i(868, 165, 32, 340)
const WARMUP_FRAMES: int = 45
const SAMPLE_FRAMES: int = 180
const MINIMUM_AVERAGE_FPS: float = 45.0
const MAXIMUM_P95_MILLISECONDS: float = 22.22
const MINIMUM_VISIBLE_DIFFERENCE: float = 0.012


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(TEST_WINDOW_SIZE)
	var lab := SHAKER_SCENE.instantiate() as CocktailShakerLab
	root.add_child(lab)
	for _index: int in range(18):
		await physics_frame
	lab.select_fluid_by_id(FluidConfig.FluidId.WATER)
	lab.add_selected_fluid()
	for _index: int in range(36):
		await physics_frame
	lab.add_selected_fluid()
	for _index: int in range(36):
		await physics_frame
	lab.select_fluid_by_id(FluidConfig.FluidId.AMBER_SPIRIT)
	lab.add_selected_fluid()
	for _index: int in range(36):
		await physics_frame
	lab.add_ice()
	lab.add_ice()
	lab.add_ice()
	lab.set_lid_enabled(true)
	lab.start_shake()
	for index: int in range(WARMUP_FRAMES):
		lab.apply_mouse_drag_delta_for_test(Vector2(sin(float(index) * 0.32) * 115.0, cos(float(index) * 0.47) * 72.0))
		await process_frame
	var frame_milliseconds := PackedFloat32Array()
	var previous_ticks := Time.get_ticks_usec()
	for index: int in range(SAMPLE_FRAMES):
		lab.apply_mouse_drag_delta_for_test(Vector2(sin(float(index) * 0.32) * 115.0, cos(float(index) * 0.47) * 72.0))
		await process_frame
		var current_ticks := Time.get_ticks_usec()
		frame_milliseconds.append(float(current_ticks - previous_ticks) / 1000.0)
		previous_ticks = current_ticks
	frame_milliseconds.sort()
	var total_milliseconds := 0.0
	for duration: float in frame_milliseconds:
		total_milliseconds += duration
	var average_milliseconds := total_milliseconds / float(frame_milliseconds.size())
	var average_fps := 1000.0 / maxf(average_milliseconds, 0.001)
	var p95_index := clampi(ceili(float(frame_milliseconds.size()) * 0.95) - 1, 0, frame_milliseconds.size() - 1)
	var p95_milliseconds := frame_milliseconds[p95_index]
	var fluid_contained := lab.are_fluid_particles_contained()
	var ice_contained := lab.are_ice_bodies_contained(0.01)
	var shaker_bounded := lab.is_shaker_within_motion_bounds()
	lab.stop_shake_and_reset()
	# AnimatableBody2D 需要连续物理帧把复位 Transform 同步给 PhysicsServer。
	for _reset_frame: int in range(4):
		await physics_frame
	var fluid := lab.find_child("ParticleFluid", true, false) as ParticleFluid2D
	fluid.simulate = false
	for body: Node in lab.get_children():
		if body is RigidBody2D:
			(body as RigidBody2D).freeze = true
	for _index: int in range(3):
		await process_frame
	var visible_image := root.get_viewport().get_texture().get_image()
	fluid.set_rendering_enabled(false)
	for _index: int in range(3):
		await process_frame
	var hidden_image := root.get_viewport().get_texture().get_image()
	var visible_difference := _mean_difference(visible_image, hidden_image, LIQUID_REGION)
	var outside_difference := maxf(
		_mean_difference(visible_image, hidden_image, OUTSIDE_LEFT_REGION),
		_mean_difference(visible_image, hidden_image, OUTSIDE_RIGHT_REGION)
	)
	var output_directory := ProjectSettings.globalize_path("user://cocktail_shaker_lab")
	DirAccess.make_dir_recursive_absolute(output_directory)
	visible_image.save_png(output_directory.path_join("shaker_visible.png"))
	hidden_image.save_png(output_directory.path_join("shaker_hidden.png"))
	print("SHAKER_VISUAL average_fps=%.2f p95_ms=%.3f liquid_mean_difference=%.5f outside_difference=%.5f" % [
		average_fps,
		p95_milliseconds,
		visible_difference,
		outside_difference,
	])
	var failed := false
	if average_fps < MINIMUM_AVERAGE_FPS or p95_milliseconds > MAXIMUM_P95_MILLISECONDS:
		push_error("Shake 场景未通过 45 FPS 性能门禁")
		failed = true
	if visible_difference < MINIMUM_VISIBLE_DIFFERENCE:
		push_error("Shake 场景液体在暗色背景上不可见")
		failed = true
	if outside_difference > 0.002:
		push_error("Shake 场景光学液体越过封闭杯壁")
		failed = true
	if not fluid_contained or not ice_contained or not shaker_bounded:
		push_error("Shake 场景存在液体、冰块或杯体越界")
		failed = true
	lab.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _mean_difference(visible: Image, hidden: Image, region: Rect2i) -> float:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, visible.get_size()))
	var difference_sum := 0.0
	var sample_count := 0
	for y: int in range(clipped.position.y, clipped.end.y, 2):
		for x: int in range(clipped.position.x, clipped.end.x, 2):
			var before := hidden.get_pixel(x, y)
			var after := visible.get_pixel(x, y)
			difference_sum += (
				absf(after.r - before.r)
				+ absf(after.g - before.g)
				+ absf(after.b - before.b)
			) / 3.0
			sample_count += 1
	return 0.0 if sample_count == 0 else difference_sum / float(sample_count)
