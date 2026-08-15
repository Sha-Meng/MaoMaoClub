extends Resource
class_name ShakerIceConfig2D

@export_category("Population")
@export var enabled: bool = true
@export_range(0, 12, 1) var maximum_count: int = 3
@export var size_meters: Vector2 = Vector2(0.16, 0.11)
@export_range(1.0, 2000.0, 1.0, "or_greater") var density_kg_per_cubic_meter: float = 917.0

@export_category("Fluid Interaction")
@export_range(0.001, 0.2, 0.001, "or_greater") var sample_spacing_meters: float = 0.055
@export_range(0.0, 20.0, 0.05, "or_greater") var drag_coefficient: float = 3.6
@export_range(0.1, 10000.0, 0.1, "or_greater") var maximum_fluid_force: float = 14.0

@export_category("Rigid Body")
@export_range(0.0, 20.0, 0.01, "or_greater") var linear_damp_per_second: float = 0.12
@export_range(0.0, 20.0, 0.01, "or_greater") var angular_damp_per_second: float = 0.18
@export_range(0.0, 1.0, 0.01) var collision_friction: float = 0.08
@export_range(0.0, 1.0, 0.01) var collision_bounce: float = 0.24
@export_range(0.0, 1.0, 0.01) var containment_restitution: float = 0.38
@export_range(0.0, 1.0, 0.01) var containment_tangent_retention: float = 0.94

@export_category("Spawn And Look")
@export_range(0.0, 0.5, 0.005, "or_greater") var gap_meters: float = 0.035
@export var color: Color = Color(0.72, 0.91, 1.0, 0.92)
@export var outline_color: Color = Color(0.90, 0.98, 1.0, 1.0)

@export_category("Collision")
@export_flags_2d_physics var collision_layer: int = 2
@export_flags_2d_physics var collision_mask: int = 3


func mass_kilograms(effective_depth_meters: float) -> float:
	return size_meters.x * size_meters.y * effective_depth_meters * density_kg_per_cubic_meter


func validate(effective_depth_meters: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if maximum_count < 0:
		errors.append("maximum_count must be non-negative")
	if size_meters.x <= 0.0 or size_meters.y <= 0.0 or not is_finite(size_meters.x) or not is_finite(size_meters.y):
		errors.append("size_meters must be finite and positive")
	if density_kg_per_cubic_meter <= 0.0 or not is_finite(density_kg_per_cubic_meter):
		errors.append("density_kg_per_cubic_meter must be finite and positive")
	if sample_spacing_meters <= 0.0 or not is_finite(sample_spacing_meters):
		errors.append("sample_spacing_meters must be finite and positive")
	if drag_coefficient < 0.0 or not is_finite(drag_coefficient):
		errors.append("drag_coefficient must be finite and non-negative")
	if maximum_fluid_force <= 0.0 or not is_finite(maximum_fluid_force):
		errors.append("maximum_fluid_force must be finite and positive")
	_require_non_negative(errors, "linear_damp_per_second", linear_damp_per_second)
	_require_non_negative(errors, "angular_damp_per_second", angular_damp_per_second)
	_require_unit_interval(errors, "collision_friction", collision_friction)
	_require_unit_interval(errors, "collision_bounce", collision_bounce)
	_require_unit_interval(errors, "containment_restitution", containment_restitution)
	_require_unit_interval(errors, "containment_tangent_retention", containment_tangent_retention)
	if collision_layer <= 0:
		errors.append("collision_layer must include at least one physics layer")
	if collision_mask <= 0:
		errors.append("collision_mask must include at least one physics layer")
	if effective_depth_meters <= 0.0 or not is_finite(effective_depth_meters):
		errors.append("effective_depth_meters must be finite and positive")
	return errors


func _require_non_negative(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value < 0.0:
		errors.append("%s must be finite and non-negative" % field_name)


func _require_unit_interval(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value < 0.0 or value > 1.0:
		errors.append("%s must be between 0 and 1" % field_name)
