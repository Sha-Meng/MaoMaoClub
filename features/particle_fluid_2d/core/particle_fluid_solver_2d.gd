extends RefCounted
class_name ParticleFluidSolver2D

var _config: ParticleFluidConfig2D
var _state: ParticleFluidState2D = ParticleFluidState2D.new()
var _spatial_hash: SpatialHash2D = SpatialHash2D.new()
var _boundary_spatial_hash: SpatialHash2D = SpatialHash2D.new()
var _container: ContainerSnapshot2D
var _external_acceleration: Vector2 = Vector2.ZERO
var _force_fields: Array[FluidForceField2D] = []
var _buoyant_bodies: Array[BuoyantBodySnapshot2D] = []
var _configured: bool = false
var _materials_by_id: Dictionary = {}
var _uses_material_physics: bool = false
var _last_neighbor_total: int = 0
var _neighbor_cache: Array[PackedInt32Array] = []
var _profile_spatial_hash_usec: int = 0
var _profile_density_usec: int = 0
var _profile_forces_usec: int = 0
var _profile_integration_usec: int = 0
var _quiescent_elapsed_seconds: float = 0.0
var _quiescent_damping_active: bool = false

func configure(new_config: ParticleFluidConfig2D) -> void:
	if new_config == null:
		push_error("ParticleFluidSolver2D requires a config")
		_configured = false
		return
	var errors := new_config.validate()
	if not errors.is_empty():
		push_error("Invalid particle fluid config: %s" % ", ".join(errors))
		_configured = false
		return
	_config = new_config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ParticleFluidConfig2D
	_external_acceleration = _config.gravity_meters_per_second_squared
	_spatial_hash.configure(_config.smoothing_radius_meters)
	_boundary_spatial_hash.configure(_config.smoothing_radius_meters)
	_configured = true
	_ensure_default_material()
	_refresh_material_physics_mode()
	_state.refresh_material_properties(_materials_by_id, _config)
	_quiescent_elapsed_seconds = 0.0
	_quiescent_damping_active = false

func is_configured() -> bool:
	return _configured

func configure_materials(materials: Array[FluidMaterial2D]) -> PackedStringArray:
	var errors := PackedStringArray()
	var candidates: Dictionary = {}
	for index: int in range(materials.size()):
		var material := materials[index]
		if material == null:
			errors.append("materials[%d] must not be null" % index)
			continue
		var material_errors := material.validate()
		for error: String in material_errors:
			errors.append("materials[%d]: %s" % [index, error])
		if candidates.has(material.material_id):
			errors.append("material_id %d is duplicated" % material.material_id)
		else:
			candidates[material.material_id] = material.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FluidMaterial2D
	if not errors.is_empty():
		return errors
	if not candidates.has(0):
		candidates[0] = FluidMaterial2D.new()
	_materials_by_id = candidates
	_refresh_material_physics_mode()
	if _configured:
		_state.refresh_material_properties(_materials_by_id, _config)
	return errors

func get_material(material_id: int) -> FluidMaterial2D:
	_ensure_default_material()
	var material := _materials_by_id.get(material_id, _materials_by_id[0]) as FluidMaterial2D
	return material.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FluidMaterial2D

func reset(_seed: int = 0) -> void:
	_state.clear()
	_force_fields.clear()
	_buoyant_bodies.clear()
	_neighbor_cache.clear()
	_boundary_spatial_hash.clear()
	_container = null
	_quiescent_elapsed_seconds = 0.0
	_quiescent_damping_active = false

func add_particles(batch: ParticleSpawnBatch2D) -> PackedInt32Array:
	if not _configured or batch == null:
		return PackedInt32Array()
	var errors := batch.validate(_config.particle_mass)
	if not errors.is_empty():
		push_error("Invalid particle batch: %s" % ", ".join(errors))
		return PackedInt32Array()
	var added_ids := _state.add_batch(batch, _config, _materials_by_id)
	if not added_ids.is_empty():
		wake()
	return added_ids

func remove_particles(particle_ids: PackedInt32Array) -> void:
	_state.remove_particles(particle_ids)
	if not particle_ids.is_empty():
		wake()

