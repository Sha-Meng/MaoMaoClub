extends RefCounted
class_name ParticleFluidMaterialTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("material registry validation and isolation", _test_registry_validation)
	_suite.run_case("material optical and physical derivation", _test_material_derivation)
	_suite.run_case("material density changes pressure threshold", _test_density_pressure_threshold)
	_suite.run_case("material viscosity remains symmetric", _test_material_viscosity)
	_suite.run_case("material mixing groups gate diffusion", _test_mixing_groups)

func _make_config() -> ParticleFluidConfig2D:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2.ZERO
	config.fixed_test_substeps = 1
	config.max_substeps = 1
	config.smoothing_radius_meters = 0.1
	config.effective_depth_meters = 0.1
	config.particle_mass = 0.1
	config.rest_density = 1000.0
	config.gas_stiffness = 1200.0
	config.dynamic_viscosity = 5.0
	return config

func _make_material(material_id: int) -> FluidMaterial2D:
	var material := FluidMaterial2D.new()
	material.material_id = material_id
	return material

func _test_registry_validation() -> void:
	var solver := ParticleFluidSolver2D.new()
	solver.configure(_make_config())
	var first := _make_material(1)
	first.density_multiplier = 1.25
	var duplicate := _make_material(1)
	var errors := solver.configure_materials([first, duplicate])
	_suite.expect_true(not errors.is_empty(), "duplicate material ids must be rejected")
	_suite.expect_equal(solver.get_material(1).material_id, 0, "rejected table must leave default material active")
	errors = solver.configure_materials([first])
	_suite.expect_equal(errors.size(), 0, "valid material table must be accepted")
	first.density_multiplier = 9.0
	_suite.expect_near(solver.get_material(1).density_multiplier, 1.25, 0.0, "solver must own a deep material copy")
	var invalid := _make_material(-1)
	_suite.expect_true(not invalid.validate().is_empty(), "negative material id must be invalid")

func _test_material_derivation() -> void:
	var material := _make_material(2)
	material.density_multiplier = 1.2
	material.viscosity_multiplier = 2.5
	material.dye_strength = 2.0
	material.turbidity_multiplier = 1.5
	material.refractive_strength = 0.7
	material.specular_strength = 0.8
	var solver := ParticleFluidSolver2D.new()
	var config := _make_config()
	solver.configure(config)
	_suite.expect_equal(solver.configure_materials([material]).size(), 0, "valid optical material must configure")
	var source_color := Color(0.4, 0.6, 0.8, 0.5)
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = PackedVector2Array([Vector2.ZERO])
	batch.colors_srgb = PackedColorArray([source_color])
	batch.concentrations = PackedFloat32Array([1.0])
	batch.turbidities = PackedFloat32Array([0.4])
	batch.material_ids = PackedInt32Array([2])
	solver.add_particles(batch)
	var snapshot := solver.get_state_snapshot()
	_suite.expect_equal(snapshot.material_ids[0], 2, "snapshot must retain resolved material id")
	_suite.expect_near(snapshot.target_rest_densities[0], 1200.0, 0.001, "density multiplier must derive target density")
	_suite.expect_near(snapshot.turbidities[0], 0.6, 0.0001, "turbidity multiplier must affect spawn optics")
	_suite.expect_near(snapshot.refractive_strengths[0], 0.7, 0.0001, "snapshot must expose refraction strength")
	_suite.expect_near(snapshot.specular_strengths[0], 0.8, 0.0001, "snapshot must expose specular strength")
	var expected_optical := ColorTransport2D.srgb_to_optical_density(source_color, 2.0)
	_suite.expect_vector3_near(snapshot.optical_densities[0], expected_optical, 0.0001, "dye strength must scale initial absorption")

