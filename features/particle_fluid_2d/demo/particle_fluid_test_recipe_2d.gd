extends RefCounted
class_name ParticleFluidTestRecipe2D

var display_name: String = "液体"
var particle_count: int = 100
var requested_volume_liters: float = 100.0
var actual_volume_liters: float = 100.0
var color_srgb: Color = Color.WHITE
var concentration: float = 1.0
var material_id: int = 0
var density_multiplier: float = 1.0
var viscosity_multiplier: float = 1.0
var color_diffusion_multiplier: float = 1.0
var mixing_group: int = 0
var dye_strength: float = 1.0
var turbidity_multiplier: float = 1.0
var refractive_strength: float = 0.35
var specular_strength: float = 0.30
var turbidity: float = 0.75
