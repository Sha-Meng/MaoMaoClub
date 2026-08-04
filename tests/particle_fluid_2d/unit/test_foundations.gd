extends RefCounted
class_name ParticleFluidFoundationsTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("config validation", _test_config_validation)
	_suite.run_case("state isolation and snapshots", _test_state_isolation)
	_suite.run_case("SPH kernels", _test_sph_kernels)
	_suite.run_case("spatial hash matches brute force", _test_spatial_hash)
	_suite.run_case("optical conversion and diffusion", _test_color_transport)

func _test_config_validation() -> void:
	var config := ParticleFluidConfig2D.new()
	_suite.expect_equal(config.validate().size(), 0, "default config must be valid")
	config.rest_density = -1.0
	_suite.expect_true(config.validate().size() > 0, "negative density must be rejected")

func _test_state_isolation() -> void:
	var config := ParticleFluidConfig2D.new()
	var batch := ParticleSpawnBatch2D.new()
	batch.positions_meters = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.02, 0.0)])
	var first := ParticleFluidState2D.new()
	var second := ParticleFluidState2D.new()
	first.add_batch(batch, config)
	second.add_batch(batch, config)
	first.positions[0] = Vector2(9.0, 9.0)
	_suite.expect_true(second.positions[0] != first.positions[0], "solver states must not share arrays")
	var snapshot := second.make_snapshot(1.0)
	snapshot.positions_meters[0] = Vector2(5.0, 5.0)
	_suite.expect_true(second.positions[0] != snapshot.positions_meters[0], "snapshot must be detached")
	second.remove_particles(PackedInt32Array([second.ids[0]]))
	_suite.expect_equal(second.count(), 1, "explicit remove must remove one particle")

func _test_sph_kernels() -> void:
	var h := 1.0
	_suite.expect_true(SphKernels2D.density_poly6(0.0, h) > 0.0, "density kernel must be positive at origin")
	_suite.expect_near(SphKernels2D.density_poly6(h, h), 0.0, 0.000001, "density kernel must have finite support")
	var gradient := SphKernels2D.pressure_spiky_gradient(Vector2(0.25, 0.0), h)
	var opposite := SphKernels2D.pressure_spiky_gradient(Vector2(-0.25, 0.0), h)
	_suite.expect_vector_near(gradient, -opposite, 0.000001, "pressure gradient must be antisymmetric")
	_suite.expect_true(SphKernels2D.viscosity_laplacian(0.25, h) > 0.0, "viscosity laplacian must be positive")
	var integral := 0.0
	var rings := 2000
	var dr := h / float(rings)
	for index: int in range(rings):
		var radius := (float(index) + 0.5) * dr
		integral += SphKernels2D.density_poly6(radius, h) * TAU * radius * dr
	_suite.expect_near(integral, 1.0, 0.002, "2D density kernel must integrate to one")
	_suite.expect_near(SphKernels2D.density_poly6(-0.1, h), 0.0, 0.0, "negative radius must be outside support")
	_suite.expect_near(SphKernels2D.viscosity_laplacian(h * 2.0, h), 0.0, 0.0, "viscosity kernel must have finite support")

func _test_spatial_hash() -> void:
	var positions := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for _index: int in range(100):
		positions.append(Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)))
	var spatial_hash := SpatialHash2D.new()
	spatial_hash.configure(0.4)
	spatial_hash.build(positions)
	for query_index: int in range(positions.size()):
		var actual: Array = Array(spatial_hash.query_indices(positions[query_index], 0.4, positions))
		var expected: Array = []
		for candidate: int in range(positions.size()):
			if positions[query_index].distance_to(positions[candidate]) <= 0.4:
				expected.append(candidate)
		actual.sort()
		expected.sort()
		_suite.expect_equal(actual, expected, "spatial hash neighbor set must match brute force")
	var occupied_bucket_count := spatial_hash.bucket_count()
	spatial_hash.build(PackedVector2Array())
	_suite.expect_true(spatial_hash.pooled_bucket_count() >= occupied_bucket_count, "spatial hash must recycle bucket arrays")

func _test_color_transport() -> void:
	var source := Color(0.3, 0.7, 0.9, 0.6)
	var optical := ColorTransport2D.srgb_to_optical_density(source)
	var output := ColorTransport2D.optical_density_to_srgb(optical, 1.0, -log(1.0 - source.a))
	_suite.expect_near(output.r, source.r, 0.002, "red channel roundtrip")
	_suite.expect_near(output.g, source.g, 0.002, "green channel roundtrip")
	_suite.expect_near(output.b, source.b, 0.002, "blue channel roundtrip")
	var mixed := ColorTransport2D.diffuse_pair(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), 1.0, 0.25)
	_suite.expect_vector3_near(mixed[0] + mixed[1], Vector3(1.0, 1.0, 0.0), 0.000001, "diffusion must conserve optical density")
	_suite.expect_vector3_near(ColorTransport2D.srgb_to_optical_density(Color.WHITE), Vector3.ZERO, 0.000001, "white transmittance must have zero absorption")
	var black_optical := ColorTransport2D.srgb_to_optical_density(Color.BLACK)
	_suite.expect_true(is_finite(black_optical.x) and is_finite(black_optical.y) and is_finite(black_optical.z), "black conversion must remain finite")
	var black_output := ColorTransport2D.optical_density_to_srgb(black_optical)
