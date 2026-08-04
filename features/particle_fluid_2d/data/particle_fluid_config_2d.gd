extends Resource
class_name ParticleFluidConfig2D

@export_category("Units")
@export var pixels_per_meter: float = 100.0
@export var effective_depth_meters: float = 0.1

@export_category("SPH")
@export var rest_density: float = 1000.0
@export var particle_mass: float = 0.02
@export var smoothing_radius_meters: float = 0.045
@export var gas_stiffness: float = 1800.0
@export_range(2.0, 12.0, 0.5) var tait_exponent: float = 7.0
@export var speed_of_sound: float = 8.0
@export var dynamic_viscosity: float = 0.18
@export var gravity_meters_per_second_squared: Vector2 = Vector2(0.0, 9.81)

@export_category("Stepping")
@export_range(1, 16, 1) var max_substeps: int = 8
@export var min_substep_seconds: float = 0.00025
@export var cfl_factor: float = 0.25
@export var fixed_test_substeps: int = 0
@export var enable_step_profiling: bool = false
@export var max_speed_meters_per_second: float = 30.0
@export var density_error_warning_ratio: float = 0.2

@export_category("Mixing")
@export var color_diffusion: float = 0.08
@export var optical_path_length: float = 1.0

@export_category("Boundary")
@export_range(0.0, 1.0, 0.01) var boundary_restitution: float = 0.05
@export_range(0.0, 1.0, 0.01) var boundary_friction: float = 0.2
@export var boundary_particle_spacing_ratio: float = 0.65
@export var enable_container_reaction: bool = false

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_require_positive_finite(errors, "pixels_per_meter", pixels_per_meter)
	_require_positive_finite(errors, "effective_depth_meters", effective_depth_meters)
	_require_positive_finite(errors, "rest_density", rest_density)
	_require_positive_finite(errors, "particle_mass", particle_mass)
	_require_positive_finite(errors, "smoothing_radius_meters", smoothing_radius_meters)
	_require_positive_finite(errors, "gas_stiffness", gas_stiffness)
	if not is_finite(tait_exponent) or tait_exponent <= 1.0:
		errors.append("tait_exponent must be finite and greater than one")
	_require_positive_finite(errors, "speed_of_sound", speed_of_sound)
	if not is_finite(gravity_meters_per_second_squared.x) or not is_finite(gravity_meters_per_second_squared.y):
		errors.append("gravity must be finite")
	if not is_finite(dynamic_viscosity) or dynamic_viscosity < 0.0:
		errors.append("dynamic_viscosity must be finite and non-negative")
	if max_substeps < 1:
		errors.append("max_substeps must be at least 1")
	_require_positive_finite(errors, "min_substep_seconds", min_substep_seconds)
	if not is_finite(cfl_factor) or cfl_factor <= 0.0 or cfl_factor > 1.0:
		errors.append("cfl_factor must be in (0, 1]")
	if fixed_test_substeps < 0:
		errors.append("fixed_test_substeps must be non-negative")
	_require_positive_finite(errors, "max_speed_meters_per_second", max_speed_meters_per_second)
	if not is_finite(density_error_warning_ratio) or density_error_warning_ratio <= 0.0:
		errors.append("density_error_warning_ratio must be finite and positive")
	if not is_finite(color_diffusion) or color_diffusion < 0.0:
		errors.append("color_diffusion must be finite and non-negative")
	_require_positive_finite(errors, "optical_path_length", optical_path_length)
	if not is_finite(boundary_particle_spacing_ratio) or boundary_particle_spacing_ratio <= 0.0:
		errors.append("boundary_particle_spacing_ratio must be positive")
	if not is_finite(boundary_restitution) or boundary_restitution < 0.0 or boundary_restitution > 1.0:
		errors.append("boundary_restitution must be in [0, 1]")
	if not is_finite(boundary_friction) or boundary_friction < 0.0 or boundary_friction > 1.0:
		errors.append("boundary_friction must be in [0, 1]")
	return errors

func meters_to_pixels(value: float) -> float:
	return value * pixels_per_meter

func pixels_to_meters(value: float) -> float:
	return value / pixels_per_meter

func vector_pixels_to_meters(value: Vector2) -> Vector2:
	return value / pixels_per_meter

func vector_meters_to_pixels(value: Vector2) -> Vector2:
	return value * pixels_per_meter

func _require_positive_finite(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and positive" % field_name)
