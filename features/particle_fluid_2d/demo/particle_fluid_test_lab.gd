extends Node2D
class_name ParticleFluidTestLab

enum Scenario {
	MIXING,
	VISCOSITY,
	DENSITY,
	COLLOID,
	ICE,
	HEAVY,
	CUSTOM,
}

const PIXELS_PER_METER: float = 100.0
const CUP_HOME_PIXELS: Vector2 = Vector2(760.0, 112.0)
const DEFAULT_CUP_WIDTH_METERS: float = 2.0
const DEFAULT_CUP_HEIGHT_METERS: float = 4.0
const MIN_CUP_WIDTH_METERS: float = 2.0
const MAX_CUP_WIDTH_METERS: float = 6.4
const MIN_CUP_HEIGHT_METERS: float = 2.0
const MAX_CUP_HEIGHT_METERS: float = 4.5
const WALL_THICKNESS_PIXELS: float = 18.0
const PARTICLE_SPACING_METERS: float = 0.20
const EFFECTIVE_DEPTH_METERS: float = 0.10
const SMOOTHING_RADIUS_RATIO: float = 1.9
const WATER_NUMERICAL_SOUND_SPEED: float = 6.5
const WATER_BASE_VISCOSITY: float = 4.0
const WATER_BOUNDARY_RESTITUTION: float = 0.0
const WATER_BOUNDARY_FRICTION: float = 0.05
const WATER_QUIESCENT_DAMPING_PER_SECOND: float = 18.0
const WATER_QUIESCENT_ACTIVATION_DELAY_SECONDS: float = 0.45
const WATER_QUIESCENT_STOP_SPEED: float = 0.04
const FLUID_MARGIN_METERS: float = PARTICLE_SPACING_METERS * 0.5
const DEFAULT_LIQUID_VOLUME_LITERS: float = 120.0
const ICE_MASS_KILOGRAMS: float = 7.0
const HEAVY_MASS_KILOGRAMS: float = 24.0
const MAX_INTERACTIVE_PARTICLES: int = 136
const AUTO_ACTION_INTERVAL_SECONDS: float = 1.8
const TEST_WINDOW_SIZE: Vector2i = Vector2i(1200, 700)
const TEST_CASE_COUNT: int = 6

var _fluid: ParticleFluid2D
var _cup: AnimatableBody2D
var _container_adapter: ContainerMotionAdapter2D
var _floating_body: BuoyantBodyAdapter2D
var _body_visual: Polygon2D
var _scenario_label: Label
var _objective_label: Label
var _metrics_label: Label
var _health_label: Label
var _criteria_label: Label
var _cup_width_spin: SpinBox
var _cup_height_spin: SpinBox
var _fluid_color_picker: ColorPickerButton
var _recipe_selector: OptionButton
var _volume_liters_spin: SpinBox
var _derived_particle_count_label: Label
var _concentration_spin: SpinBox
var _turbidity_spin: SpinBox
var _recipe_list_label: Label
var _capacity_label: Label
var _config_feedback_label: Label
var _scenario: int = Scenario.MIXING
var _cup_width_meters: float = DEFAULT_CUP_WIDTH_METERS
var _cup_height_meters: float = DEFAULT_CUP_HEIGHT_METERS
var _cup_wall_collisions: Array[CollisionShape2D] = []
var _fluid_recipes: Array[ParticleFluidTestRecipe2D] = []
var _cup_velocity_pixels_per_second: Vector2 = Vector2.ZERO
var _cup_angular_velocity_radians_per_second: float = 0.0
var _rendering_enabled: bool = true
var _auto_demo_enabled: bool = false
var _auto_demo_elapsed_seconds: float = 0.0
var _auto_demo_direction: float = 1.0

func _ready() -> void:
	var window := get_window()
	if window.size.x < TEST_WINDOW_SIZE.x or window.size.y < TEST_WINDOW_SIZE.y:
		window.size = TEST_WINDOW_SIZE
	window.min_size = TEST_WINDOW_SIZE
	_build_container()
	_build_fluid()
	_build_body()
	_build_interface()
	_load_scenario(Scenario.MIXING)
	if OS.get_cmdline_user_args().has("--lab-smoke"):
		call_deferred("_run_headless_smoke")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _auto_demo_enabled:
		_auto_demo_elapsed_seconds += delta
		if _auto_demo_elapsed_seconds >= AUTO_ACTION_INTERVAL_SECONDS:
			_auto_demo_elapsed_seconds = 0.0
			_apply_cup_impulse(170.0 * _auto_demo_direction)
			_auto_demo_direction *= -1.0
			if _auto_demo_direction > 0.0:
				_apply_fluid_impulse()
	var horizontal_input := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var angular_input := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if not is_zero_approx(horizontal_input) or not is_zero_approx(angular_input):
		_fluid.wake()
	_cup_velocity_pixels_per_second.x += horizontal_input * 520.0 * delta
	_cup_angular_velocity_radians_per_second += angular_input * 2.4 * delta
	_cup_velocity_pixels_per_second.x = clampf(_cup_velocity_pixels_per_second.x, -320.0, 320.0)
	_cup_angular_velocity_radians_per_second = clampf(_cup_angular_velocity_radians_per_second, -1.5, 1.5)
	var horizontal_limit := _cup_horizontal_travel_pixels()
	_cup.position += _cup_velocity_pixels_per_second * delta
	_cup.position.x = clampf(_cup.position.x, CUP_HOME_PIXELS.x - horizontal_limit, CUP_HOME_PIXELS.x + horizontal_limit)
	_cup.rotation = clampf(_cup.rotation + _cup_angular_velocity_radians_per_second * delta, -0.72, 0.72)
	if is_equal_approx(absf(_cup.position.x - CUP_HOME_PIXELS.x), horizontal_limit):
		_cup_velocity_pixels_per_second.x = 0.0
	if is_equal_approx(absf(_cup.rotation), 0.72):
		_cup_angular_velocity_radians_per_second = 0.0
	_cup_velocity_pixels_per_second *= exp(-2.8 * delta)
	_cup_angular_velocity_radians_per_second *= exp(-3.2 * delta)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_1:
			_load_scenario(Scenario.MIXING)
		KEY_2:
			_load_scenario(Scenario.VISCOSITY)
		KEY_3:
			_load_scenario(Scenario.DENSITY)
		KEY_4:
			_load_scenario(Scenario.COLLOID)
		KEY_5:
			_load_scenario(Scenario.ICE)
		KEY_6:
			_load_scenario(Scenario.HEAVY)
		KEY_R:
			_load_scenario(_scenario)
		KEY_P:
			_fluid.simulate = not _fluid.simulate
			_update_scenario_label()
		KEY_V:
			_rendering_enabled = not _rendering_enabled
			_fluid.set_rendering_enabled(_rendering_enabled)
		KEY_M:
			_toggle_render_mode()
		KEY_B:
			_toggle_auto_demo()
		KEY_SPACE:
			_apply_fluid_impulse()

