extends RefCounted
class_name ParticleFluidRenderingTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("optical field renderer consumes immutable snapshots", _test_optical_field_snapshot)

func _test_optical_field_snapshot() -> void:
	var snapshot := ParticleFluidSnapshot2D.new()
	snapshot.ids = PackedInt32Array([1, 2])
	snapshot.positions_meters = PackedVector2Array([Vector2(1.0, 1.0), Vector2(1.2, 1.1)])
	snapshot.velocities_meters_per_second = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	snapshot.densities = PackedFloat32Array([1000.0, 1000.0])
	snapshot.pressures = PackedFloat32Array([0.0, 0.0])
	snapshot.material_ids = PackedInt32Array([1, 2])
	snapshot.target_rest_densities = PackedFloat32Array([1000.0, 1050.0])
	snapshot.optical_densities = PackedVector3Array([Vector3(0.2, 0.4, 0.8), Vector3(0.8, 0.3, 0.1)])
	snapshot.turbidities = PackedFloat32Array([0.3, 0.9])
	snapshot.refractive_strengths = PackedFloat32Array([0.2, 0.7])
	snapshot.specular_strengths = PackedFloat32Array([0.4, 0.8])
	snapshot.display_colors_srgb = PackedColorArray([Color.RED, Color.BLUE])
	var before := snapshot.duplicate_snapshot()
	var renderer := OpticalFluidRenderer2D.new()
	renderer.field_resolution = Vector2i(32, 48)
	renderer.particle_diameter_pixels = 12.0
	renderer.update_snapshot(snapshot, 100.0, Rect2(80.0, 70.0, 80.0, 100.0))
	_suite.expect_equal(renderer.get_active_instance_count(), 2, "optical renderer must batch every visible particle")
	_suite.expect_true(renderer.get_render_bounds_world_pixels().size.x > 80.0, "optical renderer must pad explicit bounds")
	_suite.expect_vector_near(snapshot.positions_meters[0], before.positions_meters[0], 0.0, "renderer must not mutate particle positions")
	_suite.expect_vector3_near(snapshot.optical_densities[1], before.optical_densities[1], 0.0, "renderer must not mutate optical state")
	renderer.update_snapshot(ParticleFluidSnapshot2D.new(), 100.0)
	_suite.expect_equal(renderer.get_active_instance_count(), 0, "empty snapshot must hide all optical instances")
	renderer.free()