func set_container(container: ContainerSnapshot2D) -> void:
	if container != null and not container.validate().is_empty():
		push_error("Invalid container snapshot: %s" % ", ".join(container.validate()))
		return
	_container = container

func set_external_acceleration(value: Vector2) -> void:
	if is_finite(value.x) and is_finite(value.y):
		if not value.is_equal_approx(_external_acceleration):
			wake()
		_external_acceleration = value

func set_force_fields(fields: Array[FluidForceField2D]) -> void:
	_force_fields.clear()
	for field: FluidForceField2D in fields:
		if field != null and field.validate().is_empty() and not field.is_expired():
			_force_fields.append(field)
	if not _force_fields.is_empty():
		_quiescent_elapsed_seconds = 0.0
		_quiescent_damping_active = false

func set_buoyant_bodies(bodies: Array[BuoyantBodySnapshot2D]) -> void:
	_buoyant_bodies.clear()
	for body: BuoyantBodySnapshot2D in bodies:
		if body != null and body.validate().is_empty():
			_buoyant_bodies.append(body)

func wake() -> void:
	_quiescent_elapsed_seconds = 0.0
	_quiescent_damping_active = false

func is_quiescent_damping_active() -> bool:
	return _quiescent_damping_active


func apply_velocity_damping(
	damping_per_second: float,
	delta_seconds: float,
	stop_speed: float = 0.0
) -> void:
	if (
		not _configured
		or not is_finite(damping_per_second)
		or damping_per_second < 0.0
		or not is_finite(delta_seconds)
		or delta_seconds <= 0.0
		or not is_finite(stop_speed)
		or stop_speed < 0.0
	):
		return
	var damping_weight := exp(-damping_per_second * delta_seconds)
	for index: int in range(_state.count()):
		var velocity := _state.velocities[index] * damping_weight
		if velocity.length() <= stop_speed:
			velocity = Vector2.ZERO
		_state.velocities[index] = velocity

func step(delta_seconds: float) -> FluidStepResult2D:
	var result := FluidStepResult2D.new()
	if not _configured:
		result.warnings.append("solver is not configured")
		return result
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		result.warnings.append("delta_seconds must be finite and positive")
		return _finish_result(result, 0)
	if _state.count() == 0:
		return _finish_result(result, 0)
	_update_quiescent_state(delta_seconds)
	result.quiescent_damping_active = _quiescent_damping_active
	var substeps := _choose_substeps(delta_seconds, result)
	var substep_seconds := delta_seconds / float(substeps)
	var container_impulse := Vector2.ZERO
	var container_torque_impulse := 0.0
	var body_impulses: Dictionary = {}
	var body_torque_impulses: Dictionary = {}
	var body_submersion_sums: Dictionary = {}
	result.active_force_field_count = _force_fields.size()
	result.applied_buoyant_body_count = _buoyant_bodies.size()
	_last_neighbor_total = 0
	_profile_spatial_hash_usec = 0
	_profile_density_usec = 0
	_profile_forces_usec = 0
	_profile_integration_usec = 0
	for _substep: int in range(substeps):
		var reaction := _step_substep(substep_seconds)
		container_impulse += Vector2(reaction.get("impulse", Vector2.ZERO))
		container_torque_impulse += float(reaction.get("torque_impulse", 0.0))
		var substep_body_impulses: Dictionary = reaction.get("body_impulses", {})
		var substep_body_torques: Dictionary = reaction.get("body_torque_impulses", {})
		var substep_submersions: Dictionary = reaction.get("body_submersions", {})
		for body_id: int in substep_body_impulses:
			body_impulses[body_id] = Vector2(body_impulses.get(body_id, Vector2.ZERO)) + Vector2(substep_body_impulses[body_id])
			body_torque_impulses[body_id] = float(body_torque_impulses.get(body_id, 0.0)) + float(substep_body_torques.get(body_id, 0.0))
			body_submersion_sums[body_id] = float(body_submersion_sums.get(body_id, 0.0)) + float(substep_submersions.get(body_id, 0.0))
	for field: FluidForceField2D in _force_fields.duplicate():
		field.advance_lifetime(delta_seconds)
		if field.is_expired():
			_force_fields.erase(field)
	result.container_reaction_force = -container_impulse / delta_seconds if _config.enable_container_reaction else Vector2.ZERO
	result.container_reaction_torque = container_torque_impulse / delta_seconds if _config.enable_container_reaction else 0.0
	for body_id: int in body_impulses:
		result.body_forces[body_id] = Vector2(body_impulses[body_id]) / delta_seconds
		result.body_torques[body_id] = float(body_torque_impulses.get(body_id, 0.0)) / delta_seconds
		result.body_submersion_ratios[body_id] = float(body_submersion_sums.get(body_id, 0.0)) / float(substeps)
	return _finish_result(result, substeps)