func _run_headless_smoke() -> void:
	_clear_custom_fluids()
	_cup_width_spin.value = 4.2
	_cup_height_spin.value = 3.2
	_apply_cup_dimensions()
	_fluid_color_picker.color = Color(0.95, 0.15, 0.1, 0.8)
	_volume_liters_spin.value = 120.0
	_concentration_spin.value = 1.1
	_turbidity_spin.value = 0.6
	_add_custom_fluid()
	_fluid_color_picker.color = Color(0.15, 0.85, 0.3, 0.7)
	_volume_liters_spin.value = 80.0
	_concentration_spin.value = 0.8
	_turbidity_spin.value = 1.2
	_add_custom_fluid()
	_recipe_selector.select(0)
	_on_recipe_selected(0)
	_volume_liters_spin.value = 100.0
	_fluid_color_picker.color = Color(0.9, 0.2, 0.15, 0.8)
	_update_selected_fluid()
	await get_tree().physics_frame
	var failed := false
	if not is_equal_approx(_cup_width_meters, 4.2) or not is_equal_approx(_cup_height_meters, 3.2):
		push_error("Particle fluid lab smoke: cup dimensions were not applied")
		failed = true
	if _cup_wall_collisions.size() != 3:
		push_error("Particle fluid lab smoke: cup collision walls were not rebuilt")
		failed = true
	if _fluid_recipes.size() != 2 or _total_recipe_particles() != 45:
		push_error("Particle fluid lab smoke: volume-derived recipe counts are incorrect")
		failed = true
	if not is_equal_approx(_total_actual_volume_liters(), 180.0):
		push_error("Particle fluid lab smoke: accumulated liquid volume is incorrect")
		failed = true
	if _fluid.get_state_snapshot().count() != 45:
		push_error("Particle fluid lab smoke: solver particle count does not match volume recipes")
		failed = true
	for test_case: int in range(TEST_CASE_COUNT):
		_load_scenario(test_case)
		await get_tree().physics_frame
		var snapshot := _fluid.get_state_snapshot()
		var expected_recipe_count := 1 if test_case == Scenario.ICE or test_case == Scenario.HEAVY else 2
		if _fluid_recipes.size() != expected_recipe_count:
			push_error("Particle fluid lab smoke: case %d recipe count mismatch" % test_case)
			failed = true
		if snapshot.count() <= 0 or snapshot.count() > MAX_INTERACTIVE_PARTICLES:
			push_error("Particle fluid lab smoke: case %d violates particle budget with %d" % [test_case, snapshot.count()])
			failed = true
		var expected_material_ids: Dictionary = {}
		for recipe: ParticleFluidTestRecipe2D in _fluid_recipes:
			expected_material_ids[recipe.material_id] = true
		for material_id: int in snapshot.material_ids:
			if not expected_material_ids.has(material_id):
				push_error("Particle fluid lab smoke: case %d spawned unexpected material %d" % [test_case, material_id])
				failed = true
		if _objective_label.text.is_empty() or _criteria_label.text.is_empty():
			push_error("Particle fluid lab smoke: case %d lacks visible guidance" % test_case)
			failed = true
		print("LAB_CASE id=%d particles=%d recipes=%d materials=%d" % [
			test_case,
			snapshot.count(),
			_fluid_recipes.size(),
			expected_material_ids.size(),
		])
	_cup_width_meters = DEFAULT_CUP_WIDTH_METERS
	_cup_height_meters = DEFAULT_CUP_HEIGHT_METERS
	_rebuild_cup_geometry()
	_load_scenario(Scenario.MIXING)
	for _frame: int in range(90):
		await get_tree().physics_frame
	var water_baseline := _fluid.get_state_snapshot()
	var baseline_mean_speed := _snapshot_mean_speed(water_baseline)
	var baseline_maximum_speed := _snapshot_maximum_speed(water_baseline)
	if baseline_mean_speed > 0.02 or baseline_maximum_speed > 0.08:
		push_error("Particle fluid lab smoke: static water did not converge before dynamic response")
		failed = true
	_apply_fluid_impulse()
	var peak_mean_speed := 0.0
	var peak_relative_speed := 0.0
	var peak_pressure := 0.0
	var damping_disabled_during_impulse := false
	for _frame: int in range(120):
		await get_tree().physics_frame
		var response_snapshot := _fluid.get_state_snapshot()
		peak_mean_speed = maxf(peak_mean_speed, _snapshot_mean_speed(response_snapshot))
		peak_relative_speed = maxf(
			peak_relative_speed,
			_snapshot_relative_speed(response_snapshot)
		)
		peak_pressure = maxf(peak_pressure, _snapshot_maximum_pressure(response_snapshot))
		if not _fluid.is_quiescent_damping_active():
			damping_disabled_during_impulse = true
	var final_mean_speed := _snapshot_mean_speed(_fluid.get_state_snapshot())
	if peak_mean_speed < 0.8 or peak_relative_speed < 0.5:
		push_error("Particle fluid lab smoke: water preset moves as an over-damped rigid clump")
		failed = true
	if peak_pressure > 800000.0:
		push_error("Particle fluid lab smoke: water preset pressure response is too elastic")
		failed = true
	if not damping_disabled_during_impulse:
		push_error("Particle fluid lab smoke: active force did not wake quiescent damping")
		failed = true
	if final_mean_speed > 0.05:
		push_error("Particle fluid lab smoke: water did not return to rest after impulse")
		failed = true
	print("LAB_WATER_RESPONSE peak_mean=%.4f relative_speed=%.4f peak_pressure=%.2f final_mean=%.6f" % [
		peak_mean_speed,
		peak_relative_speed,
		peak_pressure,
		final_mean_speed,
	])
	var initial_render_mode := _fluid.render_mode
	_toggle_render_mode()
	if _fluid.render_mode == initial_render_mode:
		push_error("Particle fluid lab smoke: render mode did not toggle")
		failed = true
	_toggle_render_mode()
	set_auto_demo_enabled(true)
	if not _auto_demo_enabled:
		push_error("Particle fluid lab smoke: auto demo did not enable")
		failed = true
	set_auto_demo_enabled(false)
	get_tree().quit(1 if failed else 0)

func _snapshot_mean_velocity(snapshot: ParticleFluidSnapshot2D) -> Vector2:
	var total := Vector2.ZERO
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		total += velocity
	return total / float(maxi(snapshot.count(), 1))

func _snapshot_relative_speed(snapshot: ParticleFluidSnapshot2D) -> float:
	var mean_velocity := _snapshot_mean_velocity(snapshot)
	var total := 0.0
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		total += (velocity - mean_velocity).length()
	return total / float(maxi(snapshot.count(), 1))

func _snapshot_mean_speed(snapshot: ParticleFluidSnapshot2D) -> float:
	var total := 0.0
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		total += velocity.length()
	return total / float(maxi(snapshot.count(), 1))

