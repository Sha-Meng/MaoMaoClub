extends RefCounted
class_name ParticleFluidIntegrationTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("rest density and boundary contribution", _test_rest_density_and_boundary)
	_suite.run_case("coarse water volume raises settled surface", _test_coarse_water_volume_height)
	_suite.run_case("force lifecycle and invalid input isolation", _test_force_lifecycle_and_invalid_input)
	_suite.run_case("optical concentration mixing modes", _test_optical_mixing)
	_suite.run_case("moving container contact and reaction toggle", _test_moving_container)
	_suite.run_case("container acceleration stop and surface response", _test_container_acceleration_sequence)
	_suite.run_case("renderer does not affect physics snapshot", _test_renderer_independence)
	_suite.run_case("buoyancy regimes drag continuity and unregister", _test_buoyancy_regimes)

func _base_config() -> ParticleFluidConfig2D:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2.ZERO
	config.fixed_test_substeps = 1
	config.max_substeps = 1
	config.smoothing_radius_meters = 0.09
	config.effective_depth_meters = 0.1
	config.particle_mass = 0.09
	config.rest_density = 1000.0
	config.gas_stiffness = 0.001
	config.dynamic_viscosity = 0.2
	return config

func _grid_batch(columns: int, rows: int, spacing: float, origin: Vector2) -> ParticleSpawnBatch2D:
	var batch := ParticleSpawnBatch2D.new()
	for y_index: int in range(rows):
		for x_index: int in range(columns):
			batch.positions_meters.append(origin + Vector2(float(x_index), float(y_index)) * spacing)
			batch.masses.append(1000.0 * 0.1 * spacing * spacing)
	return batch

func _test_rest_density_and_boundary() -> void:
	var config := _base_config()
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	solver.add_particles(_grid_batch(9, 9, 0.03, Vector2(-0.12, -0.12)))
	var result := solver.step(0.0001)
	_suite.expect_near(result.snapshot.densities[40], config.rest_density, config.rest_density * 0.12, "interior lattice density must approximate rest density")
	var isolated_batch := ParticleSpawnBatch2D.new()
	isolated_batch.positions_meters = PackedVector2Array([Vector2(0.0, 0.96)])
	isolated_batch.masses = PackedFloat32Array([config.particle_mass])
	var free_solver := ParticleFluidSolver2D.new()
	free_solver.configure(config)
	free_solver.add_particles(isolated_batch)
	var free_density := free_solver.step(0.0001).snapshot.densities[0]
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(1.0, 1.0)
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	var wall_solver := ParticleFluidSolver2D.new()
	wall_solver.configure(config)
	wall_solver.set_container(container)
	wall_solver.add_particles(isolated_batch)
	var wall_density := wall_solver.step(0.0001).snapshot.densities[0]
	_suite.expect_true(wall_density > free_density, "boundary samples must compensate near-wall density")

func _test_coarse_water_volume_height() -> void:
	var lower := _settle_coarse_water_column(60)
	var higher := _settle_coarse_water_column(90)
	var lower_height := float(lower["height_meters"])
	var higher_height := float(higher["height_meters"])
	_suite.expect_near(lower_height, 1.2, 0.25, "240 L of water in a 2 m x 0.1 m section must settle near 1.2 m")
	_suite.expect_near(higher_height, 1.8, 0.25, "360 L of water in a 2 m x 0.1 m section must settle near 1.8 m")
	_suite.expect_true(higher_height - lower_height >= 0.4, "adding 120 L must produce a clearly higher settled liquid surface")
	_suite.expect_true(float(lower["average_density"]) <= 1150.0, "settled 240 L water density must remain near 1000 kg/m^3")
	_suite.expect_true(float(higher["average_density"]) <= 1150.0, "settled 360 L water density must remain near 1000 kg/m^3")
	_suite.expect_true(float(lower["maximum_speed"]) <= 0.5, "settled 240 L water must dissipate coarse-grid oscillation")
	_suite.expect_true(float(higher["maximum_speed"]) <= 0.5, "settled 360 L water must dissipate coarse-grid oscillation")
	_suite.expect_true(not bool(lower["has_non_finite"]) and not bool(higher["has_non_finite"]), "coarse water columns must stay finite")


