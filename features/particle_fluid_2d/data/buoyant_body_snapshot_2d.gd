extends RefCounted
class_name BuoyantBodySnapshot2D

var body_id: int = 0
var shape: BuoyantBodyShape2D
var world_transform: Transform2D = Transform2D.IDENTITY
var linear_velocity_meters_per_second: Vector2 = Vector2.ZERO
var center_of_mass_local_meters: Vector2 = Vector2.ZERO
var angular_velocity_radians_per_second: float = 0.0
var mass_kilograms: float = 1.0
var moment_of_inertia: float = 1.0
var effective_depth_meters: float = 0.1
var drag_coefficient: float = 2.0
var maximum_fluid_force: float = 1000.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if body_id <= 0:
		errors.append("body_id must be positive")
	if shape == null:
		errors.append("buoyant body shape is required")
	else:
		errors.append_array(shape.validate())
	_require_positive(errors, "mass_kilograms", mass_kilograms)
	_require_positive(errors, "moment_of_inertia", moment_of_inertia)
	if not is_finite(center_of_mass_local_meters.x) or not is_finite(center_of_mass_local_meters.y):
		errors.append("center of mass must be finite")
	_require_positive(errors, "effective_depth_meters", effective_depth_meters)
	if not is_finite(drag_coefficient) or drag_coefficient < 0.0:
		errors.append("drag_coefficient must be finite and non-negative")
	_require_positive(errors, "maximum_fluid_force", maximum_fluid_force)
	return errors

func point_velocity_world(local_point_meters: Vector2) -> Vector2:
	var world_offset := world_transform.basis_xform(local_point_meters - center_of_mass_local_meters)
	return linear_velocity_meters_per_second + Vector2(
		-angular_velocity_radians_per_second * world_offset.y,
		angular_velocity_radians_per_second * world_offset.x
	)

func _require_positive(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and positive" % field_name)
