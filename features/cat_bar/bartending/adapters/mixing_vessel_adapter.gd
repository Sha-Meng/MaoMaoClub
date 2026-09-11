extends Node
class_name MixingVesselAdapter

signal visual_snapshot_changed(snapshot: MixingVesselVisualSnapshot)

const LAB_SCENE: PackedScene = preload("res://features/cocktail_shaker_lab/cocktail_shaker_lab.tscn")

@export_range(18, 136, 1) var visual_particle_budget: int = 70

var _lab: CocktailShakerLab
var _sampler := ShakeInputSampler.new()


func _ready() -> void:
	if _lab == null:
		_create_lab()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _lab != null and (_lab.get_particle_count() > 0 or _lab.is_shaking() or _lab.is_post_shake_settling()):
		_emit_snapshot()


func reset() -> void:
	if _lab == null:
		return
	_lab.reset_test()
	_sampler.reset()
	_emit_snapshot()


func add_fluid(fluid_id: int) -> bool:
	if _lab == null:
		return false
	var accepted := _lab.add_fluid(fluid_id)
	_emit_snapshot()
	return accepted


func add_ice(count: int = 1) -> int:
	if _lab == null:
		return 0
	var accepted := 0
	for _index: int in range(maxi(count, 0)):
		if not _lab.add_ice():
			break
		accepted += 1
	_emit_snapshot()
	return accepted


func set_sealed(value: bool) -> void:
	if _lab == null:
		return
	_lab.set_lid_enabled(value)
	_emit_snapshot()


func begin_shake() -> bool:
	if _lab == null or not _lab.start_shake():
		return false
	_sampler.reset()
	_emit_snapshot()
	return true


func apply_shake_delta(delta_pixels: Vector2, delta_seconds: float) -> void:
	if _lab == null or not _lab.is_shaking():
		return
	_sampler.sample(delta_pixels, delta_seconds)
	_lab.apply_mouse_drag_delta_for_test(delta_pixels)
	_emit_snapshot()


func end_shake() -> Dictionary[StringName, float]:
	if _lab != null and _lab.is_shaking():
		_lab.stop_shake_and_reset()
	_emit_snapshot()
	return _sampler.metrics().duplicate()


func cancel_shake() -> void:
	if _lab != null and _lab.is_shaking():
		_lab.stop_shake_and_reset()
	_sampler.reset()
	_emit_snapshot()


func visual_snapshot() -> MixingVesselVisualSnapshot:
	var snapshot := MixingVesselVisualSnapshot.new()
	if _lab == null:
		return snapshot
	snapshot.particle_count = _lab.get_particle_count()
	snapshot.ice_count = _lab.get_ice_count()
	snapshot.sealed = _lab.is_lid_enabled()
	snapshot.shaking = _lab.is_shaking()
	snapshot.shaker_offset = _lab.get_shaker_offset()
	snapshot.shaker_rotation = _lab.get_shaker_rotation_radians()
	snapshot.average_fluid_speed = _lab.get_average_fluid_speed_meters_per_second()
	snapshot.fluid_contained = _lab.are_fluid_particles_contained()
	snapshot.ice_contained = _lab.are_ice_bodies_contained()
	snapshot.vessel_size_meters = _lab.get_vessel_size_meters()
	var fluid := _lab.get_fluid_local_snapshot()
	snapshot.fluid_positions_local_meters = fluid.positions_meters.duplicate()
	snapshot.fluid_velocities_local_meters_per_second = fluid.velocities_meters_per_second.duplicate()
	snapshot.fluid_colors = fluid.display_colors_srgb.duplicate()
	snapshot.ice_positions_local_meters = _lab.get_ice_local_positions_meters()
	snapshot.ice_rotations = _lab.get_ice_local_rotations_radians()
	snapshot.ice_size_meters = _lab.get_ice_size_meters()
	snapshot.ice_color = _lab.get_ice_color()
	snapshot.ice_outline_color = _lab.get_ice_outline_color()
	return snapshot


func fluid_snapshot() -> ParticleFluidSnapshot2D:
	return _lab.get_fluid_snapshot() if _lab != null else ParticleFluidSnapshot2D.new()


func is_post_shake_settling() -> bool:
	return _lab != null and _lab.is_post_shake_settling()


func _create_lab() -> void:
	_lab = LAB_SCENE.instantiate() as CocktailShakerLab
	_lab.embedded_mode = true
	_lab.visible = false
	add_child(_lab)


func _emit_snapshot() -> void:
	visual_snapshot_changed.emit(visual_snapshot())
