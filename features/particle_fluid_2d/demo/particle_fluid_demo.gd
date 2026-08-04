extends Node2D
class_name ParticleFluidDemo

var _fluid: ParticleFluid2D
var _container_root: Node2D
var _container_adapter: ContainerMotionAdapter2D
var _floating_body: BuoyantBodyAdapter2D
var _status_label: Label
var _cup_velocity_pixels_per_second: Vector2 = Vector2.ZERO
var _cup_angular_velocity_radians_per_second: float = 0.0

func _ready() -> void:
	_build_container()
	_build_fluid()
	_build_body()
	_build_controls()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_container_root.position += _cup_velocity_pixels_per_second * delta
	_container_root.position.x = clampf(_container_root.position.x, 360.0, 600.0)
	_container_root.rotation += _cup_angular_velocity_radians_per_second * delta
	_cup_velocity_pixels_per_second *= exp(-3.5 * delta)
	_cup_angular_velocity_radians_per_second *= exp(-4.0 * delta)
	queue_redraw()

func _draw() -> void:
	if _container_adapter == null or _container_adapter.container_shape == null:
		return
	var shape := _container_adapter.container_shape
	for index: int in range(shape.segment_count()):
		var start := _container_root.global_transform * (shape.segment_starts_local_meters[index] * _fluid.config.pixels_per_meter)
		var end := _container_root.global_transform * (shape.segment_ends_local_meters[index] * _fluid.config.pixels_per_meter)
		draw_line(to_local(start), to_local(end), Color(0.75, 0.82, 0.9), 7.0, true)

func _build_container() -> void:
	_container_root = Node2D.new()
	_container_root.name = "Cup"
	_container_root.position = Vector2(480.0, 120.0)
	add_child(_container_root)
	_container_adapter = ContainerMotionAdapter2D.new()
	_container_adapter.name = "ContainerMotionAdapter"
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(6.0, 4.0)
	_container_adapter.container_shape = shape
	_container_root.add_child(_container_adapter)

func _build_fluid() -> void:
	_fluid = ParticleFluid2D.new()
	_fluid.name = "ParticleFluid"
	var fluid_config := ParticleFluidConfig2D.new()
	fluid_config.smoothing_radius_meters = 0.19
	fluid_config.particle_mass = 0.9025
	fluid_config.dynamic_viscosity = 0.35
	fluid_config.color_diffusion = 0.8
	fluid_config.max_substeps = 8
	fluid_config.pixels_per_meter = 100.0
	_fluid.config = fluid_config
	add_child(_fluid)
	_fluid.set_container_adapter(_container_adapter)
	_fluid.step_completed.connect(_on_step_completed)
	var batch := ParticleSpawnBatch2D.new()
	for y_index: int in range(20):
		for x_index: int in range(40):
			batch.positions_meters.append(Vector2(2.05 + float(x_index) * 0.095, 1.2 + float(y_index) * 0.095))
			batch.colors_srgb.append(Color(0.94, 0.28, 0.20, 0.72) if x_index < 20 else Color(0.18, 0.48, 0.95, 0.72))
			batch.concentrations.append(1.0)
			batch.turbidities.append(0.75)
	_fluid.add_particles(batch)

func _build_body() -> void:
	_floating_body = BuoyantBodyAdapter2D.new()
	_floating_body.name = "FloatingBlock"
	_floating_body.position = Vector2(480.0, 250.0)
	_floating_body.mass = 0.18
	var fluid_shape := BuoyantBodyShape2D.new()
	fluid_shape.shape_type = BuoyantBodyShape2D.ShapeType.RECTANGLE
	fluid_shape.size_meters = Vector2(0.45, 0.28)
	fluid_shape.sample_spacing_meters = 0.07
	_floating_body.fluid_shape = fluid_shape
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = fluid_shape.size_meters * _fluid.config.pixels_per_meter
	collision.shape = rectangle
	_floating_body.add_child(collision)
	var visual := Polygon2D.new()
	var half_size := rectangle.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	visual.color = Color(0.82, 0.94, 1.0)
	_floating_body.add_child(visual)
	add_child(_floating_body)
	_fluid.set_buoyant_adapters([_floating_body])

func _build_controls() -> void:
	var panel := HBoxContainer.new()
	panel.position = Vector2(20.0, 20.0)
	add_child(panel)
	_add_button(panel, "向左晃", func() -> void: _apply_cup_impulse(-180.0))
	_add_button(panel, "向右晃", func() -> void: _apply_cup_impulse(180.0))
	_add_button(panel, "杯子左转", func() -> void: _cup_angular_velocity_radians_per_second -= 1.2)
	_add_button(panel, "杯子右转", func() -> void: _cup_angular_velocity_radians_per_second += 1.2)
	_add_button(panel, "液体上冲", _apply_fluid_impulse)
	_add_button(panel, "冰块", func() -> void: _floating_body.mass = 0.18)
	_add_button(panel, "重物", func() -> void: _floating_body.mass = 1.2)
	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 64.0)
	_status_label.text = "等待模拟"
	add_child(_status_label)

func _add_button(parent: Control, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(callback)
	parent.add_child(button)

func _apply_cup_impulse(value_pixels_per_second: float) -> void:
	_cup_velocity_pixels_per_second.x += value_pixels_per_second

func _apply_fluid_impulse() -> void:
	var field := FluidForceField2D.new()
	field.field_id = &"demo_upward_impulse"
	field.acceleration = Vector2(0.0, -14.0)
	field.remaining_seconds = 0.18
	_fluid.set_force_fields([field])

func _on_step_completed(result: FluidStepResult2D) -> void:
	_status_label.text = "粒子 %d | 子步 %d | 密度误差 %.1f%% | 最大速度 %.2f m/s" % [
		result.particle_count,
		result.substeps,
		result.average_density_error_ratio * 100.0,
		result.maximum_speed,
	]
