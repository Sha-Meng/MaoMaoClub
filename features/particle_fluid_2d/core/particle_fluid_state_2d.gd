extends RefCounted
class_name ParticleFluidState2D

var ids: PackedInt32Array = PackedInt32Array()
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var accelerations: PackedVector2Array = PackedVector2Array()
var masses: PackedFloat32Array = PackedFloat32Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var target_rest_densities: PackedFloat32Array = PackedFloat32Array()
var viscosity_multipliers: PackedFloat32Array = PackedFloat32Array()
var optical_densities: PackedVector3Array = PackedVector3Array()
var concentrations: PackedFloat32Array = PackedFloat32Array()
var turbidities: PackedFloat32Array = PackedFloat32Array()
var color_diffusion_multipliers: PackedFloat32Array = PackedFloat32Array()
var mixing_groups: PackedInt32Array = PackedInt32Array()
var refractive_strengths: PackedFloat32Array = PackedFloat32Array()
var specular_strengths: PackedFloat32Array = PackedFloat32Array()
var material_ids: PackedInt32Array = PackedInt32Array()

var _next_id: int = 1
var _id_to_index: Dictionary = {}

func clear() -> void:
	ids.clear()
	positions.clear()
	velocities.clear()
	accelerations.clear()
	masses.clear()
	densities.clear()
	pressures.clear()
	target_rest_densities.clear()
	viscosity_multipliers.clear()
	optical_densities.clear()
	concentrations.clear()
	turbidities.clear()
	color_diffusion_multipliers.clear()
	mixing_groups.clear()
	refractive_strengths.clear()
	specular_strengths.clear()
	material_ids.clear()
	_id_to_index.clear()
	_next_id = 1

func count() -> int:
	return ids.size()

func add_batch(
	batch: ParticleSpawnBatch2D,
	config: ParticleFluidConfig2D,
	materials_by_id: Dictionary = {}
) -> PackedInt32Array:
	var added_ids := PackedInt32Array()
	var fallback_material := materials_by_id.get(0) as FluidMaterial2D
	if fallback_material == null:
		fallback_material = FluidMaterial2D.new()
	for index: int in range(batch.count()):
		var requested_material_id := batch.material_ids[index] if batch.material_ids.size() > 0 else 0
		var material := materials_by_id.get(requested_material_id, fallback_material) as FluidMaterial2D
		var resolved_material_id := requested_material_id if materials_by_id.has(requested_material_id) else 0
		var particle_id := _next_id
		_next_id += 1
		added_ids.append(particle_id)
		ids.append(particle_id)
		positions.append(batch.positions_meters[index])
		velocities.append(batch.velocities_meters_per_second[index] if batch.velocities_meters_per_second.size() > 0 else Vector2.ZERO)
		accelerations.append(Vector2.ZERO)
		masses.append(batch.masses[index] if batch.masses.size() > 0 else config.particle_mass)
		var target_rest_density := config.rest_density * material.density_multiplier
		densities.append(target_rest_density)
		pressures.append(0.0)
		target_rest_densities.append(target_rest_density)
		viscosity_multipliers.append(material.viscosity_multiplier)
		var color := batch.colors_srgb[index] if batch.colors_srgb.size() > 0 else material.display_color_srgb
		var concentration := batch.concentrations[index] if batch.concentrations.size() > 0 else material.concentration
		optical_densities.append(ColorTransport2D.srgb_to_optical_density(
			color,
			concentration * material.dye_strength
		))
		concentrations.append(concentration)
		var turbidity := batch.turbidities[index] if batch.turbidities.size() > 0 else material.turbidity
		turbidities.append(turbidity * material.turbidity_multiplier)
		color_diffusion_multipliers.append(material.color_diffusion_multiplier)
		mixing_groups.append(material.mixing_group)
		refractive_strengths.append(material.refractive_strength)
		specular_strengths.append(material.specular_strength)
		material_ids.append(resolved_material_id)
		_id_to_index[particle_id] = ids.size() - 1
	return added_ids

func refresh_material_properties(materials_by_id: Dictionary, config: ParticleFluidConfig2D) -> void:
	var fallback_material := materials_by_id.get(0) as FluidMaterial2D
	if fallback_material == null:
		fallback_material = FluidMaterial2D.new()
	for index: int in range(count()):
		var material := materials_by_id.get(material_ids[index], fallback_material) as FluidMaterial2D
		target_rest_densities[index] = config.rest_density * material.density_multiplier
		viscosity_multipliers[index] = material.viscosity_multiplier
		color_diffusion_multipliers[index] = material.color_diffusion_multiplier
		mixing_groups[index] = material.mixing_group
		refractive_strengths[index] = material.refractive_strength
		specular_strengths[index] = material.specular_strength

func remove_particles(particle_ids: PackedInt32Array) -> void:
	for index: int in range(ids.size() - 1, -1, -1):
		if particle_ids.has(ids[index]):
			_remove_at(index)
	_rebuild_index()

func get_index(particle_id: int) -> int:
	return int(_id_to_index.get(particle_id, -1))

func make_snapshot(optical_path_length: float) -> ParticleFluidSnapshot2D:
	var snapshot := ParticleFluidSnapshot2D.new()
	snapshot.ids = ids.duplicate()
	snapshot.positions_meters = positions.duplicate()
	snapshot.velocities_meters_per_second = velocities.duplicate()
	snapshot.densities = densities.duplicate()
	snapshot.pressures = pressures.duplicate()
	snapshot.material_ids = material_ids.duplicate()
	snapshot.target_rest_densities = target_rest_densities.duplicate()
	snapshot.optical_densities = optical_densities.duplicate()
	snapshot.turbidities = turbidities.duplicate()
	snapshot.refractive_strengths = refractive_strengths.duplicate()
	snapshot.specular_strengths = specular_strengths.duplicate()
	for index: int in range(count()):
		snapshot.display_colors_srgb.append(ColorTransport2D.optical_density_to_srgb(
			optical_densities[index],
			optical_path_length,
			turbidities[index]
		))
	return snapshot

func _remove_at(index: int) -> void:
	ids.remove_at(index)
	positions.remove_at(index)
	velocities.remove_at(index)
	accelerations.remove_at(index)
	masses.remove_at(index)
	densities.remove_at(index)
	pressures.remove_at(index)
	target_rest_densities.remove_at(index)
	viscosity_multipliers.remove_at(index)
	optical_densities.remove_at(index)
	concentrations.remove_at(index)
	turbidities.remove_at(index)
	color_diffusion_multipliers.remove_at(index)
	mixing_groups.remove_at(index)
	refractive_strengths.remove_at(index)
	specular_strengths.remove_at(index)
	material_ids.remove_at(index)

func _rebuild_index() -> void:
	_id_to_index.clear()
	for index: int in range(ids.size()):
		_id_to_index[ids[index]] = index
