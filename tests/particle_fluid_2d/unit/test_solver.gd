extends RefCounted
class_name ParticleFluidSolverTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("solver external acceleration", _test_external_acceleration)
	_suite.run_case("solver momentum symmetry", _test_momentum_symmetry)
	_suite.run_case("solver viscosity dissipates", _test_viscosity)
	_suite.run_case("solver deterministic snapshots", _test_determinism)
	_suite.run_case("solver substep limits and warnings", _test_substep_limits)
	_suite.run_case("solver quiescent damping wakes for active force", _test_quiescent_damping)
	_suite.run_case("solver explicit velocity damping", _test_explicit_velocity_damping)
	_suite.run_case("open cup boundary", _test_open_cup)

func _make_config() -> ParticleFluidConfig2D:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2.ZERO
	config.fixed_test_substeps = 1
	config.smoothing_radius_meters = 0.1
	config.particle_mass = 0.1
	config.rest_density = 1000.0
	config.gas_stiffness = 1200.0
	return config

func _make_batch(positions: PackedVector2Array, velocities: PackedVector2Array = PackedVector2Array()) -> ParticleSpawnBatch2D:
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = positions
	batch.velocities_meters_per_second = velocities
	return batch

func _test_external_acceleration() -> void:
	var solver := ParticleFluidSolver2D.new()
	solver.configure(_make_config())
	solver.add_particles(_make_batch(PackedVector2Array([Vector2.ZERO])))
	solver.set_external_acceleration(Vector2(2.0, 0.0))
	var result := solver.step(0.01)
	_suite.expect_near(result.snapshot.velocities_meters_per_second[0].x, 0.02, 0.0001, "uniform acceleration must integrate velocity")

func _test_momentum_symmetry() -> void:
	var config := _make_config()
	config.rest_density = 10.0
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	solver.add_particles(_make_batch(PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.02, 0.0)])))
	var before := solver.step(0.001).total_linear_momentum
	var after := solver.step(0.001).total_linear_momentum
	_suite.expect_vector_near(after, before, 0.0001, "symmetric pressure forces must conserve momentum")

func _test_viscosity() -> void:
	var config := _make_config()
	config.gas_stiffness = 0.0001
	config.dynamic_viscosity = 5.0
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var velocities := PackedVector2Array([Vector2(1.0, 0.0), Vector2(-1.0, 0.0)])
	solver.add_particles(_make_batch(PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.02, 0.0)]), velocities))
	var before := solver.get_state_snapshot().velocities_meters_per_second[0].distance_to(
		solver.get_state_snapshot().velocities_meters_per_second[1]
	)
	var after_snapshot := solver.step(0.005).snapshot
	var after := after_snapshot.velocities_meters_per_second[0].distance_to(after_snapshot.velocities_meters_per_second[1])
	_suite.expect_true(after < before, "positive viscosity must reduce relative velocity")

func _test_determinism() -> void:
	var first := ParticleFluidSolver2D.new()
	var second := ParticleFluidSolver2D.new()
	var config := _make_config()
	first.configure(config)
	second.configure(config)
	var batch := _make_batch(PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.02, 0.0)])
	)
	first.add_particles(batch)
	second.add_particles(batch)
	for _index: int in range(10):
		first.step(0.002)
		second.step(0.002)
	var first_snapshot := first.get_state_snapshot()
	var second_snapshot := second.get_state_snapshot()
	for index: int in range(first_snapshot.count()):
		_suite.expect_vector_near(first_snapshot.positions_meters[index], second_snapshot.positions_meters[index], 0.000001, "same inputs must reproduce positions")
		_suite.expect_vector_near(first_snapshot.velocities_meters_per_second[index], second_snapshot.velocities_meters_per_second[index], 0.000001, "same inputs must reproduce velocities")

