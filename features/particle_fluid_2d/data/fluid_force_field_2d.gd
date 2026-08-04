extends RefCounted
class_name FluidForceField2D

enum FieldType {
	UNIFORM,
	RADIAL,
}

var field_id: StringName = &"force"
var field_type: int = FieldType.UNIFORM
var acceleration: Vector2 = Vector2.ZERO
var center_meters: Vector2 = Vector2.ZERO
var radius_meters: float = 1.0
var remaining_seconds: float = INF

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if field_type < FieldType.UNIFORM or field_type > FieldType.RADIAL:
		errors.append("unsupported force field type")
	if not is_finite(acceleration.x) or not is_finite(acceleration.y):
		errors.append("force field acceleration must be finite")
	if not is_finite(center_meters.x) or not is_finite(center_meters.y):
		errors.append("force field center must be finite")
	if field_type == FieldType.RADIAL and (not is_finite(radius_meters) or radius_meters <= 0.0):
		errors.append("radial force field radius must be finite and positive")
	if is_nan(remaining_seconds) or remaining_seconds < 0.0:
		errors.append("force field lifetime must be non-negative or infinite")
	return errors

func sample_acceleration(position_meters: Vector2) -> Vector2:
	if field_type == FieldType.UNIFORM:
		return acceleration
	var offset := position_meters - center_meters
	var distance := offset.length()
	if distance <= 0.000001 or distance >= radius_meters:
		return Vector2.ZERO
	return acceleration * (1.0 - distance / radius_meters)

func advance_lifetime(delta_seconds: float) -> void:
	if is_finite(remaining_seconds):
		remaining_seconds = maxf(0.0, remaining_seconds - delta_seconds)

func is_expired() -> bool:
	return is_finite(remaining_seconds) and remaining_seconds <= 0.0
