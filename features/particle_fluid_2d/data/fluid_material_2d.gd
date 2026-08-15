extends Resource
class_name FluidMaterial2D

@export_category("Identity")
@export var material_id: int = 0

@export_category("Spawn Defaults")
@export var display_color_srgb: Color = Color(0.25, 0.65, 1.0, 0.8)
@export var concentration: float = 1.0
@export var turbidity: float = 0.35

@export_category("Physical")
@export var density_multiplier: float = 1.0
@export var viscosity_multiplier: float = 1.0

@export_category("Mixing")
@export var color_diffusion_multiplier: float = 1.0
@export var mixing_group: int = 0
@export var dye_strength: float = 1.0
@export var turbidity_multiplier: float = 1.0

@export_category("Optical Presentation")
@export_range(0.0, 2.0, 0.01) var refractive_strength: float = 0.35
@export_range(0.0, 2.0, 0.01) var specular_strength: float = 0.30

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if material_id < 0:
		errors.append("material_id must be non-negative")
	if not is_finite(concentration) or concentration < 0.0:
		errors.append("concentration must be finite and non-negative")
	if not is_finite(turbidity) or turbidity < 0.0:
		errors.append("turbidity must be finite and non-negative")
	if not is_finite(density_multiplier) or density_multiplier <= 0.0:
		errors.append("density_multiplier must be finite and positive")
	if not is_finite(viscosity_multiplier) or viscosity_multiplier <= 0.0:
		errors.append("viscosity_multiplier must be finite and positive")
	if not is_finite(color_diffusion_multiplier) or color_diffusion_multiplier < 0.0:
		errors.append("color_diffusion_multiplier must be finite and non-negative")
	if mixing_group < 0:
		errors.append("mixing_group must be non-negative")
	if not is_finite(dye_strength) or dye_strength < 0.0:
		errors.append("dye_strength must be finite and non-negative")
	if not is_finite(turbidity_multiplier) or turbidity_multiplier < 0.0:
		errors.append("turbidity_multiplier must be finite and non-negative")
	if not is_finite(refractive_strength) or refractive_strength < 0.0:
		errors.append("refractive_strength must be finite and non-negative")
	if not is_finite(specular_strength) or specular_strength < 0.0:
		errors.append("specular_strength must be finite and non-negative")
	return errors