func get_state_snapshot() -> ParticleFluidSnapshot2D:
	if not _configured:
		return ParticleFluidSnapshot2D.new()
	return _state.make_snapshot(_config.optical_path_length)


func enforce_closed_container_containment(container: ContainerSnapshot2D) -> ParticleFluidSnapshot2D:
	if not _configured or container == null or container.shape == null or not container.shape.is_closed:
		return get_state_snapshot()
	var particle_radius := _config.smoothing_radius_meters * 0.22
	for index: int in range(_state.count()):
		var constrained := BoundarySolver2D.constrain_particle(
			_state.positions[index],
			_state.positions[index],
			_state.velocities[index],
			_state.masses[index],
			particle_radius,
			container,
			_config.boundary_restitution,
			_config.boundary_friction
		)
		_state.positions[index] = Vector2(constrained["position"])
		_state.velocities[index] = Vector2(constrained["velocity"])
	_container = container
	return get_state_snapshot()

func _step_substep(delta_seconds: float) -> Dictionary:
	var phase_started_usec := Time.get_ticks_usec() if _config.enable_step_profiling else 0
	_spatial_hash.build(_state.positions)
	var boundary_samples := PackedVector2Array()
	if _container != null:
		boundary_samples = BoundarySolver2D.make_world_samples(
			_container,
			_config.smoothing_radius_meters * _config.boundary_particle_spacing_ratio
		)
	_boundary_spatial_hash.build(boundary_samples)
	if _config.enable_step_profiling:
		_profile_spatial_hash_usec += Time.get_ticks_usec() - phase_started_usec
		phase_started_usec = Time.get_ticks_usec()
	_compute_density_and_pressure(boundary_samples)
	if _config.enable_step_profiling:
		_profile_density_usec += Time.get_ticks_usec() - phase_started_usec
		phase_started_usec = Time.get_ticks_usec()
	_compute_accelerations_and_color(delta_seconds)
	var body_impulses: Dictionary = {}
	var body_torque_impulses: Dictionary = {}
	var body_submersions: Dictionary = {}
	for body: BuoyantBodySnapshot2D in _buoyant_bodies:
		var buoyancy := BuoyancySolver2D.solve(body, _state, _spatial_hash, _config, delta_seconds)
		body_impulses[body.body_id] = Vector2(buoyancy["force"]) * delta_seconds
		body_torque_impulses[body.body_id] = float(buoyancy["torque"]) * delta_seconds
		body_submersions[body.body_id] = float(buoyancy["submersion_ratio"])
	if _config.enable_step_profiling:
		_profile_forces_usec += Time.get_ticks_usec() - phase_started_usec
		phase_started_usec = Time.get_ticks_usec()
	var total_particle_impulse := Vector2.ZERO
	var total_container_torque_impulse := 0.0
	var particle_radius := _config.smoothing_radius_meters * 0.22
	for index: int in range(_state.count()):
		var old_position := _state.positions[index]
		var acceleration := _state.accelerations[index]
		if not _vector_is_finite(acceleration):
			acceleration = Vector2.ZERO
		var velocity := _state.velocities[index] + acceleration * delta_seconds
		if _quiescent_damping_active:
			velocity *= exp(-_config.quiescent_damping_per_second * delta_seconds)
			if velocity.length() <= _config.quiescent_stop_speed:
				velocity = Vector2.ZERO
		if velocity.length() > _config.max_speed_meters_per_second:
			velocity = velocity.normalized() * _config.max_speed_meters_per_second
		var predicted_position := old_position + velocity * delta_seconds
		if _container != null:
			var constrained := BoundarySolver2D.constrain_particle(
				old_position,
				predicted_position,
				velocity,
				_state.masses[index],
				particle_radius,
				_container,
				_config.boundary_restitution,
				_config.boundary_friction
			)
			predicted_position = Vector2(constrained["position"])
			velocity = Vector2(constrained["velocity"])
			total_particle_impulse += Vector2(constrained["particle_impulse"])
			total_container_torque_impulse += float(constrained["container_torque_impulse"])
		if not _vector_is_finite(velocity) or not _vector_is_finite(predicted_position):
			velocity = Vector2.ZERO
			predicted_position = old_position
		_state.velocities[index] = velocity
		_state.positions[index] = predicted_position
	if _config.enable_step_profiling:
		_profile_integration_usec += Time.get_ticks_usec() - phase_started_usec
	return {
		"impulse": total_particle_impulse,
		"torque_impulse": total_container_torque_impulse,
		"body_impulses": body_impulses,
		"body_torque_impulses": body_torque_impulses,
		"body_submersions": body_submersions,
	}

