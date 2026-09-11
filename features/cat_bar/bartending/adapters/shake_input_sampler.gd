extends RefCounted
class_name ShakeInputSampler

var _duration: float = 0.0
var _distance: float = 0.0
var _reversals: int = 0
var _peak_speed: float = 0.0
var _previous_delta: Vector2 = Vector2.ZERO


func reset() -> void:
	_duration = 0.0
	_distance = 0.0
	_reversals = 0
	_peak_speed = 0.0
	_previous_delta = Vector2.ZERO


func sample(delta_pixels: Vector2, delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_duration += delta_seconds
	_distance += delta_pixels.length()
	_peak_speed = maxf(_peak_speed, delta_pixels.length() / delta_seconds)
	if (
		_previous_delta.length_squared() > 0.01
		and delta_pixels.length_squared() > 0.01
		and _previous_delta.normalized().dot(delta_pixels.normalized()) < -0.25
	):
		_reversals += 1
	_previous_delta = delta_pixels


func metrics() -> Dictionary[StringName, float]:
	return {
		&"duration": _duration,
		&"distance": _distance,
		&"reversals": float(_reversals),
		&"peak_speed": _peak_speed,
	}

