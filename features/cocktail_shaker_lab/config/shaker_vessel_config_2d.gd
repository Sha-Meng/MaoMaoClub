extends Resource
class_name ShakerVesselConfig2D

@export_category("Geometry")
@export_range(0.2, 3.0, 0.01, "or_greater") var width_meters: float = 0.72
@export_range(0.4, 5.0, 0.01, "or_greater") var height_meters: float = 1.30
@export_range(2.0, 40.0, 1.0, "or_greater") var wall_thickness_pixels: float = 12.0
@export var lid_enabled: bool = false

@export_category("Placement")
@export var home_position_pixels: Vector2 = Vector2(760.0, 150.0)
@export_range(0.0, 400.0, 1.0, "or_greater") var manual_horizontal_limit_pixels: float = 135.0

@export_category("Collision")
@export_flags_2d_physics var collision_layer: int = 1
@export_flags_2d_physics var collision_mask: int = 2


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(width_meters) or width_meters <= 0.0:
		errors.append("width_meters must be finite and positive")
	if not is_finite(height_meters) or height_meters <= 0.0:
		errors.append("height_meters must be finite and positive")
	if not is_finite(wall_thickness_pixels) or wall_thickness_pixels <= 0.0:
		errors.append("wall_thickness_pixels must be finite and positive")
	if manual_horizontal_limit_pixels < 0.0 or not is_finite(manual_horizontal_limit_pixels):
		errors.append("manual_horizontal_limit_pixels must be finite and non-negative")
	return errors