func _settle_coarse_water_column(particle_count: int) -> Dictionary:
	const spacing: float = 0.20
	const effective_depth: float = 0.10
	var config := ParticleFluidConfig2D.new()
	config.rest_density = 1000.0
	config.effective_depth_meters = effective_depth
	config.particle_mass = config.rest_density * effective_depth * spacing * spacing
	config.smoothing_radius_meters = spacing * 1.9
	config.speed_of_sound = 12.0
	config.gas_stiffness = config.rest_density * config.speed_of_sound * config.speed_of_sound
	config.tait_exponent = 7.0
	config.dynamic_viscosity = 50.0
	config.color_diffusion = 0.0
	config.max_substeps = 8
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(2.0, 4.0)
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	solver.set_container(container)
	var batch := ParticleSpawnBatch2D.new()
	for index: int in range(particle_count):
		var column := index % 10
		var row := index / 10
		batch.positions_meters.append(Vector2(
			-0.9 + float(column) * spacing,
			3.9 - float(row) * spacing
		))
	solver.add_particles(batch)
	var result := FluidStepResult2D.new()
	for _frame: int in range(600):
		result = solver.step(1.0 / 60.0)
	return {
		"height_meters": _robust_liquid_height(result.snapshot, spacing),
		"average_density": _average_snapshot_density(result.snapshot),
		"maximum_speed": result.maximum_speed,
		"has_non_finite": result.has_non_finite_state,
	}


func _robust_liquid_height(snapshot: ParticleFluidSnapshot2D, particle_spacing: float) -> float:
	var vertical_positions: Array[float] = []
	for position: Vector2 in snapshot.positions_meters:
		vertical_positions.append(position.y)
	vertical_positions.sort()
	var last_index := vertical_positions.size() - 1
	var top_index := floori(float(last_index) * 0.10)
	var bottom_index := ceili(float(last_index) * 0.90)
	return vertical_positions[bottom_index] - vertical_positions[top_index] + particle_spacing


func _average_snapshot_density(snapshot: ParticleFluidSnapshot2D) -> float:
	var total := 0.0
	for density: float in snapshot.densities:
		total += density
	return total / float(maxi(1, snapshot.count()))


func _test_force_lifecycle_and_invalid_input() -> void:
	var config := _base_config()
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = PackedVector2Array([Vector2.ZERO])
	solver.add_particles(batch)
	var field := FluidForceField2D.new()
	field.acceleration = Vector2(3.0, 0.0)
	field.remaining_seconds = 0.01
	solver.set_force_fields([field])
	var first := solver.step(0.01)
	var second := solver.step(0.01)
	_suite.expect_near(first.snapshot.velocities_meters_per_second[0].x, 0.03, 0.0001, "finite force field must apply during its lifetime")
	_suite.expect_near(second.snapshot.velocities_meters_per_second[0].x, 0.03, 0.0001, "expired force field must not apply again")
	_suite.expect_equal(second.active_force_field_count, 0, "expired force field must be removed")
	var before := solver.get_state_snapshot().duplicate_snapshot()
	var invalid := ParticleSpawnBatch2D.new()
	invalid.positions_meters = PackedVector2Array([Vector2(NAN, 0.0)])
	_suite.expect_true(not invalid.validate(config.particle_mass).is_empty(), "non-finite batch must be rejected")
	_suite.expect_equal(solver.get_state_snapshot().count(), before.count(), "rejected validation must leave solver state unchanged")
	var invalid_step := solver.step(NAN)
	_suite.expect_true(not invalid_step.warnings.is_empty(), "non-finite delta must emit a warning")
	_suite.expect_vector_near(solver.get_state_snapshot().positions_meters[0], before.positions_meters[0], 0.0, "invalid inputs must not contaminate state")

func _make_color_solver(diffusion: float) -> ParticleFluidSolver2D:
	var config := _base_config()
	config.color_diffusion = diffusion
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.01, 0.0)])
	batch.colors_srgb = PackedColorArray([Color(0.85, 0.20, 0.10, 0.5), Color(0.10, 0.35, 0.90, 0.5)])
	batch.concentrations = PackedFloat32Array([2.0, 1.0])
	solver.add_particles(batch)
	return solver

