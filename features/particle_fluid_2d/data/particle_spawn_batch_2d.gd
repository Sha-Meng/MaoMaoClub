extends RefCounted
class_name ParticleSpawnBatch2D

var positions_meters: PackedVector2Array = PackedVector2Array()
var velocities_meters_per_second: PackedVector2Array = PackedVector2Array()
var colors_srgb: PackedColorArray = PackedColorArray()
var concentrations: PackedFloat32Array = PackedFloat32Array()
var turbidities: PackedFloat32Array = PackedFloat32Array()
var masses: PackedFloat32Array = PackedFloat32Array()
var material_ids: PackedInt32Array = PackedInt32Array()

func count() -> int:
	return positions_meters.size()

func validate(default_mass: float) -> PackedStringArray:
	var errors := PackedStringArray()
	var particle_count := count()
	if particle_count == 0:
		errors.append("positions_meters must not be empty")
	_check_optional_size(errors, "velocities_meters_per_second", velocities_meters_per_second.size(), particle_count)
	_check_optional_size(errors, "colors_srgb", colors_srgb.size(), particle_count)
	_check_optional_size(errors, "concentrations", concentrations.size(), particle_count)
	_check_optional_size(errors, "turbidities", turbidities.size(), particle_count)
	_check_optional_size(errors, "masses", masses.size(), particle_count)
	_check_optional_size(errors, "material_ids", material_ids.size(), particle_count)
	for index: int in range(positions_meters.size()):
		if not _vector_is_finite(positions_meters[index]):
			errors.append("positions_meters[%d] must be finite" % index)
	for index: int in range(velocities_meters_per_second.size()):
		if not _vector_is_finite(velocities_meters_per_second[index]):
			errors.append("velocities_meters_per_second[%d] must be finite" % index)
	for index: int in range(colors_srgb.size()):
		var color := colors_srgb[index]
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
			errors.append("colors_srgb[%d] must be finite" % index)
	for index: int in range(concentrations.size()):
		if not is_finite(concentrations[index]) or concentrations[index] < 0.0:
			errors.append("concentrations[%d] must be finite and non-negative" % index)
	for index: int in range(turbidities.size()):
		if not is_finite(turbidities[index]) or turbidities[index] < 0.0:
			errors.append("turbidities[%d] must be finite and non-negative" % index)
	for index: int in range(masses.size()):
		if not is_finite(masses[index]) or masses[index] <= 0.0:
			errors.append("masses[%d] must be finite and positive" % index)
	if not is_finite(default_mass) or default_mass <= 0.0:
		errors.append("default_mass must be finite and positive")
	return errors

func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

func _check_optional_size(errors: PackedStringArray, field_name: String, size: int, expected: int) -> void:
	if size != 0 and size != expected:
		errors.append("%s must be empty or match positions size" % field_name)
