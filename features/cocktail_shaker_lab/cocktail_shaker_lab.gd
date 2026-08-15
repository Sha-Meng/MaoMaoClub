extends Node2D
class_name CocktailShakerLab

const DEFAULT_CONFIG := preload("res://features/cocktail_shaker_lab/configs/default_shaker_test.tres")
const TEST_WINDOW_SIZE := Vector2i(1200, 700)

@export var test_config: ShakerTestConfig2D = DEFAULT_CONFIG

var _runtime_config: ShakerTestConfig2D
var _active_simulation: FluidParticleSimulationConfig2D
var _shaker: AnimatableBody2D
var _container_adapter: ContainerMotionAdapter2D
var _fluid: ParticleFluid2D
var _wall_collisions: Array[CollisionShape2D] = []
var _ice_bodies: Array[BuoyantBodyAdapter2D] = []
var _pours_by_fluid_id: Dictionary = {}

var _fluid_selector: OptionButton
var _add_fluid_button: Button
var _add_ice_button: Button
var _lid_button: Button
var _shake_button: Button
var _status_label: Label
var _metrics_label: Label
var _selection_label: Label
var _contents_label: Label

var _shake_active: bool = false
var _mouse_dragging: bool = false
var _mouse_drag_anchor: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
var _shake_target_offset: Vector2 = Vector2.ZERO
var _shake_current_offset: Vector2 = Vector2.ZERO
var _reset_shaker_physics_frames_remaining: int = 0
var _post_shake_settling_remaining_seconds: float = 0.0
var _shaker_linear_velocity_pixels_per_second: Vector2 = Vector2.ZERO
var _shaker_angular_velocity_radians_per_second: float = 0.0
var _ice_collision_event_count: int = 0
var _ice_to_ice_collision_event_count: int = 0


func _ready() -> void:
	var window := get_window()
	if window.size.x < TEST_WINDOW_SIZE.x or window.size.y < TEST_WINDOW_SIZE.y:
		window.size = TEST_WINDOW_SIZE
	window.min_size = TEST_WINDOW_SIZE
	_runtime_config = _make_runtime_config()
	var config_errors := _runtime_config.validate()
	if not config_errors.is_empty():
		push_error("Shake 测试配置无效：%s" % "；".join(config_errors))
		_build_error_interface(config_errors)
		return
	_active_simulation = _runtime_config.get_default_simulation()
	_build_shaker()
	_build_fluid(_active_simulation)
	_build_interface()
	reset_test()
	if OS.get_cmdline_user_args().has("--shaker-smoke"):
		call_deferred("_run_headless_smoke")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _shaker == null or _runtime_config == null:
		return
	var previous_position := _shaker.global_position
	var previous_rotation := _shaker.global_rotation
	if _reset_shaker_physics_frames_remaining > 0:
		_reset_shaker_transform_in_physics()
		_reset_shaker_physics_frames_remaining -= 1
		previous_position = _shaker.global_position
		previous_rotation = _shaker.global_rotation
	if _shake_active:
		var motion := _runtime_config.motion
		if not _mouse_dragging:
			var return_weight := 1.0 - exp(-motion.release_return_speed_per_second * delta)
			_shake_target_offset = _shake_target_offset.lerp(Vector2.ZERO, return_weight)
		var follow_weight := 1.0 - exp(-motion.follow_speed_per_second * delta)
		_shake_current_offset = motion.clamp_offset(
			_shake_current_offset.lerp(_shake_target_offset, follow_weight)
		)
		_shaker.transform = Transform2D(
			motion.rotation_for_offset(_shake_current_offset),
			_runtime_config.vessel.home_position_pixels + _shake_current_offset
		)
		if _shake_current_offset.length_squared() > 0.01:
			_fluid.wake()
	_shaker_linear_velocity_pixels_per_second = (
		(_shaker.global_position - previous_position) / delta if delta > 0.0 else Vector2.ZERO
	)
	_shaker_angular_velocity_radians_per_second = (
		angle_difference(previous_rotation, _shaker.global_rotation) / delta if delta > 0.0 else 0.0
	)
	if not _shake_active and _post_shake_settling_remaining_seconds > 0.0:
		_apply_post_shake_settling(delta)
	if is_lid_enabled():
		_enforce_ice_containment()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _shake_active or _runtime_config == null:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = mouse_button.pressed
		if mouse_button.pressed:
			_mouse_drag_anchor = mouse_button.position
			_drag_start_offset = _shake_target_offset
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and (_mouse_dragging or not _runtime_config.motion.require_left_mouse_button):
		var mouse_delta := mouse_motion.position - _mouse_drag_anchor
		_set_shake_target(_drag_start_offset + mouse_delta * _runtime_config.motion.mouse_sensitivity)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_SPACE:
			toggle_shake()
		KEY_R:
			reset_test()
		KEY_L:
			toggle_lid()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.025, 0.035, 0.052), true)
	draw_rect(Rect2(Vector2(410.0, 45.0), Vector2(760.0, 610.0)), Color(0.045, 0.062, 0.087), true)
	for x_position: int in range(430, 1171, 40):
		draw_line(Vector2(float(x_position), 55.0), Vector2(float(x_position), 645.0), Color(0.08, 0.11, 0.15), 1.0)
	for y_position: int in range(65, 646, 40):
		draw_line(Vector2(420.0, float(y_position)), Vector2(1160.0, float(y_position)), Color(0.08, 0.11, 0.15), 1.0)
	if _container_adapter == null or _container_adapter.container_shape == null or _shaker == null:
		return
	var shape := _container_adapter.container_shape
	var ppm := _active_simulation.particle_config.pixels_per_meter
	for index: int in range(shape.segment_count()):
		var start_pixels := _shaker.global_transform * (shape.segment_starts_local_meters[index] * ppm)
		var end_pixels := _shaker.global_transform * (shape.segment_ends_local_meters[index] * ppm)
		var is_lid_segment := is_lid_enabled() and index == 0
		draw_line(
			start_pixels,
			end_pixels,
			Color(0.92, 0.79, 0.35) if is_lid_segment else Color(0.68, 0.82, 0.96),
			10.0 if is_lid_segment else 8.0,
			true
		)


