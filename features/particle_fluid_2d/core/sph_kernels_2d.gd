extends RefCounted
class_name SphKernels2D

static func density_poly6(distance: float, smoothing_radius: float) -> float:
	if distance < 0.0 or distance >= smoothing_radius or smoothing_radius <= 0.0:
		return 0.0
	var h2 := smoothing_radius * smoothing_radius
	var term := h2 - distance * distance
	return 4.0 * term * term * term / (PI * pow(smoothing_radius, 8.0))

static func pressure_spiky_gradient(offset: Vector2, smoothing_radius: float) -> Vector2:
	var distance := offset.length()
	if distance <= 0.000001 or distance >= smoothing_radius or smoothing_radius <= 0.0:
		return Vector2.ZERO
	var coefficient := -30.0 * pow(smoothing_radius - distance, 2.0) / (PI * pow(smoothing_radius, 5.0))
	return coefficient * offset / distance

static func viscosity_laplacian(distance: float, smoothing_radius: float) -> float:
	if distance < 0.0 or distance >= smoothing_radius or smoothing_radius <= 0.0:
		return 0.0
	return 40.0 * (smoothing_radius - distance) / (PI * pow(smoothing_radius, 5.0))