func _update_quiescent_state(delta_seconds: float) -> void:
	if _config.quiescent_damping_per_second <= 0.0 or not _is_quiescent_candidate():
		_quiescent_elapsed_seconds = 0.0
		_quiescent_damping_active = false
		return
	_quiescent_elapsed_seconds += delta_seconds
	_quiescent_damping_active = (
		_quiescent_elapsed_seconds >= _config.quiescent_activation_delay_seconds
	)

func _is_quiescent_candidate() -> bool:
	if not _force_fields.is_empty():
		return false
	if _container != null:
		if _container.linear_velocity_meters_per_second.length() > _config.quiescent_container_speed_threshold:
			return false
		if absf(_container.angular_velocity_radians_per_second) > _config.quiescent_container_speed_threshold:
			return false
		if _container.linear_acceleration_meters_per_second_squared.length() > _config.quiescent_container_acceleration_threshold:
			return false
		if absf(_container.angular_acceleration_radians_per_second_squared) > _config.quiescent_container_acceleration_threshold:
			return false
	for body: BuoyantBodySnapshot2D in _buoyant_bodies:
		if body.linear_velocity_meters_per_second.length() > _config.quiescent_buoyant_body_linear_speed_threshold:
			return false
		if absf(body.angular_velocity_radians_per_second) > _config.quiescent_buoyant_body_angular_speed_threshold:
			return false
	var speed_sum := 0.0
	for velocity: Vector2 in _state.velocities:
		speed_sum += velocity.length()
	var average_speed := speed_sum / float(maxi(_state.count(), 1))
	return average_speed <= _config.quiescent_max_average_speed

func _compute_density_and_pressure(boundary_samples: PackedVector2Array) -> void:
	if _uses_material_physics:
		_compute_material_density_and_pressure(boundary_samples)
	else:
		_compute_default_density_and_pressure(boundary_samples)

func _compute_default_density_and_pressure(boundary_samples: PackedVector2Array) -> void:
	var h := _config.smoothing_radius_meters
	_neighbor_cache.resize(_state.count())
	var boundary_spacing := h * _config.boundary_particle_spacing_ratio
	var boundary_mass := _config.rest_density * _config.effective_depth_meters * boundary_spacing * boundary_spacing
	for index: int in range(_state.count()):
		var density_sum := 0.0
		var neighbors := _spatial_hash.query_indices(_state.positions[index], h, _state.positions)
		_neighbor_cache[index] = neighbors
		_last_neighbor_total += neighbors.size()
		for neighbor_index: int in neighbors:
			var distance := _state.positions[index].distance_to(_state.positions[neighbor_index])
			density_sum += _state.masses[neighbor_index] * SphKernels2D.density_poly6(distance, h)
		var boundary_neighbors := _boundary_spatial_hash.query_indices(_state.positions[index], h, boundary_samples)
		for boundary_index: int in boundary_neighbors:
			var boundary_position := boundary_samples[boundary_index]
			var boundary_distance := _state.positions[index].distance_to(boundary_position)
			if boundary_distance < h:
				density_sum += boundary_mass * SphKernels2D.density_poly6(boundary_distance, h)
		var volumetric_density := density_sum / _config.effective_depth_meters
		_state.densities[index] = maxf(volumetric_density, _config.rest_density * 0.05)
		var density_ratio := _state.densities[index] / _config.rest_density
		var tait_compression := pow(density_ratio, _config.tait_exponent) - 1.0
		_state.pressures[index] = _config.gas_stiffness / _config.tait_exponent * maxf(tait_compression, 0.0)