func _snapshot_maximum_speed(snapshot: ParticleFluidSnapshot2D) -> float:
	var maximum := 0.0
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		maximum = maxf(maximum, velocity.length())
	return maximum

func _snapshot_maximum_pressure(snapshot: ParticleFluidSnapshot2D) -> float:
	var maximum := 0.0
	for pressure: float in snapshot.pressures:
		maximum = maxf(maximum, pressure)
	return maximum

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.035, 0.047, 0.067), true)
	draw_rect(Rect2(Vector2(425.0, 66.0), Vector2(690.0, 505.0)), Color(0.055, 0.075, 0.105), true)
	for x_position: int in range(450, 1116, 40):
		draw_line(
			Vector2(float(x_position), 76.0),
			Vector2(float(x_position), 561.0),
			Color(0.10, 0.14, 0.19),
			1.0
		)
	for y_position: int in range(90, 562, 40):
		draw_line(Vector2(440.0, float(y_position)), Vector2(1105.0, float(y_position)), Color(0.10, 0.14, 0.19), 1.0)
	if _container_adapter == null or _container_adapter.container_shape == null:
		return
	var shape := _container_adapter.container_shape
	for index: int in range(shape.segment_count()):
		var start_pixels := _cup.global_transform * (shape.segment_starts_local_meters[index] * PIXELS_PER_METER)
		var end_pixels := _cup.global_transform * (shape.segment_ends_local_meters[index] * PIXELS_PER_METER)
		draw_line(start_pixels, end_pixels, Color(0.66, 0.78, 0.92), 8.0, true)

func _build_container() -> void:
	_cup = AnimatableBody2D.new()
	_cup.name = "AcceptanceCup"
	_cup.position = CUP_HOME_PIXELS
	_cup.collision_layer = 1
	_cup.collision_mask = 2
	add_child(_cup)
	_container_adapter = ContainerMotionAdapter2D.new()
	_container_adapter.name = "ContainerMotionAdapter"
	_container_adapter.container_shape = ContainerShape2D.new()
	_cup.add_child(_container_adapter)
	_rebuild_cup_geometry()

func _rebuild_cup_geometry() -> void:
	for collision: CollisionShape2D in _cup_wall_collisions:
		if is_instance_valid(collision):
			collision.disabled = true
			collision.queue_free()
	_cup_wall_collisions.clear()
	_container_adapter.container_shape.configure_open_cup(_cup_width_meters, _cup_height_meters)
	var half_width_pixels := _cup_width_meters * PIXELS_PER_METER * 0.5
	var height_pixels := _cup_height_meters * PIXELS_PER_METER
	_add_cup_wall(Vector2(-half_width_pixels - WALL_THICKNESS_PIXELS * 0.5, height_pixels * 0.5), Vector2(WALL_THICKNESS_PIXELS, height_pixels))
	_add_cup_wall(Vector2(half_width_pixels + WALL_THICKNESS_PIXELS * 0.5, height_pixels * 0.5), Vector2(WALL_THICKNESS_PIXELS, height_pixels))
	_add_cup_wall(Vector2(0.0, height_pixels + WALL_THICKNESS_PIXELS * 0.5), Vector2(half_width_pixels * 2.0, WALL_THICKNESS_PIXELS))
	_container_adapter.reset_history()
	queue_redraw()

func _add_cup_wall(center_pixels: Vector2, size_pixels: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size_pixels
	collision.position = center_pixels
	collision.shape = rectangle
	_cup.add_child(collision)
	_cup_wall_collisions.append(collision)

func _cup_horizontal_travel_pixels() -> float:
	var free_half_width := 345.0 - _cup_width_meters * PIXELS_PER_METER * 0.5 - 12.0
	return clampf(free_half_width, 0.0, 130.0)

func _particle_capacity_for_size(width_meters: float, height_meters: float) -> int:
	var usable_width := maxf(0.0, width_meters - FLUID_MARGIN_METERS * 2.0)
	var usable_height := maxf(0.0, height_meters - FLUID_MARGIN_METERS * 2.0)
	var columns := maxi(1, floori(usable_width / PARTICLE_SPACING_METERS) + 1)
	var rows := maxi(1, floori(usable_height / PARTICLE_SPACING_METERS) + 1)
	return columns * rows

func _particle_volume_liters() -> float:
	return PARTICLE_SPACING_METERS * PARTICLE_SPACING_METERS * EFFECTIVE_DEPTH_METERS * 1000.0

func _particle_count_for_volume(volume_liters: float) -> int:
	return maxi(1, ceili(maxf(volume_liters, 0.0) / _particle_volume_liters()))

func _quantized_volume_liters(volume_liters: float) -> float:
	return float(_particle_count_for_volume(volume_liters)) * _particle_volume_liters()

func _volume_capacity_for_size(width_meters: float, height_meters: float) -> float:
	return float(_particle_capacity_for_size(width_meters, height_meters)) * _particle_volume_liters()

func _cup_geometric_volume_liters(width_meters: float, height_meters: float) -> float:
	return width_meters * height_meters * EFFECTIVE_DEPTH_METERS * 1000.0

func _particle_columns() -> int:
	var usable_width := maxf(0.0, _cup_width_meters - FLUID_MARGIN_METERS * 2.0)
	return maxi(1, floori(usable_width / PARTICLE_SPACING_METERS) + 1)

func _build_fluid() -> void:
	_fluid = ParticleFluid2D.new()
	_fluid.name = "ParticleFluid"
	var fluid_config := ParticleFluidConfig2D.new()
	fluid_config.pixels_per_meter = PIXELS_PER_METER
	fluid_config.effective_depth_meters = EFFECTIVE_DEPTH_METERS
	fluid_config.smoothing_radius_meters = PARTICLE_SPACING_METERS * SMOOTHING_RADIUS_RATIO
	fluid_config.particle_mass = 1000.0 * fluid_config.effective_depth_meters * PARTICLE_SPACING_METERS * PARTICLE_SPACING_METERS
	fluid_config.speed_of_sound = WATER_NUMERICAL_SOUND_SPEED
	fluid_config.gas_stiffness = (
		fluid_config.rest_density
		* fluid_config.speed_of_sound
		* fluid_config.speed_of_sound
	)
	# 低精度粗粒子使用少量数值黏性维持稳定，但普通酒液应保留水一样的层间滑动。
	fluid_config.dynamic_viscosity = WATER_BASE_VISCOSITY
	fluid_config.boundary_restitution = WATER_BOUNDARY_RESTITUTION
	fluid_config.boundary_friction = WATER_BOUNDARY_FRICTION
	fluid_config.quiescent_damping_per_second = WATER_QUIESCENT_DAMPING_PER_SECOND
	fluid_config.quiescent_activation_delay_seconds = WATER_QUIESCENT_ACTIVATION_DELAY_SECONDS
	fluid_config.quiescent_stop_speed = WATER_QUIESCENT_STOP_SPEED
	fluid_config.color_diffusion = 0.9
	fluid_config.optical_path_length = 1.0
	fluid_config.max_substeps = 8
	fluid_config.density_error_warning_ratio = 0.75
	fluid_config.enable_step_profiling = true
	_fluid.config = fluid_config
	_fluid.optical_field_resolution = Vector2i(128, 192)
	add_child(_fluid)
	_fluid.set_container_adapter(_container_adapter)
	_fluid.step_completed.connect(_on_step_completed)

func _build_body() -> void:
	_floating_body = BuoyantBodyAdapter2D.new()
	_floating_body.name = "BuoyancyTestBody"
	_floating_body.collision_layer = 2
	_floating_body.collision_mask = 1
	_floating_body.effective_depth_meters = 0.1
	_floating_body.drag_coefficient = 2.2
	_floating_body.maximum_fluid_force = 1400.0
	var fluid_shape := BuoyantBodyShape2D.new()
	fluid_shape.shape_type = BuoyantBodyShape2D.ShapeType.RECTANGLE
	fluid_shape.size_meters = Vector2(0.5, 0.3)
	fluid_shape.sample_spacing_meters = 0.06
	_floating_body.fluid_shape = fluid_shape
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = fluid_shape.size_meters * PIXELS_PER_METER
	collision.shape = rectangle
	_floating_body.add_child(collision)
	_body_visual = Polygon2D.new()
	var half_size := rectangle.size * 0.5
	_body_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	_floating_body.add_child(_body_visual)
	add_child(_floating_body)

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AcceptanceInterface"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(395.0, 610.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.09, 0.12, 0.97)
	panel_style.border_color = Color(0.18, 0.24, 0.32)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var title := Label.new()
	title.text = "2D SPH 粒子流体验收实验室"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.83, 0.93, 1.0))
	content.add_child(title)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(350.0, 535.0)
	content.add_child(tabs)
	_build_acceptance_page(_make_scroll_page(tabs, "验收"))
	_build_configuration_page(_make_scroll_page(tabs, "构造"))