func reset_test() -> void:
	if _fluid == null:
		return
	stop_shake_and_reset()
	_fluid.simulate = false
	_fluid.reset(_runtime_config.random_seed)
	_clear_ice()
	_pours_by_fluid_id.clear()
	_ice_collision_event_count = 0
	_ice_to_ice_collision_event_count = 0
	_post_shake_settling_remaining_seconds = 0.0
	_runtime_config.vessel.lid_enabled = false
	_reset_shaker_physics_frames_remaining = 3
	_rebuild_shaker_geometry()
	_fluid.simulate = not _runtime_config.start_paused
	_update_interface()
	queue_redraw()


func add_selected_fluid() -> bool:
	if _shake_active or _fluid_selector == null or _fluid_selector.item_count == 0:
		return false
	var fluid_id := int(_fluid_selector.get_item_metadata(_fluid_selector.selected))
	return add_fluid(fluid_id)


func add_fluid(fluid_id: int) -> bool:
	if _shake_active:
		return false
	if is_lid_enabled():
		_set_status_message("杯盖已封闭，请先打开杯盖再加入液体。", false)
		return false
	var simulation := _runtime_config.particle_simulation_table.get_config(fluid_id)
	if simulation == null:
		_set_status_message("未找到 FluidId=%d 的粒子模拟配置。" % fluid_id, false)
		return false
	if get_particle_count() == 0 and _active_simulation.fluid_id != simulation.fluid_id:
		_rebuild_empty_fluid(simulation)
	var add_count := _particle_count_for_active_solver(simulation.volume_per_add_liters)
	var current_count := get_particle_count()
	var limit := mini(_runtime_config.maximum_particles, _runtime_config.container_particle_capacity())
	if current_count + add_count > limit:
		_set_status_message("无法加入：需要 %d 粒子，剩余预算 %d。" % [add_count, limit - current_count], false)
		return false
	_spawn_fluid_batch(simulation, add_count)
	_pours_by_fluid_id[fluid_id] = int(_pours_by_fluid_id.get(fluid_id, 0)) + 1
	_fluid.wake()
	_update_interface()
	return true


func add_ice() -> bool:
	if _shake_active or not _runtime_config.ice.enabled:
		return false
	if is_lid_enabled():
		_set_status_message("杯盖已封闭，请先打开杯盖再加入冰块。", false)
		return false
	if _ice_bodies.size() >= _runtime_config.ice.maximum_count:
		_set_status_message("冰块已达到上限 %d。" % _runtime_config.ice.maximum_count, false)
		return false
	_spawn_one_ice(_ice_bodies.size())
	_fluid.set_buoyant_adapters(_ice_bodies)
	_update_interface()
	return true


func toggle_lid() -> void:
	if _shake_active:
		return
	set_lid_enabled(not is_lid_enabled())


func set_lid_enabled(enabled: bool) -> void:
	if _runtime_config == null or _runtime_config.vessel.lid_enabled == enabled:
		return
	_runtime_config.vessel.lid_enabled = enabled
	_rebuild_shaker_geometry()
	_container_adapter.reset_history()
	_fluid.wake()
	_update_interface()
	queue_redraw()


