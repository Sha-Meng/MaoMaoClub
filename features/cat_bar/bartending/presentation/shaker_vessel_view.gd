extends Node2D
class_name ShakerVesselView

@export var vessel_size: Vector2 = Vector2(92.0, 150.0)
@export var glass_color: Color = Color(0.72, 0.9, 1.0, 0.32)
@export var outline_color: Color = Color(0.82, 0.93, 1.0, 0.9)
@export var liquid_color: Color = Color(0.68, 0.22, 0.31, 0.72)
@export var body_texture: Texture2D
@export var lid_texture: Texture2D

var _snapshot := MixingVesselVisualSnapshot.new()
var _rest_position: Vector2 = Vector2.ZERO
var _drop_highlighted: bool = false
var _fill_ratio: float = 0.0


func bind(adapter: MixingVesselAdapter) -> void:
	if adapter == null:
		return
	_rest_position = position
	adapter.visual_snapshot_changed.connect(_on_snapshot_changed)
	_on_snapshot_changed(adapter.visual_snapshot())


func set_liquid_color(value: Color) -> void:
	liquid_color = value
	queue_redraw()


func set_fill_ratio(value: float) -> void:
	_fill_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func get_fill_ratio() -> float:
	return _fill_ratio


func get_liquid_color() -> Color:
	return liquid_color


func is_lid_aligned() -> bool:
	if not _snapshot.sealed or lid_texture == null:
		return false
	var vessel_rect := Rect2(-vessel_size * 0.5, vessel_size)
	var lid_rect := _lid_rect_for(vessel_rect)
	# 生成素材的可见底沿约位于纹理高度 58% 处。
	var visible_bottom := lid_rect.position.y + lid_rect.size.y * 0.58
	return absf(visible_bottom - vessel_rect.position.y) <= 10.01


func set_drop_highlighted(value: bool) -> void:
	if _drop_highlighted == value:
		return
	_drop_highlighted = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-vessel_size * 0.5, vessel_size)
	if body_texture != null:
		_draw_generated_vessel(rect)
		return
	var outer := PackedVector2Array([
		rect.position + Vector2(9.0, 0.0),
		rect.position + Vector2(vessel_size.x - 9.0, 0.0),
		rect.position + Vector2(vessel_size.x, vessel_size.y - 12.0),
		rect.position + Vector2(vessel_size.x - 8.0, vessel_size.y),
		rect.position + Vector2(8.0, vessel_size.y),
		rect.position + Vector2(0.0, vessel_size.y - 12.0),
	])
	if _drop_highlighted:
		draw_rect(rect.grow(7.0), Color(0.45, 0.95, 0.62, 0.22), true)
		draw_rect(rect.grow(5.0), Color(0.55, 1.0, 0.7, 0.95), false, 3.0)
	draw_colored_polygon(outer, Color(0.18, 0.2, 0.25, 0.94))
	var inner := PackedVector2Array([
		outer[0] + Vector2(5.0, 6.0), outer[1] + Vector2(-5.0, 6.0),
		outer[2] + Vector2(-6.0, -4.0), outer[3] + Vector2(-4.0, -6.0),
		outer[4] + Vector2(4.0, -6.0), outer[5] + Vector2(6.0, -4.0),
	])
	draw_colored_polygon(inner, glass_color)
	_draw_fluid_particles(rect)
	var outline := outer.duplicate()
	outline.append(outer[0])
	draw_polyline(outline, Color(0.07, 0.06, 0.1, 1.0), 5.0)
	draw_polyline(outline, outline_color, 2.0)
	draw_line(rect.position + Vector2(10.0, 13.0), rect.position + Vector2(10.0, vessel_size.y - 18.0), Color(1.0, 0.72, 0.34, 0.72), 4.0)
	draw_line(rect.position + Vector2(vessel_size.x - 10.0, 14.0), rect.position + Vector2(vessel_size.x - 10.0, vessel_size.y - 18.0), Color(0.27, 0.68, 1.0, 0.64), 3.0)
	draw_line(rect.position + Vector2(4.0, vessel_size.y - 15.0), rect.position + Vector2(vessel_size.x - 4.0, vessel_size.y - 15.0), Color(0.76, 0.78, 0.86, 0.78), 4.0)
	if _snapshot.sealed:
		var lid_rect := Rect2(rect.position + Vector2(5.0, -13.0), Vector2(vessel_size.x - 10.0, 17.0))
		draw_rect(lid_rect, Color(0.34, 0.35, 0.42, 1.0), true)
		draw_rect(lid_rect, Color(0.96, 0.78, 0.37, 0.95), false, 3.0)
		draw_colored_polygon(PackedVector2Array([
			lid_rect.position + Vector2(8.0, 1.0), lid_rect.position + Vector2(16.0, -8.0), lid_rect.position + Vector2(23.0, 1.0),
		]), Color(0.73, 0.76, 0.84, 1.0))
		draw_colored_polygon(PackedVector2Array([
			lid_rect.position + Vector2(lid_rect.size.x - 23.0, 1.0), lid_rect.position + Vector2(lid_rect.size.x - 16.0, -8.0), lid_rect.position + Vector2(lid_rect.size.x - 8.0, 1.0),
		]), Color(0.73, 0.76, 0.84, 1.0))
	_draw_ice(rect)