func _test_density_pressure_threshold() -> void:
	var config := _make_config()
	var default_solver := ParticleFluidSolver2D.new()
	default_solver.configure(config)
	var dense_solver := ParticleFluidSolver2D.new()
	dense_solver.configure(config)
	var dense_material := _make_material(1)
	dense_material.density_multiplier = 2.0
	dense_solver.configure_materials([dense_material])
	var default_batch := ParticleSpawnBatch2D.new()
	default_batch.positions_meters = PackedVector2Array([Vector2.ZERO])
	default_batch.masses = PackedFloat32Array([1.0])
	default_solver.add_particles(default_batch)
	var dense_batch := ParticleSpawnBatch2D.new()
	dense_batch.positions_meters = PackedVector2Array([Vector2.ZERO])
	dense_batch.masses = PackedFloat32Array([1.0])
	dense_batch.material_ids = PackedInt32Array([1])
	dense_solver.add_particles(dense_batch)
	var default_snapshot := default_solver.step(0.0001).snapshot
	var dense_snapshot := dense_solver.step(0.0001).snapshot
	_suite.expect_near(default_snapshot.densities[0], dense_snapshot.densities[0], 0.001, "same mass distribution must produce same sampled density")
	_suite.expect_true(default_snapshot.pressures[0] > dense_snapshot.pressures[0], "higher target density must reduce compression pressure at equal sampled density")

func _test_material_viscosity() -> void:
	var config := _make_config()
	config.gas_stiffness = 0.0001
	var default_solver := ParticleFluidSolver2D.new()
	default_solver.configure(config)
	var viscous_solver := ParticleFluidSolver2D.new()
	viscous_solver.configure(config)
	var viscous_material := _make_material(1)
	viscous_material.viscosity_multiplier = 4.0
	viscous_solver.configure_materials([viscous_material])
	var positions := PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.02, 0.0)])
	var velocities := PackedVector2Array([Vector2(1.0, 0.0), Vector2(-1.0, 0.0)])
	var default_batch := ParticleSpawnBatch2D.new()
	default_batch.positions_meters = positions
	default_batch.velocities_meters_per_second = velocities
	default_solver.add_particles(default_batch)
	var viscous_batch := ParticleSpawnBatch2D.new()
	viscous_batch.positions_meters = positions
	viscous_batch.velocities_meters_per_second = velocities
	viscous_batch.material_ids = PackedInt32Array([1, 1])
	viscous_solver.add_particles(viscous_batch)
	var default_result := default_solver.step(0.002)
	var viscous_result := viscous_solver.step(0.002)
	var default_relative := default_result.snapshot.velocities_meters_per_second[0].distance_to(default_result.snapshot.velocities_meters_per_second[1])
	var viscous_relative := viscous_result.snapshot.velocities_meters_per_second[0].distance_to(viscous_result.snapshot.velocities_meters_per_second[1])
	_suite.expect_true(viscous_relative < default_relative, "higher material viscosity must dissipate relative speed faster")
	_suite.expect_vector_near(viscous_result.total_linear_momentum, Vector2.ZERO, 0.0001, "material viscosity pair must conserve total momentum")

func _test_mixing_groups() -> void:
	var first_material := _make_material(1)
	first_material.mixing_group = 1
	var second_material := _make_material(2)
	second_material.mixing_group = 2
	var blocked := _make_color_solver(first_material, second_material)
	var blocked_before := blocked.get_state_snapshot()
	var blocked_after := blocked.step(0.1).snapshot
	_suite.expect_vector3_near(blocked_after.optical_densities[0], blocked_before.optical_densities[0], 0.0, "different mixing groups must block first absorption exchange")
	_suite.expect_vector3_near(blocked_after.optical_densities[1], blocked_before.optical_densities[1], 0.0, "different mixing groups must block second absorption exchange")
	second_material.mixing_group = 1
	var allowed := _make_color_solver(first_material, second_material)
	var allowed_before := allowed.get_state_snapshot()
	var sum_before := allowed_before.optical_densities[0] + allowed_before.optical_densities[1]
	var allowed_after := allowed.step(0.1).snapshot
	_suite.expect_true(allowed_after.optical_densities[0] != allowed_before.optical_densities[0], "same mixing group must allow diffusion")
	_suite.expect_vector3_near(allowed_after.optical_densities[0] + allowed_after.optical_densities[1], sum_before, 0.0001, "material-gated diffusion must conserve absorption")

func _make_color_solver(first_material: FluidMaterial2D, second_material: FluidMaterial2D) -> ParticleFluidSolver2D:
	var config := _make_config()
	config.gas_stiffness = 0.0001
	config.dynamic_viscosity = 0.0
	config.color_diffusion = 20.0
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	solver.configure_materials([first_material, second_material])
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.01, 0.0)])
	batch.colors_srgb = PackedColorArray([Color(0.9, 0.2, 0.1), Color(0.1, 0.3, 0.9)])
	batch.material_ids = PackedInt32Array([1, 2])
	solver.add_particles(batch)
	return solver
