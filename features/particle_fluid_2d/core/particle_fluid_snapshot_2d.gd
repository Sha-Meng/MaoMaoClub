extends RefCounted
class_name ParticleFluidSnapshot2D

var ids: PackedInt32Array = PackedInt32Array()
var positions_meters: PackedVector2Array = PackedVector2Array()
var velocities_meters_per_second: PackedVector2Array = PackedVector2Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var optical_densities: PackedVector3Array = PackedVector3Array()
var turbidities: PackedFloat32Array = PackedFloat32Array()
var display_colors_srgb: PackedColorArray = PackedColorArray()

func count() -> int:
	return ids.size()

func duplicate_snapshot() -> ParticleFluidSnapshot2D:
	var copy := ParticleFluidSnapshot2D.new()
	copy.ids = ids.duplicate()
	copy.positions_meters = positions_meters.duplicate()
	copy.velocities_meters_per_second = velocities_meters_per_second.duplicate()
	copy.densities = densities.duplicate()
	copy.pressures = pressures.duplicate()
	copy.optical_densities = optical_densities.duplicate()
	copy.turbidities = turbidities.duplicate()
	copy.display_colors_srgb = display_colors_srgb.duplicate()
	return copy