func _draw_generated_vessel(rect: Rect2) -> void:
	if _drop_highlighted:
		draw_rect(rect.grow(7.0), Color(0.45, 0.95, 0.62, 0.22), true)
		draw_rect(rect.grow(5.0), Color(0.55, 1.0, 0.7, 0.95), false, 3.0)
	draw_texture_rect(body_texture, rect, false)
	var window := Rect2(rect.position + Vector2(13.0, 27.0), rect.size - Vector2(26.0, 39.0))
	if _fill_ratio > 0.0:
		_draw_tapered_fill(window)
	if _snapshot.particle_count > 0 or _snapshot.ice_count > 0:
		_draw_fluid_particles(window)
		_draw_ice(window)
	if _snapshot.sealed and lid_texture != null:
		# 杯盖底沿压住开放杯口，避免视觉上悬空或插入杯身过深。
		var lid_rect := _lid_rect_for(rect)
		draw_texture_rect(lid_texture, lid_rect, false)


func _draw_tapered_fill(window: Rect2) -> void:
	var bottom_y := window.end.y - 3.0
	var top_limit := window.position.y + 6.0
	var surface_y := lerpf(bottom_y, top_limit, _fill_ratio)
	var top_inset := _taper_inset_at_y(window, surface_y)
	var bottom_inset := _taper_inset_at_y(window, bottom_y)
	var points := PackedVector2Array([
		Vector2(window.position.x + top_inset, surface_y),
		Vector2(window.end.x - top_inset, surface_y),
		Vector2(window.end.x - bottom_inset, bottom_y),
		Vector2(window.position.x + bottom_inset, bottom_y),
	])
	var fill_color := liquid_color
	fill_color.a = 0.72
	draw_colored_polygon(points, fill_color)
	draw_line(points[0], points[1], fill_color.lightened(0.35), 2.0)


func _taper_inset_at_y(window: Rect2, y: float) -> float:
	var normalized_y := inverse_lerp(window.position.y, window.end.y, y)
	return lerpf(1.0, window.size.x * 0.13, normalized_y)


func _lid_rect_for(vessel_rect: Rect2) -> Rect2:
	return Rect2(
		vessel_rect.position + Vector2(-3.0, -17.0),
		Vector2(vessel_rect.size.x + 6.0, 45.0)
	)


func get_rendered_particle_count() -> int:
	return _snapshot.fluid_positions_local_meters.size()


func _draw_fluid_particles(rect: Rect2) -> void:
	var count := _snapshot.fluid_positions_local_meters.size()
	if count == 0:
		return
	var particle_radius := clampf(vessel_size.x / sqrt(float(count)) * 0.38, 2.0, 4.0)
	for index: int in range(count):
		var point := _local_meters_to_pixels(_snapshot.fluid_positions_local_meters[index], rect)
		var color := liquid_color
		if index < _snapshot.fluid_colors.size():
			color = _snapshot.fluid_colors[index]
		color.a = 0.82
		if body_texture != null:
			point = _clamp_point_to_taper(point, rect, particle_radius)
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
		if body_texture != null:
			center = _clamp_point_to_taper(center, rect, maxf(half.x, half.y))
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


func _clamp_point_to_taper(point: Vector2, rect: Rect2, margin: float) -> Vector2:
	var clamped_y := clampf(point.y, rect.position.y + margin, rect.end.y - margin)
	var inset := _taper_inset_at_y(rect, clamped_y) + margin
	return Vector2(
		clampf(point.x, rect.position.x + inset, rect.end.x - inset),
		clamped_y
	)


func _on_snapshot_changed(snapshot: MixingVesselVisualSnapshot) -> void:
	_snapshot = snapshot.copy()
	position = _rest_position + _snapshot.shaker_offset.round()
	rotation = _snapshot.shaker_rotation
	queue_redraw()
