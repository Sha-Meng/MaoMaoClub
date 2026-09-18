extends Node2D
class_name ServingGlassView

@export var glass_texture: Texture2D
@export var glass_size: Vector2 = Vector2(82.0, 112.0)
@export_range(1.0, 1000.0, 1.0) var capacity_ml: float = 180.0

var fill_amount_ml: float = 0.0:
	set(value):
		fill_amount_ml = clampf(value, 0.0, capacity_ml)
		queue_redraw()
var liquid_color: Color = Color(0.72, 0.26, 0.34, 0.82):
	set(value):
		liquid_color = value
		queue_redraw()


func set_contents(amount_ml: float, color: Color) -> void:
	fill_amount_ml = amount_ml
	liquid_color = color
	queue_redraw()


func clear_contents() -> void:
	fill_amount_ml = 0.0
	queue_redraw()


func get_fill_ratio() -> float:
	return clampf(fill_amount_ml / maxf(capacity_ml, 1.0), 0.0, 1.0)


func _draw() -> void:
	var rect := Rect2(-glass_size * 0.5, glass_size)
	_draw_liquid(rect)
	if glass_texture != null:
		draw_texture_rect(glass_texture, rect, false)


func _draw_liquid(rect: Rect2) -> void:
	var ratio := get_fill_ratio()
	if ratio <= 0.0:
		return
	# 只使用浅碟杯上半部的内腔；液面越高，碗壁越宽。
	var bowl_top := rect.position.y + 13.0
	var bowl_bottom := rect.position.y + glass_size.y * 0.43
	var surface_y := lerpf(bowl_bottom, bowl_top, minf(ratio / 0.55, 1.0))
	var t := inverse_lerp(bowl_bottom, bowl_top, surface_y)
	var half_width := lerpf(glass_size.x * 0.12, glass_size.x * 0.40, t)
	var bottom_half_width := glass_size.x * 0.10
	var fill_shape := PackedVector2Array([
		Vector2(-half_width, surface_y),
		Vector2(half_width, surface_y),
		Vector2(bottom_half_width, bowl_bottom),
		Vector2(-bottom_half_width, bowl_bottom),
	])
	draw_colored_polygon(fill_shape, liquid_color)
	draw_line(
		Vector2(-half_width, surface_y), Vector2(half_width, surface_y),
		liquid_color.lightened(0.34), 2.0
	)