func _make_scroll_page(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.custom_minimum_size.x = 340.0
	page.add_theme_constant_override("separation", 8)
	scroll.add_child(page)
	return page

func _build_acceptance_page(content: VBoxContainer) -> void:
	_scenario_label = Label.new()
	_scenario_label.add_theme_font_size_override("font_size", 17)
	content.add_child(_scenario_label)
	_objective_label = Label.new()
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size.y = 68.0
	_objective_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9))
	content.add_child(_objective_label)
	_criteria_label = Label.new()
	_criteria_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_criteria_label.custom_minimum_size.y = 92.0
	_criteria_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.72))
	content.add_child(_criteria_label)
	var scenario_grid := GridContainer.new()
	scenario_grid.columns = 2
	content.add_child(scenario_grid)
	_add_button(scenario_grid, "1  透明混色", func() -> void: _load_scenario(Scenario.MIXING))
	_add_button(scenario_grid, "2  黏度对比", func() -> void: _load_scenario(Scenario.VISCOSITY))
	_add_button(scenario_grid, "3  密度分层", func() -> void: _load_scenario(Scenario.DENSITY))
	_add_button(scenario_grid, "4  胶体浑浊", func() -> void: _load_scenario(Scenario.COLLOID))
	_add_button(scenario_grid, "5  冰块浮起", func() -> void: _load_scenario(Scenario.ICE))
	_add_button(scenario_grid, "6  重物下沉", func() -> void: _load_scenario(Scenario.HEAVY))
	_add_button(scenario_grid, "R  重置当前", _reset_runtime_from_recipes)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	content.add_child(action_grid)
	_add_button(action_grid, "A  向左晃", func() -> void: _apply_cup_impulse(-220.0))
	_add_button(action_grid, "D  向右晃", func() -> void: _apply_cup_impulse(220.0))
	_add_button(action_grid, "Q  左倾杯子", func() -> void: _apply_cup_angular_impulse(-0.9))
	_add_button(action_grid, "E  右倾杯子", func() -> void: _apply_cup_angular_impulse(0.9))
	_add_button(action_grid, "Space  液体上冲", _apply_fluid_impulse)
	_add_button(action_grid, "P  暂停/继续", func() -> void:
		_fluid.simulate = not _fluid.simulate
		_update_scenario_label()
	)
	_add_button(action_grid, "B  自动演示", _toggle_auto_demo)
	_add_button(action_grid, "M  切换渲染", _toggle_render_mode)
	var separator := HSeparator.new()
	content.add_child(separator)
	var operation := Label.new()
	operation.text = "操作：1–6 选择用例；A/D 晃杯，Q/E 倾斜，Space 上冲；B 自动演示，M 切换光学场/直接粒子，V 隐藏渲染，P 暂停。"
	operation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	operation.custom_minimum_size.y = 76.0
	content.add_child(operation)
	_metrics_label = Label.new()
	_metrics_label.text = "等待首个物理步……"
	_metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics_label.custom_minimum_size.y = 72.0
	content.add_child(_metrics_label)
	_health_label = Label.new()
	_health_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_health_label)
	var hint := Label.new()
	hint.text = "绿色表示数值健康；黄色是软诊断；红色或粒子数超过 136 才算自动失败。每个用例的具体步骤与通过条件显示在上方。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.70, 0.78, 0.88))
	content.add_child(hint)