func toggle_shake() -> void:
	if _shake_active:
		stop_shake_and_reset()
	else:
		start_shake()


func start_shake() -> bool:
	if _fluid == null or _shake_active:
		return false
	if not is_lid_enabled():
		_set_status_message("请先封盖，再开始 Shake。", false)
		return false
	_shake_active = true
	_post_shake_settling_remaining_seconds = 0.0
	_mouse_dragging = false
	_shake_target_offset = Vector2.ZERO
	_shake_current_offset = (
		Vector2.ZERO
		if _reset_shaker_physics_frames_remaining > 0
		else _shaker.position - _runtime_config.vessel.home_position_pixels
	)
	_fluid.simulate = true
	_fluid.wake()
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if is_instance_valid(body):
			body.sleeping = false
	_update_interface()
	return true


func stop_shake_and_reset() -> void:
	_shake_active = false
	_mouse_dragging = false
	_shake_target_offset = Vector2.ZERO
	_shake_current_offset = Vector2.ZERO
	if _shaker != null and _runtime_config != null:
		_reset_shaker_physics_frames_remaining = 3
		_post_shake_settling_remaining_seconds = _runtime_config.motion.settling_duration_seconds
	_update_interface()
	queue_redraw()


func apply_mouse_drag_delta_for_test(mouse_delta: Vector2) -> void:
	if not _shake_active:
		return
	_set_shake_target(mouse_delta * _runtime_config.motion.mouse_sensitivity)


func select_fluid_by_id(fluid_id: int) -> bool:
	if _fluid_selector == null:
		return false
	for index: int in range(_fluid_selector.item_count):
		if int(_fluid_selector.get_item_metadata(index)) == fluid_id:
			_fluid_selector.select(index)
			_on_fluid_selected(index)
			return true
	return false


func is_lid_enabled() -> bool:
	return _runtime_config != null and _runtime_config.vessel.lid_enabled


func is_shaking() -> bool:
	return _shake_active


func get_available_fluid_count() -> int:
	return 0 if _runtime_config == null else _runtime_config.fluid_catalog.fluids.size()


func get_particle_count() -> int:
	return 0 if _fluid == null else _fluid.get_state_snapshot().count()


func get_ice_count() -> int:
	return _ice_bodies.size()


func get_average_fluid_speed_meters_per_second() -> float:
	var snapshot := get_fluid_snapshot()
	if snapshot.count() == 0:
		return 0.0
	var speed_sum := 0.0
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		speed_sum += velocity.length()
	return speed_sum / float(snapshot.count())


func get_maximum_ice_speed_pixels_per_second() -> float:
	var maximum_speed := 0.0
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if is_instance_valid(body):
			maximum_speed = maxf(maximum_speed, body.linear_velocity.length())
	return maximum_speed


func get_ice_collision_event_count() -> int:
	return _ice_collision_event_count


func get_ice_to_ice_collision_event_count() -> int:
	return _ice_to_ice_collision_event_count


func ice_collision_configuration_is_valid() -> bool:
	if _runtime_config == null:
		return false
	var ice_layer := _runtime_config.ice.collision_layer
	var vessel_layer := _runtime_config.vessel.collision_layer
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if not is_instance_valid(body):
			return false
		if (body.collision_layer & ice_layer) == 0:
			return false
		if (body.collision_mask & ice_layer) == 0 or (body.collision_mask & vessel_layer) == 0:
			return false
	return true


func is_post_shake_settling() -> bool:
	return _post_shake_settling_remaining_seconds > 0.0


func is_fluid_quiescent_damping_active() -> bool:
	return _fluid != null and _fluid.is_quiescent_damping_active()


func get_container_segment_count() -> int:
	if _container_adapter == null or _container_adapter.container_shape == null:
		return 0
	return _container_adapter.container_shape.segment_count()


func get_shake_target_offset() -> Vector2:
	return _shake_target_offset


func get_shaker_offset() -> Vector2:
	if _shaker == null or _runtime_config == null:
		return Vector2.ZERO
	if _shake_active:
		return _shake_current_offset
	return _shaker.position - _runtime_config.vessel.home_position_pixels


func get_shaker_rotation_radians() -> float:
	return 0.0 if _shaker == null else _shaker.rotation


func is_shaker_within_motion_bounds(tolerance: float = 0.01) -> bool:
	if _runtime_config == null:
		return false
	var offset := get_shaker_offset()
	var maximum := _runtime_config.motion.maximum_offset_pixels
	return absf(offset.x) <= maximum.x + tolerance and absf(offset.y) <= maximum.y + tolerance