func _test_substep_limits() -> void:
	var adaptive_config := _make_config()
	adaptive_config.fixed_test_substeps = 0
	adaptive_config.max_substeps = 2
	adaptive_config.speed_of_sound = 100.0
	var adaptive := ParticleFluidSolver2D.new()
	adaptive.configure(adaptive_config)
	adaptive.add_particles(_make_batch(PackedVector2Array([Vector2.ZERO])))
	var limited := adaptive.step(0.1)
	_suite.expect_equal(limited.substeps, 2, "adaptive stepping must honor max_substeps")
	_suite.expect_true(limited.warnings.has("requested tick exceeds configured stable substep budget"), "limited adaptive step must emit a warning")
	var fixed_config := _make_config()
	fixed_config.fixed_test_substeps = 3
	fixed_config.max_substeps = 4
	var fixed := ParticleFluidSolver2D.new()
	fixed.configure(fixed_config)
	fixed.add_particles(_make_batch(PackedVector2Array([Vector2.ZERO])))
	_suite.expect_equal(fixed.step(0.01).substeps, 3, "fixed test mode must use configured deterministic substeps")

func _test_quiescent_damping() -> void:
	var config := _make_config()
	config.gas_stiffness = 0.0001
	config.dynamic_viscosity = 0.0
	config.quiescent_damping_per_second = 10.0
	config.quiescent_activation_delay_seconds = 0.0
	config.quiescent_max_average_speed = 2.0
	config.quiescent_stop_speed = 0.0
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	solver.add_particles(_make_batch(
		PackedVector2Array([Vector2.ZERO]),
		PackedVector2Array([Vector2(1.0, 0.0)])
	))
	var damped := solver.step(0.1)
	_suite.expect_true(damped.quiescent_damping_active, "stationary environment must activate quiescent damping")
	_suite.expect_near(
		damped.snapshot.velocities_meters_per_second[0].x,
		exp(-1.0),
		0.0001,
		"quiescent damping must be exponential and frame-rate independent"
	)
	var field := FluidForceField2D.new()
	field.acceleration = Vector2(2.0, 0.0)
	field.remaining_seconds = 0.2
	var fields: Array[FluidForceField2D] = [field]
	solver.set_force_fields(fields)
	var active := solver.step(0.1)
	_suite.expect_true(not active.quiescent_damping_active, "active force must wake quiescent damping immediately")
	_suite.expect_true(
		active.snapshot.velocities_meters_per_second[0].x > damped.snapshot.velocities_meters_per_second[0].x,
		"active force must accelerate fluid without quiescent damping"
	)


func _test_explicit_velocity_damping() -> void:
	var solver := ParticleFluidSolver2D.new()
	solver.configure(_make_config())
	solver.add_particles(_make_batch(
		PackedVector2Array([Vector2.ZERO, Vector2(0.2, 0.0)]),
		PackedVector2Array([Vector2(2.0, 0.0), Vector2(0.02, 0.0)])
	))
	solver.apply_velocity_damping(10.0, 0.1, 0.01)
	var snapshot := solver.get_state_snapshot()
	_suite.expect_near(
		snapshot.velocities_meters_per_second[0].x,
		2.0 * exp(-1.0),
		0.0001,
		"explicit damping must be exponential and frame-rate independent"
	)
	solver.apply_velocity_damping(10.0, 0.1, 0.01)
	solver.apply_velocity_damping(10.0, 0.1, 0.01)
	_suite.expect_vector_near(
		solver.get_state_snapshot().velocities_meters_per_second[1],
		Vector2.ZERO,
		0.000001,
		"explicit damping must snap velocities below the configured stop speed"
	)

func _test_open_cup() -> void:
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(1.0, 1.0)
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	var solver := ParticleFluidSolver2D.new()
	solver.configure(_make_config())
	solver.set_container(container)
	solver.set_external_acceleration(Vector2(0.0, 9.81))
	solver.add_particles(_make_batch(PackedVector2Array([Vector2(0.0, 0.8)])))
	for _index: int in range(100):
		solver.step(0.002)
	var position := solver.get_state_snapshot().positions_meters[0]
	_suite.expect_true(position.y < 1.0 and absf(position.x) < 0.5, "cup walls and floor must contain particle")
