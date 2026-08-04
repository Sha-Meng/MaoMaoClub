extends RefCounted
class_name ParticleFluidBuoyancyTests

var _suite: ParticleFluidTestSuite2D

func run(suite: ParticleFluidTestSuite2D) -> void:
	_suite = suite
	_suite.run_case("buoyant shape sample area", _test_sample_area)
	_suite.run_case("buoyant body validation", _test_invalid_body)
	_suite.run_case("Archimedes full submersion", _test_archimedes)
	_suite.run_case("buoyancy reaction momentum", _test_reaction)

func _test_sample_area() -> void:
	for shape_type: int in [
		BuoyantBodyShape2D.ShapeType.CIRCLE,
		BuoyantBodyShape2D.ShapeType.RECTANGLE,
		BuoyantBodyShape2D.ShapeType.CONVEX_POLYGON,
	]:
		var shape := BuoyantBodyShape2D.new()
		shape.shape_type = shape_type
		shape.radius_meters = 0.1
		shape.size_meters = Vector2(0.2, 0.1)
		shape.polygon_points_meters = PackedVector2Array([
			Vector2(-0.1, -0.05),
			Vector2(0.1, -0.05),
			Vector2(0.1, 0.05),
			Vector2(-0.1, 0.05),
		])
		var samples := shape.make_weighted_samples()
		var area_sum := 0.0
		var weighted_centroid := Vector2.ZERO
		var points: PackedVector2Array = samples["points"]
		var areas: PackedFloat32Array = samples["areas"]
		for sample_index: int in range(points.size()):
			area_sum += areas[sample_index]
			weighted_centroid += points[sample_index] * areas[sample_index]
		weighted_centroid /= area_sum
		_suite.expect_near(area_sum, shape.area_meters_squared(), 0.00001, "sample weights must sum to analytic area")
		_suite.expect_vector_near(weighted_centroid, Vector2.ZERO, 0.01, "uniform samples must preserve analytic centroid")

func _test_invalid_body() -> void:
	var body := _make_body()
	body.mass_kilograms = 0.0
	_suite.expect_true(not body.validate().is_empty(), "zero-mass body must be rejected")
	body = _make_body()
	body.center_of_mass_local_meters = Vector2(NAN, 0.0)
	_suite.expect_true(not body.validate().is_empty(), "non-finite center of mass must be rejected")
	var concave := BuoyantBodyShape2D.new()
	concave.shape_type = BuoyantBodyShape2D.ShapeType.CONVEX_POLYGON
	concave.polygon_points_meters = PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.2, 0.2), Vector2(0.0, 1.0)])

func _make_fluid() -> Dictionary:
	var config := ParticleFluidConfig2D.new()
	config.smoothing_radius_meters = 0.12
	config.effective_depth_meters = 0.1
	config.rest_density = 1000.0
	var state := ParticleFluidState2D.new()
	var batch := ParticleSpawnBatch2D.new()
	for y_index: int in range(7):
		for x_index: int in range(7):
			batch.positions_meters.append(Vector2(-0.09 + x_index * 0.03, -0.09 + y_index * 0.03))
			batch.masses.append(config.rest_density * config.effective_depth_meters * 0.03 * 0.03)
	state.add_batch(batch, config)
	var spatial_hash := SpatialHash2D.new()
	spatial_hash.configure(config.smoothing_radius_meters)
	spatial_hash.build(state.positions)
	return {"config": config, "state": state, "hash": spatial_hash}

func _make_body() -> BuoyantBodySnapshot2D:
	var shape := BuoyantBodyShape2D.new()
	shape.shape_type = BuoyantBodyShape2D.ShapeType.RECTANGLE
	shape.size_meters = Vector2(0.08, 0.05)
	shape.sample_spacing_meters = 0.02
	var body := BuoyantBodySnapshot2D.new()
	body.body_id = 1
	body.shape = shape
	body.mass_kilograms = 0.2
	body.moment_of_inertia = 0.001
	body.effective_depth_meters = 0.1
	body.drag_coefficient = 0.0
	return body

func _test_archimedes() -> void:
	var fixture := _make_fluid()
	var result := BuoyancySolver2D.solve(_make_body(), fixture["state"], fixture["hash"], fixture["config"], 0.001)
	var expected_force: float = fixture["config"].rest_density * 0.08 * 0.05 * 0.1 * 9.81
	_suite.expect_near(absf(Vector2(result["force"]).y), expected_force, expected_force * 0.35, "fully immersed buoyancy must approximate displaced fluid weight")

func _test_reaction() -> void:
	var fixture := _make_fluid()
	var state: ParticleFluidState2D = fixture["state"]
	var momentum_before := Vector2.ZERO
	for index: int in range(state.count()):
		momentum_before += state.masses[index] * state.velocities[index]
	var result := BuoyancySolver2D.solve(_make_body(), state, fixture["hash"], fixture["config"], 0.001)
	var momentum_after := Vector2.ZERO
	for index: int in range(state.count()):
		momentum_after += state.masses[index] * state.velocities[index]
	_suite.expect_vector_near(momentum_after - momentum_before, -Vector2(result["force"]) * 0.001, 0.0005, "particle reaction impulse must oppose body force")