func is_shaker_at_home() -> bool:
	if _shake_active:
		return (
			_shake_current_offset.length_squared() <= 0.0001
			and absf(_runtime_config.motion.rotation_for_offset(_shake_current_offset)) <= 0.0001
		)
	return get_shaker_offset().length_squared() <= 0.0001 and absf(_shaker.rotation) <= 0.0001


func are_ice_bodies_contained(margin_meters: float = 0.12) -> bool:
	if _shaker == null or _runtime_config == null:
		return false
	var inverse := _shaker.global_transform.affine_inverse()
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var vessel := _runtime_config.vessel
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if not is_instance_valid(body):
			return false
		var local_meters := (inverse * body.global_position) / ppm
		if local_meters.x < -vessel.width_meters * 0.5 - margin_meters or local_meters.x > vessel.width_meters * 0.5 + margin_meters:
			return false
		if local_meters.y < -margin_meters or local_meters.y > vessel.height_meters + margin_meters:
			return false
	return true


func are_fluid_particles_contained(margin_meters: float = 0.02) -> bool:
	if _fluid == null or _shaker == null or _active_simulation == null:
		return false
	var snapshot := _fluid.get_state_snapshot()
	var inverse := _shaker.global_transform.affine_inverse()
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var vessel := _runtime_config.vessel
	for world_meters: Vector2 in snapshot.positions_meters:
		var local_meters := (inverse * (world_meters * ppm)) / ppm
		if local_meters.x < -vessel.width_meters * 0.5 - margin_meters or local_meters.x > vessel.width_meters * 0.5 + margin_meters:
			return false
		if local_meters.y < -margin_meters or local_meters.y > vessel.height_meters + margin_meters:
			return false
	return true


func get_fluid_local_bounds() -> Rect2:
	if _fluid == null or _shaker == null or _active_simulation == null:
		return Rect2()
	var snapshot := _fluid.get_state_snapshot()
	if snapshot.count() == 0:
		return Rect2()
	var inverse := _shaker.global_transform.affine_inverse()
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var first := (inverse * (snapshot.positions_meters[0] * ppm)) / ppm
	var bounds := Rect2(first, Vector2.ZERO)
	for world_meters: Vector2 in snapshot.positions_meters:
		bounds = bounds.expand((inverse * (world_meters * ppm)) / ppm)
	return bounds


func get_fluid_snapshot() -> ParticleFluidSnapshot2D:
	return ParticleFluidSnapshot2D.new() if _fluid == null else _fluid.get_state_snapshot()


func get_runtime_config() -> ShakerTestConfig2D:
	return _runtime_config


func _make_runtime_config() -> ShakerTestConfig2D:
	var source := test_config if test_config != null else DEFAULT_CONFIG
	return source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ShakerTestConfig2D


func _build_shaker() -> void:
	_shaker = AnimatableBody2D.new()
	_shaker.name = "ShakerVessel"
	# 杯体在物理帧内移动，并同步给 PhysicsServer，移动杯壁才能向冰块传递冲量。
	_shaker.sync_to_physics = true
	_shaker.position = _runtime_config.vessel.home_position_pixels
	_shaker.collision_layer = _runtime_config.vessel.collision_layer
	_shaker.collision_mask = _runtime_config.vessel.collision_mask
	add_child(_shaker)
	_container_adapter = ContainerMotionAdapter2D.new()
	_container_adapter.name = "ContainerMotionAdapter"
	_container_adapter.container_shape = ContainerShape2D.new()
	_shaker.add_child(_container_adapter)
	_rebuild_shaker_geometry()


func _rebuild_shaker_geometry() -> void:
	for collision: CollisionShape2D in _wall_collisions:
		if is_instance_valid(collision):
			collision.disabled = true
			collision.queue_free()
	_wall_collisions.clear()
	var vessel := _runtime_config.vessel
	if vessel.lid_enabled:
		_container_adapter.container_shape.configure_convex_polygon(PackedVector2Array([
			Vector2(-vessel.width_meters * 0.5, 0.0),
			Vector2(vessel.width_meters * 0.5, 0.0),
			Vector2(vessel.width_meters * 0.5, vessel.height_meters),
			Vector2(-vessel.width_meters * 0.5, vessel.height_meters),
		]))
	else:
		_container_adapter.container_shape.configure_open_cup(vessel.width_meters, vessel.height_meters)
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var half_width_pixels := vessel.width_meters * ppm * 0.5
	var height_pixels := vessel.height_meters * ppm
	var thickness := vessel.wall_thickness_pixels
	_add_wall_collision(Vector2(-half_width_pixels - thickness * 0.5, height_pixels * 0.5), Vector2(thickness, height_pixels + thickness * 2.0))
	_add_wall_collision(Vector2(half_width_pixels + thickness * 0.5, height_pixels * 0.5), Vector2(thickness, height_pixels + thickness * 2.0))
	_add_wall_collision(Vector2(0.0, height_pixels + thickness * 0.5), Vector2(half_width_pixels * 2.0, thickness))
	if vessel.lid_enabled:
		_add_wall_collision(Vector2(0.0, -thickness * 0.5), Vector2(half_width_pixels * 2.0, thickness))