func _compute_material_density_and_pressure(boundary_samples: PackedVector2Array) -> void:
	var h := _config.smoothing_radius_meters
	_neighbor_cache.resize(_state.count())
	var boundary_spacing := h * _config.boundary_particle_spacing_ratio
	for index: int in range(_state.count()):
		var density_sum := 0.0
		var neighbors := _spatial_hash.query_indices(_state.positions[index], h, _state.positions)
		_neighbor_cache[index] = neighbors
		_last_neighbor_total += neighbors.size()
		for neighbor_index: int in neighbors:
			var distance := _state.positions[index].distance_to(_state.positions[neighbor_index])
			density_sum += _state.masses[neighbor_index] * SphKernels2D.density_poly6(distance, h)
		var target_rest_density := _state.target_rest_densities[index]
		var boundary_mass := target_rest_density * _config.effective_depth_meters * boundary_spacing * boundary_spacing
		var boundary_neighbors := _boundary_spatial_hash.query_indices(_state.positions[index], h, boundary_samples)
		for boundary_index: int in boundary_neighbors:
			var boundary_position := boundary_samples[boundary_index]
			var boundary_distance := _state.positions[index].distance_to(boundary_position)
			if boundary_distance < h:
				density_sum += boundary_mass * SphKernels2D.density_poly6(boundary_distance, h)
		var volumetric_density := density_sum / _config.effective_depth_meters
		_state.densities[index] = maxf(volumetric_density, target_rest_density * 0.05)
		var density_ratio := _state.densities[index] / target_rest_density
		var tait_compression := pow(density_ratio, _config.tait_exponent) - 1.0
		_state.pressures[index] = (
			_config.gas_stiffness / _config.tait_exponent
			* maxf(tait_compression, 0.0)
		)

func _compute_accelerations_and_color(delta_seconds: float) -> void:
	for index: int in range(_state.count()):
		var acceleration := _external_acceleration
		for field: FluidForceField2D in _force_fields:
			acceleration += field.sample_acceleration(_state.positions[index])
		_state.accelerations[index] = acceleration
	if _uses_material_physics:
		_compute_material_interactions(delta_seconds)
	else:
		_compute_default_interactions(delta_seconds)

func _compute_default_interactions(delta_seconds: float) -> void:
	var h := _config.smoothing_radius_meters
	var kernel_at_zero := SphKernels2D.density_poly6(0.0, h)
	for first: int in range(_state.count()):
		var neighbors: PackedInt32Array = _neighbor_cache[first]
		for second: int in neighbors:
			if second <= first:
				continue
			var offset := _state.positions[first] - _state.positions[second]
			var distance := offset.length()
			if distance <= 0.000001 or distance >= h:
				continue
			var density_first := maxf(_state.densities[first], _config.rest_density * 0.05)
			var density_second := maxf(_state.densities[second], _config.rest_density * 0.05)
			var gradient := SphKernels2D.pressure_spiky_gradient(offset, h)
			var pressure_force := -_state.masses[first] * _state.masses[second] * (
				_state.pressures[first] / (density_first * density_first)
				+ _state.pressures[second] / (density_second * density_second)
			) * gradient / _config.effective_depth_meters
			_state.accelerations[first] += pressure_force / _state.masses[first]
			_state.accelerations[second] -= pressure_force / _state.masses[second]
			var laplacian := SphKernels2D.viscosity_laplacian(distance, h)
			var viscosity_force := _config.dynamic_viscosity * _state.masses[first] * _state.masses[second] * (
				_state.velocities[second] - _state.velocities[first]
			) * laplacian / (density_first * density_second * _config.effective_depth_meters)
			_state.accelerations[first] += viscosity_force / _state.masses[first]
			_state.accelerations[second] -= viscosity_force / _state.masses[second]
			if _config.color_diffusion > 0.0 and kernel_at_zero > 0.0:
				var weight := SphKernels2D.density_poly6(distance, h) / kernel_at_zero
				var mixed := ColorTransport2D.diffuse_pair(
					_state.optical_densities[first],
					_state.optical_densities[second],
					_config.color_diffusion * weight,
					delta_seconds
				)
				_state.optical_densities[first] = mixed[0]
				_state.optical_densities[second] = mixed[1]

