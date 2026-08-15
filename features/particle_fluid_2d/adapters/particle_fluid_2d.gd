extends Node2D
class_name ParticleFluid2D

signal step_completed(result: FluidStepResult2D)
signal stability_warning(messages: PackedStringArray)

enum RenderMode {
	OPTICAL_FIELD,
	DIRECT_PARTICLES,
}

@export var config: ParticleFluidConfig2D = ParticleFluidConfig2D.new()
@export var materials: Array[FluidMaterial2D] = []
@export var simulate: bool = true
@export_enum("Optical Field", "Direct Particles") var render_mode: int = RenderMode.OPTICAL_FIELD
@export var optical_field_resolution: Vector2i = Vector2i(160, 256)
@export_range(1.0, 3.0, 0.05) var optical_surface_fill_scale: float = 2.20

var solver: ParticleFluidSolver2D = ParticleFluidSolver2D.new()
var _container_adapter: ContainerMotionAdapter2D
var _buoyant_adapters: Array[BuoyantBodyAdapter2D] = []
var _direct_renderer: ParticleFluidRenderer2D
var _optical_renderer: OpticalFluidRenderer2D

func _ready() -> void:
	var runtime_config := config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ParticleFluidConfig2D
	config = runtime_config
	solver.configure(config)
	var material_errors := solver.configure_materials(materials)
	if not material_errors.is_empty():
		push_error("Invalid particle fluid materials: %s" % ", ".join(material_errors))
	_create_renderer()

func _physics_process(delta: float) -> void:
	if not simulate or not solver.is_configured():
		return
	var container_snapshot: ContainerSnapshot2D
	if _container_adapter != null and is_instance_valid(_container_adapter):
		container_snapshot = _container_adapter.capture_snapshot(config, delta)
		solver.set_container(container_snapshot)
	var body_snapshots: Array[BuoyantBodySnapshot2D] = []
	for adapter: BuoyantBodyAdapter2D in _buoyant_adapters.duplicate():
		if not is_instance_valid(adapter):
			_buoyant_adapters.erase(adapter)
			continue
		adapter.pixels_per_meter = config.pixels_per_meter
		var snapshot := adapter.make_snapshot()
		if snapshot != null and snapshot.validate().is_empty():
			body_snapshots.append(snapshot)
	solver.set_buoyant_bodies(body_snapshots)
	var result := solver.step(delta)
	for adapter: BuoyantBodyAdapter2D in _buoyant_adapters:
		var force: Vector2 = result.body_forces.get(adapter.body_id, Vector2.ZERO)
		var torque: float = float(result.body_torques.get(adapter.body_id, 0.0))
		adapter.queue_fluid_force(force, torque)
	_update_renderer(result.snapshot, container_snapshot)
	if not result.warnings.is_empty():
		stability_warning.emit(result.warnings)
	step_completed.emit(result)

func set_container_adapter(adapter: ContainerMotionAdapter2D) -> void:
	_container_adapter = adapter

func set_buoyant_adapters(adapters: Array[BuoyantBodyAdapter2D]) -> void:
	_buoyant_adapters = adapters.duplicate()

func add_particles(batch: ParticleSpawnBatch2D) -> PackedInt32Array:
	return solver.add_particles(batch)

func remove_particles(particle_ids: PackedInt32Array) -> void:
	solver.remove_particles(particle_ids)

func set_external_acceleration(value: Vector2) -> void:
	solver.set_external_acceleration(value)

func set_force_fields(fields: Array[FluidForceField2D]) -> void:
	solver.set_force_fields(fields)

func wake() -> void:
	solver.wake()

func is_quiescent_damping_active() -> bool:
	return solver.is_quiescent_damping_active()

func apply_velocity_damping(
	damping_per_second: float,
	delta_seconds: float,
	stop_speed: float = 0.0
) -> void:
	solver.apply_velocity_damping(damping_per_second, delta_seconds, stop_speed)

func set_materials(new_materials: Array[FluidMaterial2D]) -> PackedStringArray:
	var errors := solver.configure_materials(new_materials)
	if errors.is_empty():
		materials.clear()
		for material: FluidMaterial2D in new_materials:
			materials.append(material.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FluidMaterial2D)
	return errors

