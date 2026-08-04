extends Resource
class_name FluidMaterial2D

@export var display_color_srgb: Color = Color(0.25, 0.65, 1.0, 0.8)
@export var concentration: float = 1.0
@export var turbidity: float = 0.35
@export var density_multiplier: float = 1.0
@export var viscosity_multiplier: float = 1.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(concentration) or concentration < 0.0:
		errors.append("concentration must be finite and non-negative")
	if not is_finite(turbidity) or turbidity < 0.0:
		errors.append("turbidity must be finite and non-negative")
	if not is_finite(density_multiplier) or density_multiplier <= 0.0:
		errors.append("density_multiplier must be finite and positive")
	if not is_finite(viscosity_multiplier) or viscosity_multiplier <= 0.0:
		errors.append("viscosity_multiplier must be finite and positive")
	return errors