func _build_configuration_page(content: VBoxContainer) -> void:
	var cup_heading := Label.new()
	cup_heading.text = "杯子尺寸（米）"
	cup_heading.add_theme_font_size_override("font_size", 17)
	content.add_child(cup_heading)
	var cup_grid := GridContainer.new()
	cup_grid.columns = 2
	content.add_child(cup_grid)
	_cup_width_spin = _make_labeled_spin(cup_grid, "宽度", MIN_CUP_WIDTH_METERS, MAX_CUP_WIDTH_METERS, 0.1, _cup_width_meters, " m")
	_cup_height_spin = _make_labeled_spin(cup_grid, "高度", MIN_CUP_HEIGHT_METERS, MAX_CUP_HEIGHT_METERS, 0.1, _cup_height_meters, " m")
	_add_button(content, "应用杯子尺寸并重置", _apply_cup_dimensions)
	_capacity_label = Label.new()
	_capacity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.82, 0.94))
	content.add_child(_capacity_label)
	content.add_child(HSeparator.new())
	var fluid_heading := Label.new()
	fluid_heading.text = "添加或编辑粒子液体"
	fluid_heading.add_theme_font_size_override("font_size", 17)
	content.add_child(fluid_heading)
	var fluid_grid := GridContainer.new()
	fluid_grid.columns = 2
	content.add_child(fluid_grid)
	var selector_label := Label.new()
	selector_label.text = "选择已有液体"
	fluid_grid.add_child(selector_label)
	_recipe_selector = OptionButton.new()
	_recipe_selector.custom_minimum_size = Vector2(185.0, 34.0)
	_recipe_selector.item_selected.connect(_on_recipe_selected)
	fluid_grid.add_child(_recipe_selector)
	var color_label := Label.new()
	color_label.text = "颜色"
	fluid_grid.add_child(color_label)
	_fluid_color_picker = ColorPickerButton.new()
	_fluid_color_picker.color = Color(0.2, 0.85, 0.35, 0.78)
	_fluid_color_picker.edit_alpha = true
	_fluid_color_picker.custom_minimum_size = Vector2(185.0, 34.0)
	fluid_grid.add_child(_fluid_color_picker)
	_volume_liters_spin = _make_labeled_spin(fluid_grid, "添加体积", 1.0, 2500.0, 1.0, DEFAULT_LIQUID_VOLUME_LITERS, " L")
	_volume_liters_spin.value_changed.connect(_on_volume_input_changed)
	_concentration_spin = _make_labeled_spin(fluid_grid, "颜色浓度", 0.05, 3.0, 0.05, 1.0, "")
	_turbidity_spin = _make_labeled_spin(fluid_grid, "浑浊度", 0.0, 2.0, 0.05, 0.75, "")
	_derived_particle_count_label = Label.new()
	_derived_particle_count_label.add_theme_color_override("font_color", Color(0.7, 0.82, 0.94))
	content.add_child(_derived_particle_count_label)
	_on_volume_input_changed(_volume_liters_spin.value)
	var write_actions := HBoxContainer.new()
	content.add_child(write_actions)
	_add_button(write_actions, "添加为新液体", _add_custom_fluid)
	_add_button(write_actions, "更新选中液体", _update_selected_fluid)
	var recipe_actions := HBoxContainer.new()
	content.add_child(recipe_actions)
	_add_button(recipe_actions, "删除选中液体", _remove_selected_fluid)
	_add_button(recipe_actions, "清空全部液体", _clear_custom_fluids)
	_recipe_list_label = Label.new()
	_recipe_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_list_label.custom_minimum_size.y = 115.0
	content.add_child(_recipe_list_label)
	_config_feedback_label = Label.new()
	_config_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_config_feedback_label)
	var hint := Label.new()
	hint.text = "说明：每个粗粒子约代表 4 L。连续添加会累加总体积并提高液面；液体按加入顺序分层，晃动后按吸光度模型混合。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	content.add_child(hint)
	_update_recipe_summary()

func _on_volume_input_changed(requested_liters: float) -> void:
	if _derived_particle_count_label == null:
		return
	var particle_count := _particle_count_for_volume(requested_liters)
	var actual_liters := float(particle_count) * _particle_volume_liters()
	_derived_particle_count_label.text = "量化结果：%d 个粗粒子 × %.1f L = %.1f L 实际体积" % [
		particle_count,
		_particle_volume_liters(),
		actual_liters,
	]


func _make_labeled_spin(
	parent: GridContainer,
	label_text: String,
	minimum: float,
	maximum: float,
	step: float,
	initial_value: float,
	suffix_text: String
) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial_value
	spin.suffix = suffix_text
	spin.custom_minimum_size = Vector2(185.0, 34.0)
	parent.add_child(spin)
	return spin

func _add_button(parent: Control, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(166.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)

func _load_scenario(new_scenario: int) -> void:
	_scenario = new_scenario
	var capacity_liters := _volume_capacity_for_size(_cup_width_meters, _cup_height_meters)
	if _scenario != Scenario.CUSTOM:
		_fluid_recipes.clear()
	match _scenario:
		Scenario.MIXING:
			var per_color_liters := minf(DEFAULT_LIQUID_VOLUME_LITERS, capacity_liters * 0.5)
			var red := _make_recipe("红色基酒", per_color_liters, Color(0.96, 0.22, 0.12, 0.66), 1.0, 0.35)
			_set_recipe_material(red, 1, 0.98, 0.85, 1.0, 0, 1.25, 0.9, 0.55, 0.45)
			var blue := _make_recipe("蓝色基酒", per_color_liters, Color(0.12, 0.36, 0.98, 0.66), 1.0, 0.35)
			_set_recipe_material(blue, 2, 1.03, 1.15, 1.0, 0, 0.85, 0.9, 0.25, 0.20)
			_fluid_recipes.assign([red, blue])
		Scenario.VISCOSITY:
			var thin := _make_recipe("低黏基酒", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.98, 0.64, 0.12, 0.70), 1.0, 0.25)
			_set_recipe_material(thin, 10, 1.0, 0.35, 0.0, 1, 1.0, 0.8, 0.40, 0.35)
			var syrup := _make_recipe("高黏糖浆", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.62, 0.18, 0.88, 0.76), 1.0, 0.55)
			_set_recipe_material(syrup, 11, 1.0, 4.0, 0.0, 2, 1.2, 1.2, 0.30, 0.55)
			_fluid_recipes.assign([thin, syrup])
		Scenario.DENSITY:
			var light := _make_recipe("低密度液体", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.98, 0.78, 0.22, 0.66), 1.0, 0.25)
			_set_recipe_material(light, 20, 0.88, 1.0, 0.0, 3, 0.9, 0.8, 0.28, 0.30)
			var dense := _make_recipe("高密度液体", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.10, 0.72, 0.92, 0.72), 1.0, 0.35)
			_set_recipe_material(dense, 21, 1.12, 1.0, 0.0, 4, 1.0, 1.0, 0.38, 0.35)
			_fluid_recipes.assign([light, dense])
		Scenario.COLLOID:
			var clear_spirit := _make_recipe("清澈基酒", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.45, 0.86, 1.0, 0.45), 0.65, 0.12)
			_set_recipe_material(clear_spirit, 30, 0.98, 0.70, 0.35, 0, 0.65, 0.45, 0.65, 0.50)
			var colloid := _make_recipe("浑浊胶体", DEFAULT_LIQUID_VOLUME_LITERS, Color(0.98, 0.42, 0.58, 0.82), 1.15, 1.20)
			_set_recipe_material(colloid, 31, 1.04, 3.0, 0.35, 0, 1.35, 1.65, 0.12, 0.18)
			_fluid_recipes.assign([clear_spirit, colloid])
		Scenario.ICE, Scenario.HEAVY:
			var water := _make_recipe(
				"基础蓝色液体",
				minf(DEFAULT_LIQUID_VOLUME_LITERS * 2.0, capacity_liters),
				Color(0.14, 0.62, 0.96, 0.62),
				1.0,
				0.30
			)
			_set_recipe_material(water, 40, 1.0, 1.0, 1.0, 0, 0.85, 0.8, 0.40, 0.35)
			_fluid_recipes.append(water)
		Scenario.CUSTOM:
			pass
	_reset_runtime_from_recipes()

