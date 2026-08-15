extends Resource
class_name ShakerTestConfig2D

@export_category("Fluid Tables")
@export var fluid_catalog: FluidCatalog = FluidCatalog.new()
@export var particle_simulation_table: FluidParticleSimulationTable2D = FluidParticleSimulationTable2D.new()

@export_category("Shaker")
@export var vessel: ShakerVesselConfig2D = ShakerVesselConfig2D.new()
@export var motion: ShakerMotionConfig2D = ShakerMotionConfig2D.new()
@export var ice: ShakerIceConfig2D = ShakerIceConfig2D.new()

@export_category("Particle Quantization")
@export_range(0.01, 0.5, 0.001, "or_greater") var particle_spacing_meters: float = 0.055
@export_range(1, 500, 1) var maximum_particles: int = 120

@export_category("Rendering")
@export_enum("Optical Field", "Direct Particles") var render_mode: int = ParticleFluid2D.RenderMode.OPTICAL_FIELD
@export var optical_field_resolution: Vector2i = Vector2i(96, 144)
@export_range(1.0, 3.0, 0.05) var optical_surface_fill_scale: float = 2.8
@export var rendering_enabled: bool = true

@export_category("Runtime")
@export var start_paused: bool = false
@export var random_seed: int = 20260815


func get_default_simulation() -> FluidParticleSimulationConfig2D:
	if particle_simulation_table == null:
		return null
	return particle_simulation_table.get_default_config()


func get_reference_particle_config() -> ParticleFluidConfig2D:
	var simulation := get_default_simulation()
	return null if simulation == null else simulation.particle_config


func particle_volume_liters(simulation: FluidParticleSimulationConfig2D) -> float:
	if simulation == null or simulation.particle_config == null:
		return 0.0
	return (
		particle_spacing_meters
		* particle_spacing_meters
		* simulation.particle_config.effective_depth_meters
		* 1000.0
	)


func particle_count_per_add(simulation: FluidParticleSimulationConfig2D) -> int:
	var particle_volume := particle_volume_liters(simulation)
	if simulation == null or particle_volume <= 0.0:
		return 0
	return maxi(1, ceili(simulation.volume_per_add_liters / particle_volume))


func container_particle_capacity() -> int:
	if vessel == null or particle_spacing_meters <= 0.0:
		return 0
	var margin := particle_spacing_meters * 0.6
	var columns := maxi(1, floori((vessel.width_meters - margin * 2.0) / particle_spacing_meters) + 1)
	var rows := maxi(1, floori((vessel.height_meters - margin * 2.0) / particle_spacing_meters) + 1)
	return columns * rows


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if fluid_catalog == null:
		errors.append("fluid_catalog must not be null")
	else:
		_append_prefixed(errors, "fluid_catalog", fluid_catalog.validate())
	if particle_simulation_table == null:
		errors.append("particle_simulation_table must not be null")
	else:
		_append_prefixed(errors, "particle_simulation_table", particle_simulation_table.validate())
	if fluid_catalog != null and particle_simulation_table != null:
		for fluid_id: int in fluid_catalog.get_ids():
			if particle_simulation_table.get_config(fluid_id) == null:
				errors.append("fluid_id %d has no particle simulation config" % fluid_id)
		for simulation: FluidParticleSimulationConfig2D in particle_simulation_table.entries:
			if simulation != null and fluid_catalog.get_fluid(simulation.fluid_id) == null:
				errors.append("particle simulation fluid_id %d has no business config" % simulation.fluid_id)
	if vessel == null:
		errors.append("vessel must not be null")
	else:
		_append_prefixed(errors, "vessel", vessel.validate())
	if motion == null:
		errors.append("motion must not be null")
	else:
		_append_prefixed(errors, "motion", motion.validate())
	var reference_config := get_reference_particle_config()
	if ice == null:
		errors.append("ice must not be null")
	elif reference_config != null:
		_append_prefixed(errors, "ice", ice.validate(reference_config.effective_depth_meters))
	if particle_spacing_meters <= 0.0 or not is_finite(particle_spacing_meters):
		errors.append("particle_spacing_meters must be finite and positive")
	if maximum_particles < 1:
		errors.append("maximum_particles must be positive")
	if optical_field_resolution.x < 2 or optical_field_resolution.y < 2:
		errors.append("optical_field_resolution must be at least 2x2")
	return errors


func _append_prefixed(errors: PackedStringArray, prefix: String, child_errors: PackedStringArray) -> void:
	for error: String in child_errors:
		errors.append("%s: %s" % [prefix, error])