func _add_wall_collision(center_pixels: Vector2, size_pixels: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size_pixels
	collision.position = center_pixels
	collision.shape = rectangle
	_shaker.add_child(collision)
	_wall_collisions.append(collision)


func _build_fluid(simulation: FluidParticleSimulationConfig2D) -> void:
	_active_simulation = simulation
	_fluid = ParticleFluid2D.new()
	_fluid.name = "ParticleFluid"
	_fluid.config = simulation.particle_config
	_fluid.render_mode = _runtime_config.render_mode
	_fluid.optical_field_resolution = _runtime_config.optical_field_resolution
	_fluid.optical_surface_fill_scale = _runtime_config.optical_surface_fill_scale
	add_child(_fluid)
	_fluid.set_container_adapter(_container_adapter)
	_fluid.set_rendering_enabled(_runtime_config.rendering_enabled)
	_fluid.step_completed.connect(_on_step_completed)
	_configure_all_materials()


func _rebuild_empty_fluid(simulation: FluidParticleSimulationConfig2D) -> void:
	if _fluid != null:
		remove_child(_fluid)
		_fluid.queue_free()
	_build_fluid(simulation)
	_fluid.set_external_acceleration(simulation.particle_config.gravity_meters_per_second_squared)
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		body.pixels_per_meter = simulation.particle_config.pixels_per_meter
		body.effective_depth_meters = simulation.particle_config.effective_depth_meters
		body.refresh_fluid_snapshot()
	_fluid.set_buoyant_adapters(_ice_bodies)


func _configure_all_materials() -> void:
	var materials: Array[FluidMaterial2D] = []
	for simulation: FluidParticleSimulationConfig2D in _runtime_config.particle_simulation_table.entries:
		materials.append(simulation.to_fluid_material())
	var errors := _fluid.set_materials(materials)
	if not errors.is_empty():
		push_error("Shake 液体材质注册失败：%s" % "；".join(errors))


func _particle_count_for_active_solver(volume_liters: float) -> int:
	var particle_volume := (
		_runtime_config.particle_spacing_meters
		* _runtime_config.particle_spacing_meters
		* _active_simulation.particle_config.effective_depth_meters
		* 1000.0
	)
	return maxi(1, ceili(volume_liters / particle_volume))


func _spawn_fluid_batch(simulation: FluidParticleSimulationConfig2D, count: int) -> void:
	var spacing := _runtime_config.particle_spacing_meters
	var vessel := _runtime_config.vessel
	var margin := spacing * 0.6
	var columns := mini(simulation.pour_stream_columns, count)
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var batch := ParticleSpawnBatch2D.new()
	for particle_offset: int in range(count):
		var column := particle_offset % columns
		var row_from_top := particle_offset / columns
		var stream_width := float(maxi(columns - 1, 0)) * spacing
		var local_meters := Vector2(
			-stream_width * 0.5 + float(column) * spacing,
			simulation.pour_spawn_depth_meters + margin + float(row_from_top) * spacing * 0.82
		)
		var world_pixels := _shaker.global_transform * (local_meters * ppm)
		batch.positions_meters.append(world_pixels / ppm)
		batch.velocities_meters_per_second.append(Vector2(
			0.0, simulation.pour_initial_downward_speed_meters_per_second
		))
		batch.colors_srgb.append(simulation.display_color_srgb)
		batch.concentrations.append(simulation.concentration)
		batch.turbidities.append(simulation.turbidity)
		batch.material_ids.append(simulation.fluid_id)
	_fluid.add_particles(batch)


func _enforce_ice_containment() -> void:
	if _ice_bodies.is_empty() or _shaker == null:
		return
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var vessel := _runtime_config.vessel
	var inverse := _shaker.global_transform.affine_inverse()
	var ice_radius := _runtime_config.ice.size_meters.length() * 0.5
	var minimum := Vector2(-vessel.width_meters * 0.5 + ice_radius, ice_radius)
	var maximum := Vector2(vessel.width_meters * 0.5 - ice_radius, vessel.height_meters - ice_radius)
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if not is_instance_valid(body):
			continue
		var local_meters := (inverse * body.global_position) / ppm
		var hit_left := local_meters.x < minimum.x
		var hit_right := local_meters.x > maximum.x
		var hit_top := local_meters.y < minimum.y
		var hit_bottom := local_meters.y > maximum.y
		var contained := Vector2(
			clampf(local_meters.x, minimum.x, maximum.x),
			clampf(local_meters.y, minimum.y, maximum.y)
		)
		if contained.is_equal_approx(local_meters):
			continue
		body.global_position = _shaker.global_transform * (contained * ppm)
		var body_offset_pixels := body.global_position - _shaker.global_position
		var wall_velocity := _shaker_linear_velocity_pixels_per_second + Vector2(
			-body_offset_pixels.y, body_offset_pixels.x
		) * _shaker_angular_velocity_radians_per_second
		var relative_local_velocity := (body.linear_velocity - wall_velocity).rotated(-_shaker.global_rotation)
		var restitution := _runtime_config.ice.containment_restitution
		var tangent_retention := _runtime_config.ice.containment_tangent_retention
		if (hit_left and relative_local_velocity.x < 0.0) or (hit_right and relative_local_velocity.x > 0.0):
			relative_local_velocity.x *= -restitution
			relative_local_velocity.y *= tangent_retention
		if (hit_top and relative_local_velocity.y < 0.0) or (hit_bottom and relative_local_velocity.y > 0.0):
			relative_local_velocity.y *= -restitution
			relative_local_velocity.x *= tangent_retention
		body.linear_velocity = wall_velocity + relative_local_velocity.rotated(_shaker.global_rotation)
		body.angular_velocity *= tangent_retention
		body.sleeping = false
		body.refresh_fluid_snapshot()


func _spawn_one_ice(index: int) -> void:
	var ice := _runtime_config.ice
	var ppm := _active_simulation.particle_config.pixels_per_meter
	var body := BuoyantBodyAdapter2D.new()
	body.name = "IceCube%02d" % (index + 1)
	body.body_id = 1000 + index
	body.pixels_per_meter = ppm
	body.mass = ice.mass_kilograms(_active_simulation.particle_config.effective_depth_meters)
	body.effective_depth_meters = _active_simulation.particle_config.effective_depth_meters
	body.drag_coefficient = ice.drag_coefficient
	body.maximum_fluid_force = ice.maximum_fluid_force
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = ice.linear_damp_per_second
	body.angular_damp = ice.angular_damp_per_second
	body.collision_layer = ice.collision_layer
	body.collision_mask = ice.collision_mask
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.max_contacts_reported = 8
	body.contact_monitor = true
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = ice.collision_friction
	physics_material.bounce = ice.collision_bounce
	body.physics_material_override = physics_material
	var fluid_shape := BuoyantBodyShape2D.new()
	fluid_shape.shape_type = BuoyantBodyShape2D.ShapeType.RECTANGLE
	fluid_shape.size_meters = ice.size_meters
	fluid_shape.sample_spacing_meters = ice.sample_spacing_meters
	body.fluid_shape = fluid_shape
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = ice.size_meters * ppm
	collision.shape = rectangle
	body.add_child(collision)
	var visual := Polygon2D.new()
	var half_size := rectangle.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
	])
	visual.color = ice.color
	body.add_child(visual)
	var outline := Line2D.new()
	outline.points = visual.polygon
	outline.closed = true
	outline.width = 2.0
	outline.default_color = ice.outline_color
	body.add_child(outline)
	var slot_width := ice.size_meters.x + ice.gap_meters
	var first_x := -float(maxi(ice.maximum_count - 1, 0)) * slot_width * 0.5
	var local_position := Vector2(first_x + float(index) * slot_width, 0.22 + float(index % 2) * 0.05)
	body.position = _shaker.global_transform * (local_position * ppm)
	body.rotation = -0.12 + float(index) * 0.12
	add_child(body)
	body.body_entered.connect(_on_ice_body_entered)
	body.refresh_fluid_snapshot()
	_ice_bodies.append(body)


