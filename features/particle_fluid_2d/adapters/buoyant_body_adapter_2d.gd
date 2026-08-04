extends RigidBody2D
class_name BuoyantBodyAdapter2D

@export var body_id: int = 0
@export var fluid_shape: BuoyantBodyShape2D
@export var effective_depth_meters: float = 0.1
@export var drag_coefficient: float = 2.0
@export var maximum_fluid_force: float = 1000.0

var pixels_per_meter: float = 100.0
var _pending_force_newtons: Vector2 = Vector2.ZERO
var _pending_torque_newton_meters: float = 0.0
var _cached_snapshot: BuoyantBodySnapshot2D

func _ready() -> void:
	if body_id <= 0:
		body_id = int(get_instance_id())
	_cache_snapshot(global_transform, linear_velocity, angular_velocity)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if mass > 0.0:
		state.linear_velocity += _pending_force_newtons / mass * state.step * pixels_per_meter
	var effective_inertia := _effective_inertia()
	if effective_inertia > 0.0:
		state.angular_velocity += _pending_torque_newton_meters / effective_inertia * state.step
	_pending_force_newtons = Vector2.ZERO
	_pending_torque_newton_meters = 0.0
	_cache_snapshot(state.transform, state.linear_velocity, state.angular_velocity)

func make_snapshot() -> BuoyantBodySnapshot2D:
	if _cached_snapshot == null:
		_cache_snapshot(global_transform, linear_velocity, angular_velocity)
	return _cached_snapshot

func queue_fluid_force(force_newtons: Vector2, torque_newton_meters: float) -> void:
	if is_finite(force_newtons.x) and is_finite(force_newtons.y) and is_finite(torque_newton_meters):
		_pending_force_newtons += force_newtons
		_pending_torque_newton_meters += torque_newton_meters

func refresh_fluid_snapshot() -> void:
	_pending_force_newtons = Vector2.ZERO
	_pending_torque_newton_meters = 0.0
	_cache_snapshot(global_transform, linear_velocity, angular_velocity)

func _cache_snapshot(transform_pixels: Transform2D, velocity_pixels: Vector2, angular_speed: float) -> void:
	var snapshot := BuoyantBodySnapshot2D.new()
	snapshot.body_id = body_id
	snapshot.shape = fluid_shape
	snapshot.world_transform = Transform2D(transform_pixels.get_rotation(), transform_pixels.origin / pixels_per_meter)
	snapshot.linear_velocity_meters_per_second = velocity_pixels / pixels_per_meter
	snapshot.angular_velocity_radians_per_second = angular_speed
	snapshot.center_of_mass_local_meters = center_of_mass / pixels_per_meter
	snapshot.mass_kilograms = mass
	snapshot.moment_of_inertia = _effective_inertia()
	snapshot.effective_depth_meters = effective_depth_meters
	snapshot.drag_coefficient = drag_coefficient
	snapshot.maximum_fluid_force = maximum_fluid_force
	_cached_snapshot = snapshot

func _effective_inertia() -> float:
	if inertia > 0.0:
		return inertia / (pixels_per_meter * pixels_per_meter)
	if fluid_shape == null:
		return maxf(mass * 0.01, 0.000001)
	match fluid_shape.shape_type:
		BuoyantBodyShape2D.ShapeType.CIRCLE:
			return 0.5 * mass * fluid_shape.radius_meters * fluid_shape.radius_meters
		BuoyantBodyShape2D.ShapeType.RECTANGLE:
			return mass * (fluid_shape.size_meters.x * fluid_shape.size_meters.x + fluid_shape.size_meters.y * fluid_shape.size_meters.y) / 12.0
	return maxf(mass * fluid_shape.area_meters_squared() / 6.0, 0.000001)
