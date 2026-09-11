extends RefCounted
class_name MixingVesselVisualSnapshot

var particle_count: int = 0
var ice_count: int = 0
var sealed: bool = false
var shaking: bool = false
var shaker_offset: Vector2 = Vector2.ZERO
var shaker_rotation: float = 0.0
var average_fluid_speed: float = 0.0
var fluid_contained: bool = true
var ice_contained: bool = true
var vessel_size_meters: Vector2 = Vector2.ONE
var fluid_positions_local_meters: PackedVector2Array = PackedVector2Array()
var fluid_velocities_local_meters_per_second: PackedVector2Array = PackedVector2Array()
var fluid_colors: PackedColorArray = PackedColorArray()
var ice_positions_local_meters: PackedVector2Array = PackedVector2Array()
var ice_rotations: PackedFloat32Array = PackedFloat32Array()
var ice_size_meters: Vector2 = Vector2.ZERO
var ice_color: Color = Color(0.78, 0.94, 1.0, 0.78)
var ice_outline_color: Color = Color(0.9, 0.98, 1.0, 0.9)


func copy() -> MixingVesselVisualSnapshot:
	var result := MixingVesselVisualSnapshot.new()
	result.particle_count = particle_count
	result.ice_count = ice_count
	result.sealed = sealed
	result.shaking = shaking
	result.shaker_offset = shaker_offset
	result.shaker_rotation = shaker_rotation
	result.average_fluid_speed = average_fluid_speed
	result.fluid_contained = fluid_contained
	result.ice_contained = ice_contained
	result.vessel_size_meters = vessel_size_meters
	result.fluid_positions_local_meters = fluid_positions_local_meters.duplicate()
	result.fluid_velocities_local_meters_per_second = fluid_velocities_local_meters_per_second.duplicate()
	result.fluid_colors = fluid_colors.duplicate()
	result.ice_positions_local_meters = ice_positions_local_meters.duplicate()
	result.ice_rotations = ice_rotations.duplicate()
	result.ice_size_meters = ice_size_meters
	result.ice_color = ice_color
	result.ice_outline_color = ice_outline_color
	return result
