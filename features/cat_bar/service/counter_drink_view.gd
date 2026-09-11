extends Node2D
class_name CounterDrinkView

var _has_drink: bool = false
var _quality: int = 0


func show_drink(result: DrinkResult) -> void:
	_has_drink = result != null and result.valid
	_quality = result.quality if result != null else 0
	visible = _has_drink
	queue_redraw()


func take_drink() -> void:
	_has_drink = false
	visible = false
	queue_redraw()


func has_drink() -> bool:
	return _has_drink


func _draw() -> void:
	if not _has_drink:
		return
	var liquid := Color("d99a55").lerp(Color("b95472"), clampf(float(_quality) / 100.0, 0.0, 1.0))
	draw_polygon(
		PackedVector2Array([Vector2(-10.0, -13.0), Vector2(10.0, -13.0), Vector2(6.0, -4.0), Vector2(-6.0, -4.0)]),
		PackedColorArray([Color(0.8, 0.92, 1.0, 0.5)])
	)
	draw_line(Vector2(-7.0, -9.0), Vector2(7.0, -9.0), liquid, 5.0)
	draw_line(Vector2(0.0, -4.0), Vector2(0.0, 7.0), Color("e8d4b8"), 2.0)
	draw_line(Vector2(-7.0, 7.0), Vector2(7.0, 7.0), Color("e8d4b8"), 2.0)