func _clear_ice() -> void:
	var no_adapters: Array[BuoyantBodyAdapter2D] = []
	_fluid.set_buoyant_adapters(no_adapters)
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if is_instance_valid(body):
			body.freeze = true
			body.queue_free()
	_ice_bodies.clear()


func _set_shake_target(value: Vector2) -> void:
	_shake_target_offset = _runtime_config.motion.clamp_offset(value)
	_fluid.wake()


func _reset_shaker_transform_in_physics() -> void:
	_shaker.transform = Transform2D(0.0, _runtime_config.vessel.home_position_pixels)
	_shaker.reset_physics_interpolation()
	_shaker_linear_velocity_pixels_per_second = Vector2.ZERO
	_shaker_angular_velocity_radians_per_second = 0.0
	if _container_adapter != null:
		_container_adapter.reset_history()


func _apply_post_shake_settling(delta: float) -> void:
	var motion := _runtime_config.motion
	var linear_weight := exp(-motion.settling_ice_linear_damping_per_second * delta)
	var angular_weight := exp(-motion.settling_ice_angular_damping_per_second * delta)
	for body: BuoyantBodyAdapter2D in _ice_bodies:
		if not is_instance_valid(body):
			continue
		body.linear_velocity *= linear_weight
		body.angular_velocity *= angular_weight
		if (
			body.linear_velocity.length() <= motion.settling_ice_stop_speed_pixels_per_second
			and absf(body.angular_velocity) <= motion.settling_ice_stop_angular_speed
		):
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
	_post_shake_settling_remaining_seconds = maxf(
		0.0, _post_shake_settling_remaining_seconds - delta
	)