func _make_recipe(
	display_name: String,
	requested_volume_liters: float,
	color_srgb: Color,
	concentration: float,
	turbidity: float
) -> ParticleFluidTestRecipe2D:
	var recipe := ParticleFluidTestRecipe2D.new()
	recipe.display_name = display_name
	recipe.requested_volume_liters = requested_volume_liters
	recipe.particle_count = _particle_count_for_volume(requested_volume_liters)
	recipe.actual_volume_liters = float(recipe.particle_count) * _particle_volume_liters()
	recipe.color_srgb = color_srgb
	recipe.concentration = concentration
	recipe.turbidity = turbidity
	return recipe

func _set_recipe_material(
	recipe: ParticleFluidTestRecipe2D,
	material_id: int,
	density_multiplier: float,
	viscosity_multiplier: float,
	color_diffusion_multiplier: float,
	mixing_group: int,
	dye_strength: float,
	turbidity_multiplier: float,
	refractive_strength: float,
	specular_strength: float
) -> void:
	recipe.material_id = material_id
	recipe.density_multiplier = density_multiplier
	recipe.viscosity_multiplier = viscosity_multiplier
	recipe.color_diffusion_multiplier = color_diffusion_multiplier
	recipe.mixing_group = mixing_group
	recipe.dye_strength = dye_strength
	recipe.turbidity_multiplier = turbidity_multiplier
	recipe.refractive_strength = refractive_strength
	recipe.specular_strength = specular_strength

func _configure_recipe_materials() -> bool:
	var material_table: Array[FluidMaterial2D] = []
	var registered_ids: Dictionary = {}
	for recipe: ParticleFluidTestRecipe2D in _fluid_recipes:
		if registered_ids.has(recipe.material_id):
			continue
		var material := FluidMaterial2D.new()
		material.material_id = recipe.material_id
		material.density_multiplier = recipe.density_multiplier
		material.viscosity_multiplier = recipe.viscosity_multiplier
		material.color_diffusion_multiplier = recipe.color_diffusion_multiplier
		material.mixing_group = recipe.mixing_group
		material.dye_strength = recipe.dye_strength
		material.turbidity_multiplier = recipe.turbidity_multiplier
		material.refractive_strength = recipe.refractive_strength
		material.specular_strength = recipe.specular_strength
		material_table.append(material)
		registered_ids[recipe.material_id] = true
	var errors := _fluid.set_materials(material_table)
	if not errors.is_empty():
		push_error("流体测试材质配置失败：%s" % "；".join(errors))
		return false
	return true

func _reset_runtime_from_recipes() -> void:
	var total_particles := _total_recipe_particles()
	var capacity := _particle_capacity_for_size(_cup_width_meters, _cup_height_meters)
	if total_particles > capacity:
		_set_config_feedback(
			"重建失败：当前配方需要 %d 个粒子（%.1f L），杯子模拟容量为 %d 个（%.1f L）。" % [
				total_particles,
				_total_actual_volume_liters(),
				capacity,
				_volume_capacity_for_size(_cup_width_meters, _cup_height_meters),
			],
			false
		)
		return
	_fluid.simulate = false
	_fluid.reset(_scenario)
	_fluid.set_external_acceleration(Vector2(0.0, 9.81))
	var empty_fields: Array[FluidForceField2D] = []
	_fluid.set_force_fields(empty_fields)
	if not _configure_recipe_materials():
		_fluid.simulate = false
		_set_config_feedback("材质配置失败，请查看编辑器输出。", false)
		return
	_cup.position = CUP_HOME_PIXELS
	_cup.rotation = 0.0
	_cup_velocity_pixels_per_second = Vector2.ZERO
	_cup_angular_velocity_radians_per_second = 0.0
	_container_adapter.reset_history()
	var uses_body := _scenario == Scenario.ICE or _scenario == Scenario.HEAVY
	_configure_body(uses_body, ICE_MASS_KILOGRAMS if _scenario == Scenario.ICE else HEAVY_MASS_KILOGRAMS)
	_spawn_recipe_particles()
	_fluid.simulate = true
	_update_scenario_label()
	_update_recipe_summary()
	queue_redraw()

func _spawn_recipe_particles() -> void:
	var columns := _particle_columns()
	var global_index := 0
	var cup_origin_meters := CUP_HOME_PIXELS / PIXELS_PER_METER
	for recipe: ParticleFluidTestRecipe2D in _fluid_recipes:
		var batch := ParticleSpawnBatch2D.new()
		for _particle_index: int in range(recipe.particle_count):
			var column := global_index % columns
			var row_from_bottom := global_index / columns
			var local_position := Vector2(
				-_cup_width_meters * 0.5 + FLUID_MARGIN_METERS + float(column) * PARTICLE_SPACING_METERS,
				_cup_height_meters - FLUID_MARGIN_METERS - float(row_from_bottom) * PARTICLE_SPACING_METERS
			)
			batch.positions_meters.append(cup_origin_meters + local_position)
			batch.colors_srgb.append(recipe.color_srgb)
			batch.concentrations.append(recipe.concentration)
			batch.turbidities.append(recipe.turbidity)
			batch.material_ids.append(recipe.material_id)
			global_index += 1
		_fluid.add_particles(batch)

func _total_recipe_particles() -> int:
	var total := 0
	for recipe: ParticleFluidTestRecipe2D in _fluid_recipes:
		total += recipe.particle_count
	return total

func _total_actual_volume_liters() -> float:
	var total := 0.0
	for recipe: ParticleFluidTestRecipe2D in _fluid_recipes:
		total += recipe.actual_volume_liters
	return total

func _apply_cup_dimensions() -> void:
	var proposed_width := float(_cup_width_spin.value)
	var proposed_height := float(_cup_height_spin.value)
	var proposed_capacity := _particle_capacity_for_size(proposed_width, proposed_height)
	var total_particles := _total_recipe_particles()
	if total_particles > proposed_capacity:
		_set_config_feedback(
			"尺寸未应用：现有 %.1f L（%d 个粒子）超过新杯子的模拟容量 %.1f L（%d 个粒子）。" % [
				_total_actual_volume_liters(),
				total_particles,
				_volume_capacity_for_size(proposed_width, proposed_height),
				proposed_capacity,
			],
			false
		)
		return
	_cup_width_meters = proposed_width
	_cup_height_meters = proposed_height
	_rebuild_cup_geometry()
	_reset_runtime_from_recipes()
	_set_config_feedback("杯子已调整为 %.1f m × %.1f m，并按 %.1f L 总液体体积重建。" % [
		_cup_width_meters,
		_cup_height_meters,
		_total_actual_volume_liters(),
	], true)

