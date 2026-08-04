extends Resource
class_name BuoyantBodyShape2D

enum ShapeType {
	CIRCLE,
	RECTANGLE,
	CONVEX_POLYGON,
}

@export var shape_type: int = ShapeType.RECTANGLE
@export var radius_meters: float = 0.08
@export var size_meters: Vector2 = Vector2(0.16, 0.10)
@export var polygon_points_meters: PackedVector2Array = PackedVector2Array()
@export var sample_spacing_meters: float = 0.025

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(sample_spacing_meters) or sample_spacing_meters <= 0.0:
		errors.append("sample_spacing_meters must be finite and positive")
	match shape_type:
		ShapeType.CIRCLE:
			if not is_finite(radius_meters) or radius_meters <= 0.0:
				errors.append("circle radius must be finite and positive")
		ShapeType.RECTANGLE:
			if not is_finite(size_meters.x) or not is_finite(size_meters.y) or size_meters.x <= 0.0 or size_meters.y <= 0.0:
				errors.append("rectangle size must be finite and positive")
		ShapeType.CONVEX_POLYGON:
			if polygon_points_meters.size() < 3 or not _is_convex(polygon_points_meters):
				errors.append("polygon must contain at least three convex points")
		_:
			errors.append("unsupported buoyant body shape type")
	return errors

func area_meters_squared() -> float:
	match shape_type:
		ShapeType.CIRCLE:
			return PI * radius_meters * radius_meters
		ShapeType.RECTANGLE:
			return size_meters.x * size_meters.y
		ShapeType.CONVEX_POLYGON:
			var signed_area := 0.0
			for index: int in range(polygon_points_meters.size()):
				signed_area += polygon_points_meters[index].cross(
					polygon_points_meters[(index + 1) % polygon_points_meters.size()]
				)
			return absf(signed_area) * 0.5
	return 0.0

func make_weighted_samples() -> Dictionary:
	var points := PackedVector2Array()
	var bounds := _bounds()
	if shape_type == ShapeType.CIRCLE:
		bounds = Rect2(Vector2(-radius_meters, -radius_meters), Vector2.ONE * radius_meters * 2.0)
	var x_count := maxi(1, ceili(bounds.size.x / sample_spacing_meters))
	var y_count := maxi(1, ceili(bounds.size.y / sample_spacing_meters))
	for y_index: int in range(y_count):
		for x_index: int in range(x_count):
			var point := bounds.position + Vector2(
				(float(x_index) + 0.5) * bounds.size.x / float(x_count),
				(float(y_index) + 0.5) * bounds.size.y / float(y_count)
			)
			if _contains_point(point):
				points.append(point)
	if points.is_empty():
		points.append(Vector2.ZERO)
	var areas := PackedFloat32Array()
	var sample_area := area_meters_squared() / float(points.size())
	areas.resize(points.size())
	areas.fill(sample_area)
	return {"points": points, "areas": areas}

func _bounds() -> Rect2:
	if shape_type == ShapeType.RECTANGLE:
		return Rect2(-size_meters * 0.5, size_meters)
	if shape_type == ShapeType.CONVEX_POLYGON and not polygon_points_meters.is_empty():
		var bounds := Rect2(polygon_points_meters[0], Vector2.ZERO)
		for point: Vector2 in polygon_points_meters:
			bounds = bounds.expand(point)
		return bounds
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _contains_point(point: Vector2) -> bool:
	match shape_type:
		ShapeType.CIRCLE:
			return point.length_squared() <= radius_meters * radius_meters
		ShapeType.RECTANGLE:
			return Rect2(-size_meters * 0.5, size_meters).has_point(point)
		ShapeType.CONVEX_POLYGON:
			return Geometry2D.is_point_in_polygon(point, polygon_points_meters)
	return false

func _is_convex(points: PackedVector2Array) -> bool:
	var sign_value := 0.0
	for index: int in range(points.size()):
		var cross_value := (points[(index + 1) % points.size()] - points[index]).cross(
			points[(index + 2) % points.size()] - points[(index + 1) % points.size()]
		)
		if absf(cross_value) <= 0.000001:
			continue
		if sign_value == 0.0:
			sign_value = signf(cross_value)
		elif signf(cross_value) != sign_value:
			return false
	return sign_value != 0.0