func _test_optical_mixing() -> void:
	var solver := _make_color_solver(20.0)
	var before := solver.get_state_snapshot()
	var sum_before := before.optical_densities[0] + before.optical_densities[1]
	var after := solver.step(0.1).snapshot
	_suite.expect_vector3_near(after.optical_densities[0] + after.optical_densities[1], sum_before, 0.00001, "pair diffusion must conserve concentration-weighted absorption")
	_suite.expect_vector3_near(after.optical_densities[0], after.optical_densities[1], 0.0001, "strong stable diffusion must converge two optical densities")
	var disabled := _make_color_solver(0.0)
	var disabled_before := disabled.get_state_snapshot()
	var disabled_after := disabled.step(0.1).snapshot
	_suite.expect_vector3_near(disabled_after.optical_densities[0], disabled_before.optical_densities[0], 0.0, "disabled diffusion must retain first color")
	_suite.expect_vector3_near(disabled_after.optical_densities[1], disabled_before.optical_densities[1], 0.0, "disabled diffusion must retain second color")
	var same := ColorTransport2D.diffuse_pair(Vector3.ONE, Vector3.ONE, 50.0, 1.0)
	_suite.expect_vector3_near(same[0], Vector3.ONE, 0.0, "same-color diffusion must be invariant")

func _test_container_acceleration_sequence() -> void:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2(0.0, 9.81)
	config.fixed_test_substeps = 1
	config.max_substeps = 1
	config.smoothing_radius_meters = 0.22
	config.particle_mass = 1.21
	config.gas_stiffness = 1000.0
	config.dynamic_viscosity = 2.0
	config.color_diffusion = 0.0
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var container := _make_cup_snapshot()
	solver.set_container(container)
	var batch := ParticleSpawnBatch2D.new()
	for y_index: int in range(3):
		for x_index: int in range(9):
			batch.positions_meters.append(Vector2(-0.44 + float(x_index) * 0.11, 0.62 + float(y_index) * 0.11))
	solver.add_particles(batch)
	var initial_relative_x := _average_local_x(solver.get_state_snapshot(), container)
	var delta_seconds := 0.001
	var acceleration := 1.5
	for step_index: int in range(400):
		var elapsed := float(step_index + 1) * delta_seconds
		container.world_transform = Transform2D(0.0, Vector2(0.5 * acceleration * elapsed * elapsed, 0.0))
		container.linear_velocity_meters_per_second = Vector2(acceleration * elapsed, 0.0)
		container.linear_acceleration_meters_per_second_squared = Vector2(acceleration, 0.0)
		solver.set_container(container)
		solver.step(delta_seconds)
	var accelerated_snapshot := solver.get_state_snapshot()
	var accelerated_relative_x := _average_local_x(accelerated_snapshot, container)
	_suite.expect_true(accelerated_relative_x < initial_relative_x, "fluid center of mass must lag opposite container acceleration")
	var surface := _surface_heights(accelerated_snapshot, container)
	_suite.expect_true(float(surface["right"]) >= float(surface["left"]) - 0.02, "accelerated free surface must not tilt opposite effective gravity")
	var speed_at_stop := _average_speed(accelerated_snapshot)
	container.linear_velocity_meters_per_second = Vector2.ZERO
	container.linear_acceleration_meters_per_second_squared = Vector2(-acceleration, 0.0)
	solver.set_container(container)
	solver.step(delta_seconds)
	container.linear_acceleration_meters_per_second_squared = Vector2.ZERO
	for _step_index: int in range(1000):
		solver.set_container(container)
		solver.step(delta_seconds)
	var settled_speed := _average_speed(solver.get_state_snapshot())
	_suite.expect_true(settled_speed < speed_at_stop, "post-stop slosh must dissipate without continued input")

func _average_local_x(snapshot: ParticleFluidSnapshot2D, container: ContainerSnapshot2D) -> float:
	var inverse := container.world_transform.affine_inverse()
	var total := 0.0
	for position: Vector2 in snapshot.positions_meters:
		total += (inverse * position).x
	return total / float(maxi(1, snapshot.count()))

func _average_speed(snapshot: ParticleFluidSnapshot2D) -> float:
	var total := 0.0
	for velocity: Vector2 in snapshot.velocities_meters_per_second:
		total += velocity.length()
	return total / float(maxi(1, snapshot.count()))