func _on_ice_body_entered(other_body: Node) -> void:
	_ice_collision_event_count += 1
	if other_body is BuoyantBodyAdapter2D:
		_ice_to_ice_collision_event_count += 1


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShakerInterface"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(370.0, 645.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.105, 0.97)
	style.border_color = Color(0.18, 0.28, 0.40)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	var title := Label.new()
	title.text = "调酒 Shake 配表测试"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var help := Label.new()
	help.text = "流程：选择液体 → 加液体/冰块 → 封盖 → Shake\nShake 中按住鼠标左键，上下左右拖动杯子。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	_fluid_selector = OptionButton.new()
	for fluid: FluidConfig in _runtime_config.fluid_catalog.fluids:
		_fluid_selector.add_item(fluid.fluid_name)
		_fluid_selector.set_item_metadata(_fluid_selector.item_count - 1, fluid.fluid_id)
	_fluid_selector.item_selected.connect(_on_fluid_selected)
	content.add_child(_fluid_selector)
	var add_row := HBoxContainer.new()
	content.add_child(add_row)
	_add_fluid_button = Button.new()
	_add_fluid_button.text = "增加液体"
	_add_fluid_button.pressed.connect(add_selected_fluid)
	add_row.add_child(_add_fluid_button)
	_add_ice_button = Button.new()
	_add_ice_button.text = "增加冰块"
	_add_ice_button.pressed.connect(add_ice)
	add_row.add_child(_add_ice_button)
	_lid_button = Button.new()
	_lid_button.pressed.connect(toggle_lid)
	add_row.add_child(_lid_button)
	var action_row := HBoxContainer.new()
	content.add_child(action_row)
	_shake_button = Button.new()
	_shake_button.pressed.connect(toggle_shake)
	action_row.add_child(_shake_button)
	var reset_button := Button.new()
	reset_button.text = "清空并重置"
	reset_button.pressed.connect(reset_test)
	action_row.add_child(reset_button)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	_metrics_label = Label.new()
	_metrics_label.text = "空杯：等待加入测试内容。"
	content.add_child(_metrics_label)
	content.add_child(HSeparator.new())
	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selection_label)
	_contents_label = Label.new()
	_contents_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_contents_label)
	if _fluid_selector.item_count > 0:
		_on_fluid_selected(0)
	_update_interface()


func _build_error_interface(errors: PackedStringArray) -> void:
	var label := Label.new()
	label.position = Vector2(24.0, 24.0)
	label.text = "Shake 测试配置错误：\n- %s" % "\n- ".join(errors)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	add_child(label)


func _on_fluid_selected(index: int) -> void:
	if _fluid_selector == null or index < 0 or index >= _fluid_selector.item_count:
		return
	var fluid_id := int(_fluid_selector.get_item_metadata(index))
	var fluid := _runtime_config.fluid_catalog.get_fluid(fluid_id)
	var simulation := _runtime_config.particle_simulation_table.get_config(fluid_id)
	if fluid == null or simulation == null:
		_selection_label.text = "配表缺失：FluidId=%d" % fluid_id
		return
	_selection_label.text = "已选：%s [%s]\n单次 %.3f L → %d 粒子｜密度×%.3f｜黏度×%.2f\n真实参考：ρ %.1f kg/m³｜μ %.6f Pa·s" % [
		fluid.fluid_name,
		FluidConfig.id_name(fluid.fluid_id),
		simulation.volume_per_add_liters,
		_runtime_config.particle_count_per_add(simulation),
		simulation.density_multiplier,
		simulation.viscosity_multiplier,
		fluid.reference_density_kg_per_cubic_meter,
		fluid.reference_dynamic_viscosity_pascal_seconds,
	]


