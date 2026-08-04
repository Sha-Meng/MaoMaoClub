extends RefCounted
class_name ContainerSnapshot2D

var shape: ContainerShape2D
var world_transform: Transform2D = Transform2D.IDENTITY
var linear_velocity_meters_per_second: Vector2 = Vector2.ZERO
var angular_velocity_radians_per_second: float = 0.0
var linear_acceleration_meters_per_second_squared: Vector2 = Vector2.ZERO
var angular_acceleration_radians_per_second_squared: float = 0.0

func point_velocity_world(local_point_meters: Vector2) -> Vector2:
	var world_offset := world_transform.basis_xform(local_point_meters)
	var angular_velocity := Vector2(
		-angular_velocity_radians_per_second * world_offset.y,
		angular_velocity_radians_per_second * world_offset.x
	)
	return linear_velocity_meters_per_second + angular_velocity

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if shape == null:
		errors.append("container shape is required")
	else:
		errors.append_array(shape.validate())
	if not _vector_is_finite(linear_velocity_meters_per_second):
		errors.append("container linear velocity must be finite")
	if not is_finite(angular_velocity_radians_per_second):
		errors.append("container angular velocity must be finite")
	if not _vector_is_finite(linear_acceleration_meters_per_second_squared):
		errors.append("container linear acceleration must be finite")
	if not is_finite(angular_acceleration_radians_per_second_squared):
		errors.append("container angular acceleration must be finite")
	return errors

func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