func _surface_heights(snapshot: ParticleFluidSnapshot2D, container: ContainerSnapshot2D) -> Dictionary:
	var inverse := container.world_transform.affine_inverse()
	var left_top := INF
	var right_top := INF
	for position: Vector2 in snapshot.positions_meters:
		var local := inverse * position
		if local.x < 0.0:
			left_top = minf(left_top, local.y)
		else:
			right_top = minf(right_top, local.y)
	return {"left": left_top, "right": right_top}

func _make_cup_snapshot(linear_velocity: Vector2 = Vector2.ZERO, angular_velocity: float = 0.0) -> ContainerSnapshot2D:
	var shape := ContainerShape2D.new()
	shape.configure_open_cup(1.0, 1.0)
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	container.linear_velocity_meters_per_second = linear_velocity
	container.angular_velocity_radians_per_second = angular_velocity
	return container

func _test_moving_container() -> void:
	var moving := _make_cup_snapshot(Vector2(1.0, 0.0))
	var constrained := BoundarySolver2D.constrain_particle(
		Vector2(-0.45, 0.5), Vector2(-0.60, 0.5), Vector2(-2.0, 0.0), 0.1, 0.02, moving, 0.0, 0.0
	)
	_suite.expect_true(Vector2(constrained["velocity"]).x >= 1.0, "accelerating wall contact must transfer wall motion to fluid")
	_suite.expect_true(_make_cup_snapshot(Vector2.ZERO, 2.0).point_velocity_world(Vector2(0.5, 0.5)).distance_to(Vector2.ZERO) > 0.0, "rotating container point velocity must include angular motion")
	var escaped := BoundarySolver2D.constrain_particle(
		Vector2(0.0, 0.05), Vector2(0.0, -0.20), Vector2(0.0, -2.0), 0.1, 0.02, _make_cup_snapshot(), 0.0, 0.0
	)
	_suite.expect_true(Vector2(escaped["position"]).y < 0.0, "open cup mouth must not create an invisible wall")
	for reaction_enabled: bool in [false, true]:
		var config := _base_config()
		config.enable_container_reaction = reaction_enabled
		var solver := ParticleFluidSolver2D.new()
		solver.configure(config)
		solver.set_container(_make_cup_snapshot())
		var batch := ParticleSpawnBatch2D.new()
		batch.positions_meters = PackedVector2Array([Vector2(-0.46, 0.5)])
		batch.velocities_meters_per_second = PackedVector2Array([Vector2(-4.0, 0.0)])
		solver.add_particles(batch)
		var result := solver.step(0.02)
		if reaction_enabled:
			_suite.expect_true(result.container_reaction_force.length() > 0.0, "enabled container reaction must report force")
		else:
			_suite.expect_vector_near(result.container_reaction_force, Vector2.ZERO, 0.0, "disabled container reaction must report zero")

func _test_renderer_independence() -> void:
	var solver := _make_color_solver(0.0)
	var before := solver.get_state_snapshot().duplicate_snapshot()
	var renderer := ParticleFluidRenderer2D.new()
	renderer.update_snapshot(before, 100.0)
	renderer.update_snapshot(before, 100.0)
	var after := solver.get_state_snapshot()
	for index: int in range(before.count()):
		_suite.expect_vector_near(after.positions_meters[index], before.positions_meters[index], 0.0, "render submission must not mutate positions")
		_suite.expect_vector_near(after.velocities_meters_per_second[index], before.velocities_meters_per_second[index], 0.0, "render submission must not mutate velocities")
	renderer.free()

func _make_buoyancy_fixture() -> Dictionary:
	var config := _base_config()
	config.smoothing_radius_meters = 0.12
	config.gravity_meters_per_second_squared = Vector2(0.0, 9.81)
	var state := ParticleFluidState2D.new()
	var batch := _grid_batch(9, 9, 0.03, Vector2(-0.12, -0.12))
	state.add_batch(batch, config)
	var spatial_hash := SpatialHash2D.new()
	spatial_hash.configure(config.smoothing_radius_meters)
	spatial_hash.build(state.positions)
	return {"config": config, "state": state, "hash": spatial_hash}

