extends Node2D
class_name ShakerVesselView

@export var vessel_size: Vector2 = Vector2(92.0, 150.0)
@export var glass_color: Color = Color(0.72, 0.9, 1.0, 0.32)
@export var outline_color: Color = Color(0.82, 0.93, 1.0, 0.9)
@export var liquid_color: Color = Color(0.68, 0.22, 0.31, 0.72)

var _snapshot := MixingVesselVisualSnapshot.new()
var _rest_position: Vector2 = Vector2.ZERO
var _drop_highlighted: bool = false


func bind(adapter: MixingVesselAdapter) -> void:
	if adapter == null:
		return
	_rest_position = position
	adapter.visual_snapshot_changed.connect(_on_snapshot_changed)
	_on_snapshot_changed(adapter.visual_snapshot())


func set_liquid_color(value: Color) -> void:
	liquid_color = value
	queue_redraw()


func set_drop_highlighted(value: bool) -> void:
	if _drop_highlighted == value:
		return
	_drop_highlighted = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-vessel_size * 0.5, vessel_size)
	if _drop_highlighted:
		draw_rect(rect.grow(7.0), Color(0.45, 0.95, 0.62, 0.22), true)
		draw_rect(rect.grow(5.0), Color(0.55, 1.0, 0.7, 0.95), false, 3.0)
	draw_rect(rect, glass_color, true)
	_draw_fluid_particles(rect)
	draw_line(rect.position, rect.position + Vector2(0.0, vessel_size.y), outline_color, 4.0)
	draw_line(rect.position + Vector2(vessel_size.x, 0.0), rect.end, outline_color, 4.0)
	draw_line(rect.position + Vector2(0.0, vessel_size.y), rect.end, outline_color, 4.0)
	if _snapshot.sealed:
		draw_line(rect.position, rect.position + Vector2(vessel_size.x, 0.0), Color(0.94, 0.78, 0.35), 6.0)
	_draw_ice(rect)


func get_rendered_particle_count() -> int:
	return _snapshot.fluid_positions_local_meters.size()


func _draw_fluid_particles(rect: Rect2) -> void:
	var count := _snapshot.fluid_positions_local_meters.size()
	if count == 0:
		return
	var particle_radius := clampf(vessel_size.x / sqrt(float(count)) * 0.72, 3.0, 7.0)
	for index: int in range(count):
		var point := _local_meters_to_pixels(_snapshot.fluid_positions_local_meters[index], rect)
		var color := liquid_color
		if index < _snapshot.fluid_colors.size():
			color = liquid_color.lerp(_snapshot.fluid_colors[index], 0.42)
		color.a = 0.68
		draw_circle(point.round(), particle_radius + 1.0, Color(color.r * 0.4, color.g * 0.32, color.b * 0.42, 0.18))
		draw_circle(point.round(), particle_radius, color)
		if index % 4 == 0:
			draw_circle((point + Vector2(-1.0, -1.0)).round(), maxf(particle_radius * 0.25, 1.0), Color(1.0, 0.88, 0.72, 0.34))


func _draw_ice(rect: Rect2) -> void:
	var vessel := _safe_vessel_size()
	var size_pixels := Vector2(
		_snapshot.ice_size_meters.x / vessel.x * (vessel_size.x - 10.0),
		_snapshot.ice_size_meters.y / vessel.y * (vessel_size.y - 10.0)
	).clamp(Vector2(8.0, 8.0), Vector2(22.0, 22.0))
	for index: int in range(_snapshot.ice_positions_local_meters.size()):
		var center := _local_meters_to_pixels(_snapshot.ice_positions_local_meters[index], rect)
		var angle := _snapshot.ice_rotations[index] if index < _snapshot.ice_rotations.size() else 0.0
		var half := size_pixels * 0.5
		var points := PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		for point_index: int in range(points.size()):
			points[point_index] = center + points[point_index].rotated(angle)
		draw_colored_polygon(points, _snapshot.ice_color)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, _snapshot.ice_outline_color, 2.0)


func _local_meters_to_pixels(local_meters: Vector2, rect: Rect2) -> Vector2:
	var vessel := _safe_vessel_size()
	return Vector2(
		rect.position.x + 5.0 + (local_meters.x / vessel.x + 0.5) * (vessel_size.x - 10.0),
		rect.position.y + 5.0 + local_meters.y / vessel.y * (vessel_size.y - 10.0)
	)


func _safe_vessel_size() -> Vector2:
	return Vector2(maxf(_snapshot.vessel_size_meters.x, 0.001), maxf(_snapshot.vessel_size_meters.y, 0.001))


func _on_snapshot_changed(snapshot: MixingVesselVisualSnapshot) -> void:
	_snapshot = snapshot.copy()
	position = _rest_position + _snapshot.shaker_offset.round()
	rotation = _snapshot.shaker_rotation
	queue_redraw()
