extends RefCounted
class_name ParticleFluidStabilityTests

const SUBSTEPS_PER_FIXTURE: int = 10000

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("10000-substep static cup stability", func() -> void: _run_fixture(false))
	_suite.run_case("10000-substep moving cup stability", func() -> void: _run_fixture(true))

func _run_fixture(moving: bool) -> void:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2(0.0, 9.81)
	config.fixed_test_substeps = 1
	config.max_substeps = 1
	config.smoothing_radius_meters = 0.12
	config.particle_mass = 0.36
	config.gas_stiffness = 900.0
	config.dynamic_viscosity = 0.8
	config.max_speed_meters_per_second = 12.0
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(1.0, 1.0)
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	solver.set_container(container)
	var batch := ParticleSpawnBatch2D.new()
	for y_index: int in range(4):
		for x_index: int in range(6):
			batch.positions_meters.append(Vector2(-0.15 + float(x_index) * 0.06, 0.62 + float(y_index) * 0.06))
	solver.add_particles(batch)
	var initial_mass := config.particle_mass * float(batch.count())
	var maximum_energy := 0.0
	var last_result := FluidStepResult2D.new()
	for step_index: int in range(SUBSTEPS_PER_FIXTURE):
		if moving:
			var phase := float(step_index) * 0.002
			container.world_transform = Transform2D(0.025 * sin(phase * 0.7), Vector2(0.03 * sin(phase), 0.0))
			container.linear_velocity_meters_per_second = Vector2(0.06 * cos(phase), 0.0)
			container.angular_velocity_radians_per_second = 0.035 * cos(phase * 0.7)
			solver.set_container(container)
		last_result = solver.step(0.0005)
		maximum_energy = maxf(maximum_energy, last_result.kinetic_energy)
		if step_index % 100 == 0:
			_suite.expect_true(not last_result.has_non_finite_state, "long-run fixture must remain finite")
			_suite.expect_near(last_result.total_mass, initial_mass, 0.00001, "long-run fixture must conserve mass")
			_check_no_solid_wall_leak(last_result.snapshot, container)
	_suite.expect_equal(last_result.substeps, 1, "fixture must execute exactly one substep per iteration")
	_suite.expect_true(last_result.maximum_speed <= config.max_speed_meters_per_second + 0.001, "long-run speed must remain bounded")
	_suite.expect_true(maximum_energy <= 0.5 * initial_mass * config.max_speed_meters_per_second * config.max_speed_meters_per_second + 0.01, "long-run kinetic energy must remain bounded")
	_check_no_solid_wall_leak(last_result.snapshot, container)
	if not moving:
		var left_surface := INF
		var right_surface := INF
		for position: Vector2 in last_result.snapshot.positions_meters:
			var local := container.world_transform.affine_inverse() * position
			if local.x < 0.0:
				left_surface = minf(left_surface, local.y)
			else:
				right_surface = minf(right_surface, local.y)
		_suite.expect_near(left_surface, right_surface, 0.12, "settled static free surface must be approximately horizontal")
	print("STABILITY fixture=%s substeps=%d max_energy=%.6f final_speed=%.6f" % [
		"moving" if moving else "static",
		SUBSTEPS_PER_FIXTURE,
		maximum_energy,
		last_result.maximum_speed,
	])

func _check_no_solid_wall_leak(snapshot: ParticleFluidSnapshot2D, container: ContainerSnapshot2D) -> void:
	var inverse := container.world_transform.affine_inverse()
	for position: Vector2 in snapshot.positions_meters:
		var local := inverse * position
		_suite.expect_true(local.x >= -0.53 and local.x <= 0.53, "particle must not leak through side walls")
		_suite.expect_true(local.y <= 1.03, "particle must not leak through cup floor")
