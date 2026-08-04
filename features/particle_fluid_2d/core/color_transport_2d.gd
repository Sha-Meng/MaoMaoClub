extends RefCounted
class_name ColorTransport2D

const MIN_TRANSMITTANCE: float = 0.0001

static func srgb_to_optical_density(color_srgb: Color, concentration: float = 1.0) -> Vector3:
	if concentration <= 0.0:
		return Vector3.ZERO
	var linear := color_srgb.srgb_to_linear()
	return Vector3(
		-log(maxf(linear.r, MIN_TRANSMITTANCE)),
		-log(maxf(linear.g, MIN_TRANSMITTANCE)),
		-log(maxf(linear.b, MIN_TRANSMITTANCE))
	) * concentration

static func optical_density_to_srgb(
	optical_density: Vector3,
	path_length: float = 1.0,
	turbidity: float = 1.0
) -> Color:
	var safe_path := maxf(path_length, 0.0)
	var linear := Color(
		exp(-maxf(optical_density.x, 0.0) * safe_path),
		exp(-maxf(optical_density.y, 0.0) * safe_path),
		exp(-maxf(optical_density.z, 0.0) * safe_path),
		clampf(1.0 - exp(-maxf(turbidity, 0.0) * safe_path), 0.0, 1.0)
	)
	return linear.linear_to_srgb()

static func diffuse_pair(first: Vector3, second: Vector3, rate: float, delta_seconds: float) -> Array[Vector3]:
	var exchange_factor := clampf(rate * delta_seconds, 0.0, 0.5)
	var exchange := (second - first) * exchange_factor
	return [first + exchange, second - exchange]