func _add_custom_fluid() -> void:
	var requested_liters := float(_volume_liters_spin.value)
	var recipe_number := _fluid_recipes.size() + 1
	var recipe := _make_recipe(
		"自定义液体 %d" % recipe_number,
		requested_liters,
		_fluid_color_picker.color,
		float(_concentration_spin.value),
		float(_turbidity_spin.value)
	)
	var capacity := _particle_capacity_for_size(_cup_width_meters, _cup_height_meters)
	var proposed_total := _total_recipe_particles() + recipe.particle_count
	if proposed_total > capacity:
		_set_config_feedback(
			"添加失败：加入后为 %.1f L（%d 个粒子），当前杯子模拟容量为 %.1f L（%d 个粒子）。" % [
				_total_actual_volume_liters() + recipe.actual_volume_liters,
				proposed_total,
				_volume_capacity_for_size(_cup_width_meters, _cup_height_meters),
				capacity,
			],
			false
		)
		return
	_fluid_recipes.append(recipe)
	_scenario = Scenario.CUSTOM
	_reset_runtime_from_recipes()
	_recipe_selector.select(_fluid_recipes.size() - 1)
	_on_recipe_selected(_fluid_recipes.size() - 1)
	_set_config_feedback("已添加 %s：请求 %.1f L，实际 %.1f L（%d 个粗粒子）。" % [
		recipe.display_name,
		recipe.requested_volume_liters,
		recipe.actual_volume_liters,
		recipe.particle_count,
	], true)

func _update_selected_fluid() -> void:
	if _fluid_recipes.is_empty() or _recipe_selector.selected < 0:
		_set_config_feedback("请先添加或选择一种液体。", false)
		return
	var selected_index := _recipe_selector.selected
	var recipe := _fluid_recipes[selected_index]
	var requested_liters := float(_volume_liters_spin.value)
	var requested_count := _particle_count_for_volume(requested_liters)
	var proposed_total := _total_recipe_particles() - recipe.particle_count + requested_count
	var capacity := _particle_capacity_for_size(_cup_width_meters, _cup_height_meters)
	if proposed_total > capacity:
		_set_config_feedback(
			"更新失败：修改后为 %.1f L（%d 个粒子），当前杯子最多模拟 %.1f L（%d 个粒子）。" % [
				_total_actual_volume_liters() - recipe.actual_volume_liters + _quantized_volume_liters(requested_liters),
				proposed_total,
				_volume_capacity_for_size(_cup_width_meters, _cup_height_meters),
				capacity,
			],
			false
		)
		return
	recipe.requested_volume_liters = requested_liters
	recipe.particle_count = requested_count
	recipe.actual_volume_liters = float(requested_count) * _particle_volume_liters()
	recipe.color_srgb = _fluid_color_picker.color
	recipe.concentration = float(_concentration_spin.value)
	recipe.turbidity = float(_turbidity_spin.value)
	_scenario = Scenario.CUSTOM
	_reset_runtime_from_recipes()
	_recipe_selector.select(selected_index)
	_on_recipe_selected(selected_index)
	_set_config_feedback("已更新 %s：实际体积 %.1f L（%d 个粗粒子）。" % [
		recipe.display_name,
		recipe.actual_volume_liters,
		recipe.particle_count,
	], true)

func _remove_selected_fluid() -> void:
	if _fluid_recipes.is_empty() or _recipe_selector.selected < 0:
		_set_config_feedback("没有可删除的液体。", false)
		return
	var selected_index := _recipe_selector.selected
	var removed := _fluid_recipes[selected_index]
	_fluid_recipes.remove_at(selected_index)
	_scenario = Scenario.CUSTOM
	_reset_runtime_from_recipes()
	_set_config_feedback("已删除 %s（%.1f L）。" % [removed.display_name, removed.actual_volume_liters], true)

func _clear_custom_fluids() -> void:
	_fluid_recipes.clear()
	_scenario = Scenario.CUSTOM
	_reset_runtime_from_recipes()
	_set_config_feedback("已清空全部液体，杯中总体积为 0 L。", true)

func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= _fluid_recipes.size():
		return
	var recipe := _fluid_recipes[index]
	_fluid_color_picker.color = recipe.color_srgb
	_volume_liters_spin.value = recipe.requested_volume_liters
	_concentration_spin.value = recipe.concentration
	_turbidity_spin.value = recipe.turbidity
	_on_volume_input_changed(recipe.requested_volume_liters)

func _update_recipe_summary() -> void:
	if _recipe_list_label == null or _capacity_label == null or _recipe_selector == null:
		return
	var capacity := _particle_capacity_for_size(_cup_width_meters, _cup_height_meters)
	_capacity_label.text = "液体 %.1f / %.1f L｜%d / %d 粗粒子｜杯子几何体积 %.1f L" % [
		_total_actual_volume_liters(),
		_volume_capacity_for_size(_cup_width_meters, _cup_height_meters),
		_total_recipe_particles(),
		capacity,
		_cup_geometric_volume_liters(_cup_width_meters, _cup_height_meters),
	]
	var previous_selection := _recipe_selector.selected
	_recipe_selector.clear()
	if _fluid_recipes.is_empty():
		_recipe_selector.disabled = true
		_recipe_list_label.text = "液体列表：空｜总体积 0 L"
		return
	_recipe_selector.disabled = false
	var lines := PackedStringArray(["当前液体（总体积 %.1f L）：" % _total_actual_volume_liters()])
	for index: int in range(_fluid_recipes.size()):
		var recipe := _fluid_recipes[index]
		_recipe_selector.add_item("%d. %s" % [index + 1, recipe.display_name])
		lines.append(
			"%d. %s｜%.1f L｜%d 粒子｜材质 %d｜密度 ×%.2f｜黏度 ×%.2f｜浑浊 %.2f" % [
				index + 1,
				recipe.display_name,
				recipe.actual_volume_liters,
				recipe.particle_count,
				recipe.material_id,
				recipe.density_multiplier,
				recipe.viscosity_multiplier,
				recipe.turbidity,
			]
		)
	var selected_index := clampi(previous_selection, 0, _fluid_recipes.size() - 1)
	_recipe_selector.select(selected_index)
	_on_recipe_selected(selected_index)
	_recipe_list_label.text = "\n".join(lines)

func _set_config_feedback(message: String, success: bool) -> void:
	if _config_feedback_label == null:
		return
	_config_feedback_label.text = message
	_config_feedback_label.add_theme_color_override(
		"font_color",
		Color(0.45, 0.92, 0.6) if success else Color(1.0, 0.45, 0.32)
	)

func _configure_body(enabled: bool, mass_kilograms: float) -> void:
	_floating_body.freeze = true
	_floating_body.visible = enabled
	_floating_body.collision_layer = 2 if enabled else 0
	_floating_body.collision_mask = 1 if enabled else 0
	_floating_body.position = CUP_HOME_PIXELS + Vector2(0.0, 125.0)
	_floating_body.rotation = 0.0
	_floating_body.linear_velocity = Vector2.ZERO
	_floating_body.angular_velocity = 0.0
	_floating_body.mass = mass_kilograms
	_body_visual.color = Color(0.78, 0.94, 1.0) if mass_kilograms == ICE_MASS_KILOGRAMS else Color(0.92, 0.61, 0.19)
	_floating_body.refresh_fluid_snapshot()
	var adapters: Array[BuoyantBodyAdapter2D] = []
	if enabled:
		adapters.append(_floating_body)
	_fluid.set_buoyant_adapters(adapters)
	_floating_body.freeze = not enabled
	if enabled:
		_floating_body.sleeping = false

