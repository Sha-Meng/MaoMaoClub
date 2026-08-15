extends Resource
class_name ContainerShape2D

var segment_starts_local_meters: PackedVector2Array = PackedVector2Array()
var segment_ends_local_meters: PackedVector2Array = PackedVector2Array()
var inward_normals_local: PackedVector2Array = PackedVector2Array()
var is_closed: bool = false

func clear() -> void:
	segment_starts_local_meters.clear()
	segment_ends_local_meters.clear()
	inward_normals_local.clear()
	is_closed = false

func segment_count() -> int:
	return segment_starts_local_meters.size()

func add_segment(start: Vector2, end: Vector2, inward_normal: Vector2) -> void:
	assert(start.distance_to(end) > 0.000001)
	assert(inward_normal.length_squared() > 0.000001)
	segment_starts_local_meters.append(start)
	segment_ends_local_meters.append(end)
	inward_normals_local.append(inward_normal.normalized())

func configure_open_cup(width_meters: float, height_meters: float) -> void:
	clear()
	var half_width := width_meters * 0.5
	add_segment(Vector2(-half_width, 0.0), Vector2(-half_width, height_meters), Vector2.RIGHT)
	add_segment(Vector2(-half_width, height_meters), Vector2(half_width, height_meters), Vector2.UP)
	add_segment(Vector2(half_width, height_meters), Vector2(half_width, 0.0), Vector2.LEFT)

func configure_convex_polygon(points: PackedVector2Array) -> void:
	assert(points.size() >= 3)
	assert(_is_convex(points))
	clear()
	var centroid := Vector2.ZERO
	for point: Vector2 in points:
		centroid += point
	centroid /= float(points.size())
	for index: int in range(points.size()):
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var direction := end - start
		var normal := Vector2(-direction.y, direction.x).normalized()
		if normal.dot(centroid - (start + end) * 0.5) < 0.0:
			normal = -normal
		add_segment(start, end, normal)
	is_closed = true

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if segment_count() == 0:
		errors.append("container must have at least one boundary segment")
	if segment_ends_local_meters.size() != segment_count() or inward_normals_local.size() != segment_count():
		errors.append("container boundary arrays must have equal size")
	for index: int in range(mini(segment_count(), mini(segment_ends_local_meters.size(), inward_normals_local.size()))):
		if segment_starts_local_meters[index].distance_to(segment_ends_local_meters[index]) <= 0.000001:
			errors.append("segment %d has zero length" % index)
		if inward_normals_local[index].length_squared() <= 0.000001:
			errors.append("segment %d has zero inward normal" % index)
	return errors

func _is_convex(points: PackedVector2Array) -> bool:
	var sign_value := 0.0
	for index: int in range(points.size()):
		var first := points[index]
		var second := points[(index + 1) % points.size()]
		var third := points[(index + 2) % points.size()]
		var cross_value := (second - first).cross(third - second)
		if absf(cross_value) <= 0.000001:
			continue
		if sign_value == 0.0:
			sign_value = signf(cross_value)
		elif signf(cross_value) != sign_value:
			return false
	return sign_value != 0.0