func _compute_material_interactions(delta_seconds: float) -> void:
	var h := _config.smoothing_radius_meters
	var kernel_at_zero := SphKernels2D.density_poly6(0.0, h)
	for first: int in range(_state.count()):
		var neighbors: PackedInt32Array = _neighbor_cache[first]
		for second: int in neighbors:
			if second <= first:
				continue
			var offset := _state.positions[first] - _state.positions[second]
			var distance := offset.length()
			if distance <= 0.000001 or distance >= h:
				continue
			var density_first := maxf(_state.densities[first], _state.target_rest_densities[first] * 0.05)
			var density_second := maxf(_state.densities[second], _state.target_rest_densities[second] * 0.05)
			var gradient := SphKernels2D.pressure_spiky_gradient(offset, h)
			var pressure_force := -_state.masses[first] * _state.masses[second] * (
				_state.pressures[first] / (density_first * density_first)
				+ _state.pressures[second] / (density_second * density_second)
			) * gradient / _config.effective_depth_meters
			_state.accelerations[first] += pressure_force / _state.masses[first]
			_state.accelerations[second] -= pressure_force / _state.masses[second]
			var laplacian := SphKernels2D.viscosity_laplacian(distance, h)
			var pair_viscosity_multiplier := 0.5 * (
				_state.viscosity_multipliers[first] + _state.viscosity_multipliers[second]
			)
			var viscosity_force := _config.dynamic_viscosity * pair_viscosity_multiplier * _state.masses[first] * _state.masses[second] * (
				_state.velocities[second] - _state.velocities[first]
			) * laplacian / (density_first * density_second * _config.effective_depth_meters)
			_state.accelerations[first] += viscosity_force / _state.masses[first]
			_state.accelerations[second] -= viscosity_force / _state.masses[second]
			var pair_diffusion_multiplier := minf(_state.color_diffusion_multipliers[first], _state.color_diffusion_multipliers[second])
			var can_diffuse := _state.mixing_groups[first] == _state.mixing_groups[second]
			if _config.color_diffusion > 0.0 and pair_diffusion_multiplier > 0.0 and kernel_at_zero > 0.0 and can_diffuse:
				var weight := SphKernels2D.density_poly6(distance, h) / kernel_at_zero
				var mixed := ColorTransport2D.diffuse_pair(
					_state.optical_densities[first],
					_state.optical_densities[second],
					_config.color_diffusion * pair_diffusion_multiplier * weight,
					delta_seconds
				)
				_state.optical_densities[first] = mixed[0]
				_state.optical_densities[second] = mixed[1]

func _choose_substeps(delta_seconds: float, result: FluidStepResult2D) -> int:
	if _config.fixed_test_substeps > 0:
		return mini(_config.fixed_test_substeps, _config.max_substeps)
	var maximum_speed := 0.0
	if _uses_material_physics:
		for index: int in range(_state.count()):
			maximum_speed = maxf(maximum_speed, _state.velocities[index].length())
	else:
		for velocity: Vector2 in _state.velocities:
			maximum_speed = maxf(maximum_speed, velocity.length())
	var maximum_viscosity_multiplier := 1.0
	var minimum_target_density := _config.rest_density
	if _uses_material_physics:
		for index: int in range(_state.count()):
			maximum_viscosity_multiplier = maxf(maximum_viscosity_multiplier, _state.viscosity_multipliers[index])
			minimum_target_density = minf(minimum_target_density, _state.target_rest_densities[index])
	var cfl_step := _config.cfl_factor * _config.smoothing_radius_meters / (_config.speed_of_sound + maximum_speed)
	var acceleration_scale := maxf(_external_acceleration.length(), 0.000001)
	var acceleration_step := 0.25 * sqrt(_config.smoothing_radius_meters / acceleration_scale)
	var kinematic_viscosity := _config.dynamic_viscosity * maximum_viscosity_multiplier / minimum_target_density
	var viscosity_step := 0.125 * _config.smoothing_radius_meters * _config.smoothing_radius_meters / maxf(kinematic_viscosity, 0.000001)
	var stable_step := maxf(_config.min_substep_seconds, minf(cfl_step, minf(acceleration_step, viscosity_step)))
	var required := maxi(1, ceili(delta_seconds / stable_step))
	if required > _config.max_substeps:
		result.warnings.append("requested tick exceeds configured stable substep budget")
	return mini(required, _config.max_substeps)

