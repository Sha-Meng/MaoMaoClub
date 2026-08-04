extends RefCounted
class_name BoundarySolver2D

static func make_world_samples(container: ContainerSnapshot2D, spacing: float) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if container == null or container.shape == null or spacing <= 0.0:
		return samples
	for index: int in range(container.shape.segment_count()):
		var start_local := container.shape.segment_starts_local_meters[index]
		var end_local := container.shape.segment_ends_local_meters[index]
		var length := start_local.distance_to(end_local)
		var divisions := maxi(1, ceili(length / spacing))
		for sample_index: int in range(divisions + 1):
			var local_point := start_local.lerp(end_local, float(sample_index) / float(divisions))
			samples.append(container.world_transform * local_point)
	return samples

static func constrain_particle(
	old_position: Vector2,
	predicted_position: Vector2,
	velocity: Vector2,
	mass: float,
	particle_radius: float,
	container: ContainerSnapshot2D,
	restitution: float,
	friction: float
) -> Dictionary:
	var corrected_position := predicted_position
	var corrected_velocity := velocity
	var total_particle_impulse := Vector2.ZERO
	var total_container_torque_impulse := 0.0
	if container == null or container.shape == null:
		return _make_result(corrected_position, corrected_velocity, total_particle_impulse, total_container_torque_impulse)
	for index: int in range(container.shape.segment_count()):
		var start_local := container.shape.segment_starts_local_meters[index]
		var end_local := container.shape.segment_ends_local_meters[index]
		var start_world := container.world_transform * start_local
		var end_world := container.world_transform * end_local
		var normal_world := container.world_transform.basis_xform(container.shape.inward_normals_local[index]).normalized()
		var closest := _closest_point_on_segment(corrected_position, start_world, end_world)
		var signed_distance := (corrected_position - closest).dot(normal_world)
		var intersection: Variant = Geometry2D.segment_intersects_segment(old_position, corrected_position, start_world, end_world)
		var near_segment := corrected_position.distance_to(closest) <= particle_radius * 1.5
		if intersection == null and (signed_distance >= particle_radius or not near_segment):
			continue
		var contact_world: Vector2 = intersection if intersection != null else closest
		var segment_direction := end_world - start_world
		var segment_length_squared := segment_direction.length_squared()
		var local_t := 0.0
		if segment_length_squared > 0.000001:
			local_t = clampf((contact_world - start_world).dot(segment_direction) / segment_length_squared, 0.0, 1.0)
		var contact_local := start_local.lerp(end_local, local_t)
		corrected_position += normal_world * (particle_radius - signed_distance + 0.00001)
		var wall_velocity := container.point_velocity_world(contact_local)
		var relative_velocity := corrected_velocity - wall_velocity
		var normal_speed := relative_velocity.dot(normal_world)
		var previous_velocity := corrected_velocity
		if normal_speed < 0.0:
			relative_velocity -= (1.0 + restitution) * normal_speed * normal_world
		var tangent_velocity := relative_velocity - relative_velocity.dot(normal_world) * normal_world
		relative_velocity -= tangent_velocity * clampf(friction, 0.0, 1.0)
		corrected_velocity = wall_velocity + relative_velocity
		var particle_impulse := mass * (corrected_velocity - previous_velocity)
		total_particle_impulse += particle_impulse
		total_container_torque_impulse += (contact_world - container.world_transform.origin).cross(-particle_impulse)
	return _make_result(corrected_position, corrected_velocity, total_particle_impulse, total_container_torque_impulse)

static func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var direction := end - start
	var length_squared := direction.length_squared()
	if length_squared <= 0.000001:
		return start
	var ratio := clampf((point - start).dot(direction) / length_squared, 0.0, 1.0)
	return start + direction * ratio

static func _make_result(position: Vector2, velocity: Vector2, impulse: Vector2, torque_impulse: float) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"particle_impulse": impulse,
		"container_torque_impulse": torque_impulse,
	}