func reset(seed: int = 0) -> void:
	solver.reset(seed)
	var empty_snapshot := ParticleFluidSnapshot2D.new()
	if _direct_renderer != null:
		_direct_renderer.update_snapshot(empty_snapshot, config.pixels_per_meter)
	if _optical_renderer != null:
		_optical_renderer.update_snapshot(empty_snapshot, config.pixels_per_meter)

func set_rendering_enabled(enabled: bool) -> void:
	if _direct_renderer != null:
		_direct_renderer.visible = enabled
	if _optical_renderer != null:
		_optical_renderer.visible = enabled

func set_render_mode(new_mode: int) -> void:
	if new_mode != RenderMode.OPTICAL_FIELD and new_mode != RenderMode.DIRECT_PARTICLES:
		push_warning("Unknown particle fluid render mode: %d" % new_mode)
		return
	if render_mode == new_mode:
		return
	render_mode = new_mode
	if is_inside_tree():
		_create_renderer()

func get_state_snapshot() -> ParticleFluidSnapshot2D:
	return solver.get_state_snapshot()


func enforce_closed_container_containment(container_snapshot: ContainerSnapshot2D) -> void:
	var snapshot := solver.enforce_closed_container_containment(container_snapshot)
	_update_renderer(snapshot, container_snapshot)

func _create_renderer() -> void:
	_clear_renderer()
	var direct_diameter_pixels := config.meters_to_pixels(config.smoothing_radius_meters * 0.44)
	if render_mode == RenderMode.DIRECT_PARTICLES:
		_direct_renderer = ParticleFluidRenderer2D.new()
		_direct_renderer.name = "ParticleRenderer"
		_direct_renderer.particle_diameter_pixels = direct_diameter_pixels
		add_child(_direct_renderer)
		return
	_optical_renderer = OpticalFluidRenderer2D.new()
	_optical_renderer.name = "OpticalFluidRenderer"
	_optical_renderer.field_resolution = optical_field_resolution
	# 光学场通过重叠 splat 填补粗粒子之间的对角空隙；不增加物理粒子或节点。
	_optical_renderer.particle_diameter_pixels = (
		direct_diameter_pixels * clampf(optical_surface_fill_scale, 1.0, 3.0)
	)
	add_child(_optical_renderer)

func _clear_renderer() -> void:
	if _direct_renderer != null:
		remove_child(_direct_renderer)
		_direct_renderer.queue_free()
		_direct_renderer = null
	if _optical_renderer != null:
		remove_child(_optical_renderer)
		_optical_renderer.queue_free()
		_optical_renderer = null

func _update_renderer(
	snapshot: ParticleFluidSnapshot2D,
	container_snapshot: ContainerSnapshot2D
) -> void:
	if _direct_renderer != null:
		_direct_renderer.update_snapshot(snapshot, config.pixels_per_meter)
	elif _optical_renderer != null:
		_optical_renderer.update_snapshot(
			snapshot,
			config.pixels_per_meter,
			_container_bounds_world_pixels(container_snapshot),
			container_snapshot
		)

func _container_bounds_world_pixels(container_snapshot: ContainerSnapshot2D) -> Rect2:
	if container_snapshot == null or container_snapshot.shape == null:
		return Rect2()
	var shape := container_snapshot.shape
	if shape.segment_count() == 0:
		return Rect2()
	var first_world_meters := container_snapshot.world_transform * shape.segment_starts_local_meters[0]
	var bounds := Rect2(first_world_meters * config.pixels_per_meter, Vector2.ZERO)
	for index: int in range(shape.segment_count()):
		var start_world_meters := container_snapshot.world_transform * shape.segment_starts_local_meters[index]
		var end_world_meters := container_snapshot.world_transform * shape.segment_ends_local_meters[index]
		bounds = bounds.expand(start_world_meters * config.pixels_per_meter)
		bounds = bounds.expand(end_world_meters * config.pixels_per_meter)
	return bounds