func _finish_result(result: FluidStepResult2D, substeps: int) -> FluidStepResult2D:
	result.substeps = substeps
	result.snapshot = get_state_snapshot()
	result.particle_count = _state.count()
	result.applied_external_acceleration = _external_acceleration
	result.profile_spatial_hash_microseconds = _profile_spatial_hash_usec
	result.profile_density_microseconds = _profile_density_usec
	result.profile_forces_microseconds = _profile_forces_usec
	result.profile_integration_microseconds = _profile_integration_usec
	var density_error_sum := 0.0
	for index: int in range(_state.count()):
		var mass := _state.masses[index]
		var speed := _state.velocities[index].length()
		var target_rest_density := _state.target_rest_densities[index] if _uses_material_physics else _config.rest_density
		var density_error := absf(_state.densities[index] - target_rest_density) / target_rest_density
		result.total_mass += mass
		result.total_linear_momentum += mass * _state.velocities[index]
		result.kinetic_energy += 0.5 * mass * speed * speed
		result.maximum_speed = maxf(result.maximum_speed, speed)
		density_error_sum += density_error
		result.maximum_density_error_ratio = maxf(result.maximum_density_error_ratio, density_error)
		result.minimum_density = minf(result.minimum_density, _state.densities[index])
		if not _particle_is_finite(index):
			result.has_non_finite_state = true
	if _state.count() > 0:
		result.average_density_error_ratio = density_error_sum / float(_state.count())
		result.average_neighbor_count = float(_last_neighbor_total) / float(maxi(1, _state.count() * maxi(1, substeps)))
	if _state.count() == 0:
		result.minimum_density = 0.0
	if result.minimum_density > 0.0 and result.minimum_density < _config.rest_density * 0.1:
		result.warnings.append("particle density is near collapse threshold")
	if result.maximum_density_error_ratio > _config.density_error_warning_ratio:
		result.warnings.append("density error exceeds configured warning ratio")
	if result.has_non_finite_state:
		result.warnings.append("non-finite particle state detected")
	return result

func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

func _particle_is_finite(index: int) -> bool:
	var position := _state.positions[index]
	var velocity := _state.velocities[index]
	var optical := _state.optical_densities[index]
	return (
		is_finite(position.x)
		and is_finite(position.y)
		and is_finite(velocity.x)
		and is_finite(velocity.y)
		and is_finite(_state.densities[index])
		and is_finite(_state.pressures[index])
		and is_finite(_state.target_rest_densities[index])
		and is_finite(optical.x)
		and is_finite(optical.y)
		and is_finite(optical.z)
	)

func _ensure_default_material() -> void:
	if _materials_by_id.has(0):
		return
	var default_material := FluidMaterial2D.new()
	_materials_by_id[0] = default_material

func _refresh_material_physics_mode() -> void:
	_uses_material_physics = false
	for material_value: Variant in _materials_by_id.values():
		var material := material_value as FluidMaterial2D
		if material == null:
			continue
		if (
			not is_equal_approx(material.density_multiplier, 1.0)
			or not is_equal_approx(material.viscosity_multiplier, 1.0)
			or not is_equal_approx(material.color_diffusion_multiplier, 1.0)
			or material.mixing_group != 0
		):
			_uses_material_physics = true
			return
