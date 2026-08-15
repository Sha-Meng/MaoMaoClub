extends Resource
class_name ShakerMotionConfig2D

@export_category("Mouse Shake")
@export_range(0.05, 8.0, 0.05, "or_greater") var mouse_sensitivity: float = 1.15
@export var maximum_offset_pixels: Vector2 = Vector2(135.0, 90.0)
@export_range(0.0, 1.4, 0.01, "or_greater") var maximum_rotation_radians: float = 0.28
@export_range(0.1, 60.0, 0.1, "or_greater") var follow_speed_per_second: float = 18.0
@export_range(0.1, 60.0, 0.1, "or_greater") var release_return_speed_per_second: float = 8.0
@export_range(0.1, 60.0, 0.1, "or_greater") var reset_speed_per_second: float = 22.0

@export_category("Input")
@export var require_left_mouse_button: bool = true

@export_category("Post-Shake Settling")
@export_range(0.0, 5.0, 0.05, "or_greater") var settling_duration_seconds: float = 1.6
@export_range(0.0, 80.0, 0.1, "or_greater") var settling_fluid_damping_per_second: float = 24.0
@export_range(0.0, 2.0, 0.005, "or_greater") var settling_fluid_stop_speed_meters_per_second: float = 0.035
@export_range(0.0, 80.0, 0.1, "or_greater") var settling_ice_linear_damping_per_second: float = 32.0
@export_range(0.0, 80.0, 0.1, "or_greater") var settling_ice_angular_damping_per_second: float = 24.0
@export_range(0.0, 100.0, 0.5, "or_greater") var settling_ice_stop_speed_pixels_per_second: float = 2.0
@export_range(0.0, 10.0, 0.05, "or_greater") var settling_ice_stop_angular_speed: float = 0.08


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_require_positive(errors, "mouse_sensitivity", mouse_sensitivity)
	if not is_finite(maximum_offset_pixels.x) or not is_finite(maximum_offset_pixels.y) or maximum_offset_pixels.x <= 0.0 or maximum_offset_pixels.y <= 0.0:
		errors.append("maximum_offset_pixels must be finite and positive")
	_require_non_negative(errors, "maximum_rotation_radians", maximum_rotation_radians)
	_require_positive(errors, "follow_speed_per_second", follow_speed_per_second)
	_require_positive(errors, "release_return_speed_per_second", release_return_speed_per_second)
	_require_positive(errors, "reset_speed_per_second", reset_speed_per_second)
	_require_non_negative(errors, "settling_duration_seconds", settling_duration_seconds)
	_require_non_negative(errors, "settling_fluid_damping_per_second", settling_fluid_damping_per_second)
	_require_non_negative(errors, "settling_fluid_stop_speed_meters_per_second", settling_fluid_stop_speed_meters_per_second)
	_require_non_negative(errors, "settling_ice_linear_damping_per_second", settling_ice_linear_damping_per_second)
	_require_non_negative(errors, "settling_ice_angular_damping_per_second", settling_ice_angular_damping_per_second)
	_require_non_negative(errors, "settling_ice_stop_speed_pixels_per_second", settling_ice_stop_speed_pixels_per_second)
	_require_non_negative(errors, "settling_ice_stop_angular_speed", settling_ice_stop_angular_speed)
	return errors


func clamp_offset(value: Vector2) -> Vector2:
	return Vector2(
		clampf(value.x, -maximum_offset_pixels.x, maximum_offset_pixels.x),
		clampf(value.y, -maximum_offset_pixels.y, maximum_offset_pixels.y)
	)


func rotation_for_offset(value: Vector2) -> float:
	if maximum_offset_pixels.x <= 0.0:
		return 0.0
	return clampf(
		value.x / maximum_offset_pixels.x * maximum_rotation_radians,
		-maximum_rotation_radians,
		maximum_rotation_radians
	)


func _require_positive(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and positive" % field_name)


func _require_non_negative(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value < 0.0:
		errors.append("%s must be finite and non-negative" % field_name)
