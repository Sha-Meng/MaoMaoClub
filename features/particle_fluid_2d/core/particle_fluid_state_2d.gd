extends RefCounted
class_name ParticleFluidState2D

var ids: PackedInt32Array = PackedInt32Array()
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var accelerations: PackedVector2Array = PackedVector2Array()
var masses: PackedFloat32Array = PackedFloat32Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var optical_densities: PackedVector3Array = PackedVector3Array()
var concentrations: PackedFloat32Array = PackedFloat32Array()
var turbidities: PackedFloat32Array = PackedFloat32Array()
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
	optical_densities.clear()
	concentrations.clear()
	turbidities.clear()
	material_ids.clear()
	_id_to_index.clear()
	_next_id = 1

func count() -> int:
	return ids.size()

func add_batch(batch: ParticleSpawnBatch2D, config: ParticleFluidConfig2D) -> PackedInt32Array:
	var added_ids := PackedInt32Array()
	for index: int in range(batch.count()):
		var particle_id := _next_id
		_next_id += 1
		added_ids.append(particle_id)
		ids.append(particle_id)
		positions.append(batch.positions_meters[index])
		velocities.append(batch.velocities_meters_per_second[index] if batch.velocities_meters_per_second.size() > 0 else Vector2.ZERO)
		accelerations.append(Vector2.ZERO)
		masses.append(batch.masses[index] if batch.masses.size() > 0 else config.particle_mass)
		densities.append(config.rest_density)
		pressures.append(0.0)
		var color := batch.colors_srgb[index] if batch.colors_srgb.size() > 0 else Color.WHITE
		var concentration := batch.concentrations[index] if batch.concentrations.size() > 0 else 1.0
		optical_densities.append(ColorTransport2D.srgb_to_optical_density(color, concentration))
		concentrations.append(concentration)
		turbidities.append(batch.turbidities[index] if batch.turbidities.size() > 0 else color.a)
		material_ids.append(batch.material_ids[index] if batch.material_ids.size() > 0 else 0)
		_id_to_index[particle_id] = ids.size() - 1
	return added_ids

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
	snapshot.optical_densities = optical_densities.duplicate()
	snapshot.turbidities = turbidities.duplicate()
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
	optical_densities.remove_at(index)
	concentrations.remove_at(index)
	turbidities.remove_at(index)
	material_ids.remove_at(index)

func _rebuild_index() -> void:
	_id_to_index.clear()
	for index: int in range(ids.size()):
		_id_to_index[ids[index]] = index
