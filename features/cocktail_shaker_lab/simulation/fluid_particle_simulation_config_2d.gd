extends Resource
class_name FluidParticleSimulationConfig2D

@export_category("Key")
@export_enum("Water:0", "Amber Spirit:1") var fluid_id: int = FluidConfig.FluidId.WATER

@export_category("Complete Particle Solver")
@export var particle_config: ParticleFluidConfig2D = ParticleFluidConfig2D.new()

@export_category("Pour")
@export_range(0.001, 10.0, 0.001, "or_greater") var volume_per_add_liters: float = 0.20
@export_range(1, 12, 1) var pour_stream_columns: int = 3
@export_range(0.0, 1.0, 0.005, "or_greater") var pour_spawn_depth_meters: float = 0.035
@export_range(0.0, 10.0, 0.05, "or_greater") var pour_initial_downward_speed_meters_per_second: float = 0.75
@export var display_color_srgb: Color = Color(0.25, 0.65, 1.0, 0.8)
@export_range(0.0, 8.0, 0.01, "or_greater") var concentration: float = 1.0
@export_range(0.0, 8.0, 0.01, "or_greater") var turbidity: float = 0.35

@export_category("Per Fluid Physical Mapping")
@export_range(0.01, 8.0, 0.001, "or_greater") var density_multiplier: float = 1.0
@export_range(0.001, 100.0, 0.01, "or_greater") var viscosity_multiplier: float = 1.0

@export_category("Mixing And Dye")
@export_range(0.0, 20.0, 0.01, "or_greater") var color_diffusion_multiplier: float = 1.0
@export_range(0, 64, 1) var mixing_group: int = 0
@export_range(0.0, 20.0, 0.01, "or_greater") var dye_strength: float = 1.0
@export_range(0.0, 20.0, 0.01, "or_greater") var turbidity_multiplier: float = 1.0

@export_category("Optical Presentation")
@export_range(0.0, 2.0, 0.01) var refractive_strength: float = 0.35
@export_range(0.0, 2.0, 0.01) var specular_strength: float = 0.30


func to_fluid_material() -> FluidMaterial2D:
	var material := FluidMaterial2D.new()
	material.material_id = fluid_id
	material.display_color_srgb = display_color_srgb
	material.concentration = concentration
	material.turbidity = turbidity
	material.density_multiplier = density_multiplier
	material.viscosity_multiplier = viscosity_multiplier
	material.color_diffusion_multiplier = color_diffusion_multiplier
	material.mixing_group = mixing_group
	material.dye_strength = dye_strength
	material.turbidity_multiplier = turbidity_multiplier
	material.refractive_strength = refractive_strength
	material.specular_strength = specular_strength
	return material


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not FluidConfig.FluidId.values().has(fluid_id):
		errors.append("fluid_id must be a declared FluidId")
	if particle_config == null:
		errors.append("particle_config must not be null")
	else:
		for error: String in particle_config.validate():
			errors.append("particle_config: %s" % error)
	if not is_finite(volume_per_add_liters) or volume_per_add_liters <= 0.0:
		errors.append("volume_per_add_liters must be finite and positive")
	if pour_stream_columns < 1:
		errors.append("pour_stream_columns must be positive")
	if not is_finite(pour_spawn_depth_meters) or pour_spawn_depth_meters < 0.0:
		errors.append("pour_spawn_depth_meters must be finite and non-negative")
	if not is_finite(pour_initial_downward_speed_meters_per_second) or pour_initial_downward_speed_meters_per_second < 0.0:
		errors.append("pour_initial_downward_speed_meters_per_second must be finite and non-negative")
	for error: String in to_fluid_material().validate():
		errors.append(error)
	return errors