func _make_body(mass: float, position: Vector2 = Vector2.ZERO) -> BuoyantBodySnapshot2D:
	var shape := BuoyantBodyShape2D.new()
	shape.shape_type = BuoyantBodyShape2D.ShapeType.RECTANGLE
	shape.size_meters = Vector2(0.08, 0.05)
	shape.sample_spacing_meters = 0.02
	var body := BuoyantBodySnapshot2D.new()
	body.body_id = 42
	body.shape = shape
	body.world_transform = Transform2D(0.0, position)
	body.mass_kilograms = mass
	body.moment_of_inertia = 0.001
	body.effective_depth_meters = 0.1
	body.drag_coefficient = 1.5
	return body

func _solve_body(body: BuoyantBodySnapshot2D, fixture: Dictionary) -> Dictionary:
	return BuoyancySolver2D.solve(body, fixture["state"], fixture["hash"], fixture["config"], 0.0001)

func _test_buoyancy_regimes() -> void:
	for entry: Dictionary in [
		{"mass": 0.2, "sign": -1.0},
		{"mass": 0.4, "sign": 0.0},
		{"mass": 0.7, "sign": 1.0},
	]:
		var fixture := _make_buoyancy_fixture()
		var mass := float(entry["mass"])
		var result := _solve_body(_make_body(mass), fixture)
		var net_vertical := Vector2(result["force"]).y + mass * 9.81
		if float(entry["sign"]) < 0.0:
			_suite.expect_true(net_vertical < 0.0, "low-density body must accelerate upward")
		elif float(entry["sign"]) > 0.0:
			_suite.expect_true(net_vertical > 0.0, "high-density body must accelerate downward")
		else:
			_suite.expect_near(net_vertical, 0.0, 1.5, "near-fluid-density body must be approximately neutral")
	var drag_fixture := _make_buoyancy_fixture()
	var moving_body := _make_body(0.4)
	moving_body.linear_velocity_meters_per_second = Vector2(1.0, 0.0)
	var drag_result := _solve_body(moving_body, drag_fixture)
	_suite.expect_true(Vector2(drag_result["force"]).x < 0.0, "fluid drag must oppose relative body motion")
	var ratios := PackedFloat32Array()
	for y: float in [-0.25, -0.15, -0.05, 0.05]:
		var fixture := _make_buoyancy_fixture()
		ratios.append(float(_solve_body(_make_body(0.4, Vector2(0.0, y)), fixture)["submersion_ratio"]))
	for index: int in range(1, ratios.size()):
		_suite.expect_true(ratios[index] + 0.05 >= ratios[index - 1], "slow entry must produce continuous non-decreasing submersion")
	var closest_to_half := 1.0
	for ratio: float in ratios:
		closest_to_half = minf(closest_to_half, absf(ratio - 0.5))
	_suite.expect_true(closest_to_half < 0.3, "low-density body must have a reachable partial-submersion equilibrium")
	var dry_result := _solve_body(_make_body(0.4, Vector2(10.0, 10.0)), _make_buoyancy_fixture())
	_suite.expect_true(float(dry_result["submersion_ratio"]) == 0.0 and Vector2(dry_result["force"]).is_zero_approx(), "body outside all fluid neighborhoods must receive zero fluid force")
	var torque_fixture := _make_buoyancy_fixture()
	var tilted_body := _make_body(0.4, Vector2(0.13, -0.08))
	tilted_body.world_transform = Transform2D(0.45, tilted_body.world_transform.origin)
	var torque_result := _solve_body(tilted_body, torque_fixture)
	_suite.expect_true(absf(float(torque_result["torque"])) > 0.000001, "offset tilted submersion must create a lever-arm torque")
	var solver := ParticleFluidSolver2D.new()
	var config: ParticleFluidConfig2D = _make_buoyancy_fixture()["config"]
	solver.configure(config)
	solver.add_particles(_grid_batch(9, 9, 0.03, Vector2(-0.12, -0.12)))
	var registered := _make_body(0.4)
	solver.set_buoyant_bodies([registered])
	_suite.expect_true(solver.step(0.0001).body_forces.has(registered.body_id), "registered body must receive a result")
	solver.set_buoyant_bodies([])
	_suite.expect_true(not solver.step(0.0001).body_forces.has(registered.body_id), "unregistered body must stop receiving results")
