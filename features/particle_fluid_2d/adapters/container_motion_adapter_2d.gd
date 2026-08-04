extends Node2D
class_name ContainerMotionAdapter2D

@export var container_shape: ContainerShape2D

var _has_history: bool = false
var _previous_position_meters: Vector2 = Vector2.ZERO
var _previous_rotation: float = 0.0
var _previous_linear_velocity: Vector2 = Vector2.ZERO
var _previous_angular_velocity: float = 0.0

func capture_snapshot(config: ParticleFluidConfig2D, delta_seconds: float) -> ContainerSnapshot2D:
	var source := get_parent() as Node2D
	if source == null:
		source = self
	var position_meters := source.global_position / config.pixels_per_meter
	var rotation_radians := source.global_rotation
	var linear_velocity := Vector2.ZERO
	var angular_velocity := 0.0
	var rigid_body := source as RigidBody2D
	if rigid_body != null:
		linear_velocity = rigid_body.linear_velocity / config.pixels_per_meter
		angular_velocity = rigid_body.angular_velocity
	elif _has_history and delta_seconds > 0.0:
		linear_velocity = (position_meters - _previous_position_meters) / delta_seconds
		angular_velocity = angle_difference(_previous_rotation, rotation_radians) / delta_seconds
	var linear_acceleration := Vector2.ZERO
	var angular_acceleration := 0.0
	if _has_history and delta_seconds > 0.0:
		linear_acceleration = (linear_velocity - _previous_linear_velocity) / delta_seconds
		angular_acceleration = (angular_velocity - _previous_angular_velocity) / delta_seconds
	var snapshot := ContainerSnapshot2D.new()
	snapshot.shape = container_shape
	snapshot.world_transform = Transform2D(rotation_radians, position_meters)
	snapshot.linear_velocity_meters_per_second = linear_velocity
	snapshot.angular_velocity_radians_per_second = angular_velocity
	snapshot.linear_acceleration_meters_per_second_squared = linear_acceleration
	snapshot.angular_acceleration_radians_per_second_squared = angular_acceleration
	_previous_position_meters = position_meters
	_previous_rotation = rotation_radians
	_previous_linear_velocity = linear_velocity
	_previous_angular_velocity = angular_velocity
	_has_history = true
	return snapshot

func reset_history() -> void:
	_has_history = false