func _apply_cup_impulse(value_pixels_per_second: float) -> void:
	_fluid.wake()
	_cup_velocity_pixels_per_second.x += value_pixels_per_second

func _apply_cup_angular_impulse(value_radians_per_second: float) -> void:
	_fluid.wake()
	_cup_angular_velocity_radians_per_second += value_radians_per_second

func _apply_fluid_impulse() -> void:
	var field := FluidForceField2D.new()
	field.field_id = &"acceptance_upward_impulse"
	field.acceleration = Vector2(0.0, -16.0)
	field.remaining_seconds = 0.2
	var fields: Array[FluidForceField2D] = [field]
	_fluid.set_force_fields(fields)

func set_auto_demo_enabled(enabled: bool) -> void:
	_auto_demo_enabled = enabled
	_auto_demo_elapsed_seconds = 0.0
	_auto_demo_direction = 1.0
	_update_scenario_label()

func _toggle_auto_demo() -> void:
	set_auto_demo_enabled(not _auto_demo_enabled)

func _toggle_render_mode() -> void:
	var next_mode := ParticleFluid2D.RenderMode.DIRECT_PARTICLES
	if _fluid.render_mode == ParticleFluid2D.RenderMode.DIRECT_PARTICLES:
		next_mode = ParticleFluid2D.RenderMode.OPTICAL_FIELD
	_fluid.set_render_mode(next_mode)
	_update_scenario_label()

func _update_scenario_label() -> void:
	var scenario_name := "透明 Beer-Lambert 减色混合"
	match _scenario:
		Scenario.VISCOSITY:
			scenario_name = "低黏基酒与高黏糖浆对比"
		Scenario.DENSITY:
			scenario_name = "低密度与高密度液体重排"
		Scenario.COLLOID:
			scenario_name = "清澈液体与浑浊胶体对比"
		Scenario.ICE:
			scenario_name = "低密度规则冰块浮力"
		Scenario.HEAVY:
			scenario_name = "高密度规则重物下沉"
		Scenario.CUSTOM:
			scenario_name = "自定义杯子与多液体配方"
	var render_name := "光学场" if _fluid.render_mode == ParticleFluid2D.RenderMode.OPTICAL_FIELD else "直接粒子"
	_scenario_label.text = "当前：%s｜%s%s%s" % [
		scenario_name,
		render_name,
		"｜自动演示" if _auto_demo_enabled else "",
		"｜已暂停" if not _fluid.simulate else "",
	]
	match _scenario:
		Scenario.MIXING:
			_objective_label.text = "步骤：先静置 2 秒，再交替按 A/D 三轮；最后按 M 对比两种渲染。"
			_criteria_label.text = "通过：红蓝接触区逐渐形成更深的减色结果；厚处更深、薄处更透明；切换渲染不改变运动。"
		Scenario.VISCOSITY:
			_objective_label.text = "步骤：按 Space 后观察橙色低黏基酒与紫色高黏糖浆，再交替按 A/D。"
			_criteria_label.text = "通过：橙色液体响应更快、回荡更明显；紫色糖浆形变与回流更慢；两侧都保持稳定且不穿墙。"
		Scenario.DENSITY:
			_objective_label.text = "步骤：高密度蓝液初始位于低密度黄液上方；按 B 自动晃动或手动 A/D，观察 15–30 秒。"
			_criteria_label.text = "通过：蓝色高密度液体具有下沉趋势，黄色低密度液体具有上移趋势；允许粗粒子界面模糊，但不能速度爆炸。"
		Scenario.COLLOID:
			_objective_label.text = "步骤：先比较透明度，再按 Space 和 A/D，观察清澈蓝液与粉色胶体的流动和光学差异。"
			_criteria_label.text = "通过：蓝液更透明、更灵活；粉色胶体更浑浊、更迟缓；重叠区域按厚度加深且没有黑色矩形或残影。"
		Scenario.ICE:
			_objective_label.text = "步骤：等待冰块落入液体并回升；稳定后按 A/D 晃杯。"
			_criteria_label.text = "通过：7 kg 冰块最终部分浸没并浮起，浸没率连续变化；冰块和液体都没有瞬移。"
		Scenario.HEAVY:
			_objective_label.text = "步骤：等待重物穿过液面并到达杯底；随后按 A/D 检查接触稳定性。"
			_criteria_label.text = "通过：24 kg 重物不能被浮力托住，最终由杯底承托；不得悬空、弹飞或穿透杯底。"
		Scenario.CUSTOM:
			_objective_label.text = "在“构造”页调整杯子尺寸，并按升设置每种液体的体积、颜色、浓度和浑浊度；粒子数由体积自动量化。"
			_criteria_label.text = "通过：配方体积、量化粒子数和液位同步变化；容量不足时拒绝修改而不丢失现有液体。"


func _on_step_completed(result: FluidStepResult2D) -> void:
	var submersion_text := ""
	if _floating_body.visible:
		var ratio := float(result.body_submersion_ratios.get(_floating_body.body_id, 0.0))
		submersion_text = " | 浸没 %.0f%%" % (ratio * 100.0)
	var quiescent_text := " | 已静稳" if result.quiescent_damping_active else ""
	var physics_milliseconds := float(
		result.profile_spatial_hash_microseconds
		+ result.profile_density_microseconds
		+ result.profile_forces_microseconds
		+ result.profile_integration_microseconds
	) / 1000.0
	_metrics_label.text = "FPS %d | 物理 %.2f ms | 粒子 %d | 子步 %d/%d\n密度误差 %.1f%% | 最大速度 %.2f m/s | 邻居 %.1f%s%s" % [
		Engine.get_frames_per_second(),
		physics_milliseconds,
		result.particle_count,
		result.substeps,
		_fluid.config.max_substeps,
		result.average_density_error_ratio * 100.0,
		result.maximum_speed,
		result.average_neighbor_count,
		submersion_text,
		quiescent_text,
	]
	if result.has_non_finite_state:
		_health_label.text = "❌ 数值状态出现非有限值，请停止并记录复现步骤。"
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	elif _scenario != Scenario.CUSTOM and result.particle_count > MAX_INTERACTIVE_PARTICLES:
		_health_label.text = "❌ 内置用例超过 %d 粒子交互预算。" % MAX_INTERACTIVE_PARTICLES
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	elif not result.warnings.is_empty():
		_health_label.text = "⚠ 有限值正常；诊断告警：%s" % "；".join(result.warnings)
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.3))
	else:
		_health_label.text = (
			"✓ 液体已收敛到静稳状态"
			if result.quiescent_damping_active
			else "✓ 数值有限，当前物理步无稳定性告警"
		)
		_health_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.6))
