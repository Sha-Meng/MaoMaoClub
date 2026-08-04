extends RefCounted
class_name BuoyancySolver2D

static func solve(
	body: BuoyantBodySnapshot2D,
	state: ParticleFluidState2D,
	spatial_hash: SpatialHash2D,
	config: ParticleFluidConfig2D,
	delta_seconds: float
) -> Dictionary:
	var total_force := Vector2.ZERO
	var total_torque := 0.0
	var submersion_sum := 0.0
	var weighted_samples := body.shape.make_weighted_samples()
	var points: PackedVector2Array = weighted_samples["points"]
	var areas: PackedFloat32Array = weighted_samples["areas"]
	for sample_index: int in range(points.size()):
		var local_point := points[sample_index]
		var world_point := body.world_transform * local_point
		var neighbors := spatial_hash.query_indices(world_point, config.smoothing_radius_meters, state.positions)
		if neighbors.is_empty():
			continue
		var density := 0.0
		var fluid_velocity := Vector2.ZERO
		var weight_sum := 0.0
		for particle_index: int in neighbors:
			var distance := world_point.distance_to(state.positions[particle_index])
			var weight := SphKernels2D.density_poly6(distance, config.smoothing_radius_meters)
			density += state.masses[particle_index] * weight / config.effective_depth_meters
			fluid_velocity += state.velocities[particle_index] * weight
			weight_sum += weight
		if weight_sum > 0.0:
			fluid_velocity /= weight_sum
		var coverage := smoothstep(config.rest_density * 0.1, config.rest_density * 0.8, density)
		if coverage <= 0.0:
			continue
		submersion_sum += coverage
		var displaced_volume := areas[sample_index] * body.effective_depth_meters * coverage
		var effective_density := clampf(density, 0.0, config.rest_density * 1.2)
		var buoyancy_force := -config.gravity_meters_per_second_squared * effective_density * displaced_volume
		var relative_velocity := fluid_velocity - body.point_velocity_world(local_point)
		var drag_force := relative_velocity * body.drag_coefficient * effective_density * displaced_volume
		var sample_force := buoyancy_force + drag_force
		if sample_force.length() > body.maximum_fluid_force:
			sample_force = sample_force.normalized() * body.maximum_fluid_force
		total_force += sample_force
		var lever_arm := world_point - body.world_transform * body.center_of_mass_local_meters
		total_torque += lever_arm.cross(sample_force)
		_apply_reaction_impulse(state, neighbors, world_point, -sample_force * delta_seconds, config)
	return {
		"force": total_force,
		"torque": total_torque,
		"submersion_ratio": submersion_sum / float(maxi(1, points.size())),
	}

static func _apply_reaction_impulse(
	state: ParticleFluidState2D,
	neighbors: PackedInt32Array,
	world_point: Vector2,
	total_impulse: Vector2,
	config: ParticleFluidConfig2D
) -> void:
	var weights := PackedFloat32Array()
	var weight_sum := 0.0
	for particle_index: int in neighbors:
		var weight := SphKernels2D.density_poly6(
			world_point.distance_to(state.positions[particle_index]),
			config.smoothing_radius_meters
		)
		weights.append(weight)
		weight_sum += weight
	if weight_sum <= 0.0:
		return
	for neighbor_offset: int in range(neighbors.size()):
		var particle_index := neighbors[neighbor_offset]
		var impulse := total_impulse * weights[neighbor_offset] / weight_sum
		state.velocities[particle_index] += impulse / state.masses[particle_index]
