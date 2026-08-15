extends SceneTree

const FOUNDATIONS_TESTS := preload("res://tests/particle_fluid_2d/unit/test_foundations.gd")
const SOLVER_TESTS := preload("res://tests/particle_fluid_2d/unit/test_solver.gd")
const MATERIAL_TESTS := preload("res://tests/particle_fluid_2d/unit/test_materials.gd")
const RENDERING_TESTS := preload("res://tests/particle_fluid_2d/unit/test_rendering.gd")
const BUOYANCY_TESTS := preload("res://tests/particle_fluid_2d/unit/test_buoyancy.gd")
const INTEGRATION_TESTS := preload("res://tests/particle_fluid_2d/integration/test_particle_fluid_integration.gd")
const STABILITY_TESTS := preload("res://tests/particle_fluid_2d/stability/test_stability.gd")
const BENCHMARK := preload("res://tests/particle_fluid_2d/performance/benchmark_particle_fluid.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite := ParticleFluidTestSuite2D.new()
	var arguments := OS.get_cmdline_user_args()
	var foundations := FOUNDATIONS_TESTS.new()
	foundations.run(suite)
	var solver_tests := SOLVER_TESTS.new()
	solver_tests.run(suite)
	var material_tests := MATERIAL_TESTS.new()
	material_tests.run(suite)
	var rendering_tests := RENDERING_TESTS.new()
	rendering_tests.run(suite)
	var buoyancy_tests := BUOYANCY_TESTS.new()
	buoyancy_tests.run(suite)
	var integration := INTEGRATION_TESTS.new()
	integration.run(suite)
	if arguments.has("--long"):
		var stability := STABILITY_TESTS.new()
		stability.run(suite)
	if arguments.has("--benchmark"):
		var benchmark := BENCHMARK.new()
		benchmark.run()
	if arguments.has("--self-test-failure"):
		suite.run_case("intentional runner failure", func() -> void:
			suite.expect_true(false, "intentional failure proves non-zero exit behavior")
		)
	print("Particle fluid tests: %d passed, %d failed" % [suite.passed, suite.failed])
	for failure: String in suite.failures:
		print("  - %s" % failure)
	quit(0 if suite.failed == 0 else 1)
