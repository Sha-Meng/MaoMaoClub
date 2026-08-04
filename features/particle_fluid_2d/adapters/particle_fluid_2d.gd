extends Node2D
class_name ParticleFluid2D

signal step_completed(result: FluidStepResult2D)
signal stability_warning(messages: PackedStringArray)

@export var config: ParticleFluidConfig2D = ParticleFluidConfig2D.new()
@export var simulate: bool = true

var solver: ParticleFluidSolver2D = ParticleFluidSolver2D.new()
var _container_adapter: ContainerMotionAdapter2D
var _buoyant_adapters: Array[BuoyantBodyAdapter2D] = []
var _renderer: ParticleFluidRenderer2D

func _ready() -> void:
	var runtime_config := config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ParticleFluidConfig2D
	config = runtime_config
	solver.configure(config)
	_renderer = ParticleFluidRenderer2D.new()
	_renderer.name = "ParticleRenderer"
	_renderer.particle_diameter_pixels = config.meters_to_pixels(config.smoothing_radius_meters * 0.44)
	add_child(_renderer)

func _physics_process(delta: float) -> void:
	if not simulate or not solver.is_configured():
		return
	if _container_adapter != null and is_instance_valid(_container_adapter):
		solver.set_container(_container_adapter.capture_snapshot(config, delta))
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
	_renderer.update_snapshot(result.snapshot, config.pixels_per_meter)
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

func reset(seed: int = 0) -> void:
	solver.reset(seed)
	if _renderer != null:
		_renderer.update_snapshot(ParticleFluidSnapshot2D.new(), config.pixels_per_meter)

func set_rendering_enabled(enabled: bool) -> void:
	if _renderer != null:
		_renderer.visible = enabled

func get_state_snapshot() -> ParticleFluidSnapshot2D:
	return solver.get_state_snapshot()