func _update_interface() -> void:
	if _status_label == null:
		return
	var mode := "鼠标 Shake：按住左键拖动" if _shake_active else "配置模式"
	_status_label.text = "杯盖：%s｜%s｜灵敏度 %.2f｜最大幅度 %.0f×%.0f px" % [
		"已封闭" if is_lid_enabled() else "未封盖",
		mode,
		_runtime_config.motion.mouse_sensitivity,
		_runtime_config.motion.maximum_offset_pixels.x,
		_runtime_config.motion.maximum_offset_pixels.y,
	]
	_lid_button.text = "打开杯盖" if is_lid_enabled() else "封盖"
	_shake_button.text = "结束 Shake 并复位" if _shake_active else "Shake"
	_shake_button.disabled = not _shake_active and not is_lid_enabled()
	_add_fluid_button.disabled = _shake_active or is_lid_enabled()
	_add_ice_button.disabled = _shake_active or is_lid_enabled() or get_ice_count() >= _runtime_config.ice.maximum_count
	_fluid_selector.disabled = _shake_active
	var content_lines := PackedStringArray(["杯中内容：粒子 %d / %d｜冰块 %d / %d" % [
		get_particle_count(), _runtime_config.maximum_particles,
		get_ice_count(), _runtime_config.ice.maximum_count,
	]])
	for fluid_id_value: Variant in _pours_by_fluid_id.keys():
		var fluid := _runtime_config.fluid_catalog.get_fluid(int(fluid_id_value))
		if fluid != null:
			content_lines.append("• %s：已加入 %d 次" % [fluid.fluid_name, int(_pours_by_fluid_id[fluid_id_value])])
	if _pours_by_fluid_id.is_empty() and _ice_bodies.is_empty():
		content_lines.append("• 当前为空杯")
	_contents_label.text = "\n".join(content_lines)
	queue_redraw()


func _set_status_message(message: String, success: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.6) if success else Color(1.0, 0.55, 0.30))


func _on_step_completed(result: FluidStepResult2D) -> void:
	if is_lid_enabled():
		_fluid.enforce_closed_container_containment(_make_current_container_snapshot())
	if _post_shake_settling_remaining_seconds > 0.0:
		_fluid.apply_velocity_damping(
			_runtime_config.motion.settling_fluid_damping_per_second,
			get_physics_process_delta_time(),
			_runtime_config.motion.settling_fluid_stop_speed_meters_per_second
		)
	if _metrics_label == null:
		return
	var physics_milliseconds := float(
		result.profile_spatial_hash_microseconds + result.profile_density_microseconds
		+ result.profile_forces_microseconds + result.profile_integration_microseconds
	) / 1000.0
	_metrics_label.text = "FPS %d｜物理 %.2f ms｜粒子 %d｜冰 %d\n子步 %d/%d｜最大速度 %.2f m/s%s" % [
		Engine.get_frames_per_second(), physics_milliseconds, result.particle_count,
		_ice_bodies.size(), result.substeps, _active_simulation.particle_config.max_substeps,
		result.maximum_speed, "｜已静稳" if result.quiescent_damping_active else "",
	]


func _make_current_container_snapshot() -> ContainerSnapshot2D:
	var snapshot := ContainerSnapshot2D.new()
	snapshot.shape = _container_adapter.container_shape
	snapshot.world_transform = Transform2D(
		_shaker.global_rotation,
		_shaker.global_position / _active_simulation.particle_config.pixels_per_meter
	)
	return snapshot


func _run_headless_smoke() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures := PackedStringArray()
	if get_available_fluid_count() < 1:
		failures.append("no fluids in catalog")
	if get_particle_count() != 0 or get_ice_count() != 0:
		failures.append("initial scene must be empty")
	if is_lid_enabled() or get_container_segment_count() != 3:
		failures.append("initial cup must be open")
	if not add_selected_fluid():
		failures.append("add fluid failed")
	if not add_ice():
		failures.append("add ice failed")
	set_lid_enabled(true)
	if not start_shake():
		failures.append("start shake failed")
	apply_mouse_drag_delta_for_test(Vector2(1000.0, -1000.0))
	if absf(get_shake_target_offset().x) > _runtime_config.motion.maximum_offset_pixels.x or absf(get_shake_target_offset().y) > _runtime_config.motion.maximum_offset_pixels.y:
		failures.append("shake amplitude was not clamped")
	stop_shake_and_reset()
	for _reset_frame: int in range(4):
		await get_tree().physics_frame
	if not is_shaker_at_home():
		failures.append("shake reset did not return home")
	if not failures.is_empty():
		push_error("Cocktail shaker smoke failed: %s" % "; ".join(failures))
		get_tree().quit(1)
		return
	print("Cocktail shaker smoke: catalog=%d particles=%d ice=%d lid=%s home=%s" % [
		get_available_fluid_count(), get_particle_count(), get_ice_count(), is_lid_enabled(), is_shaker_at_home()
	])
	get_tree().quit(0)
