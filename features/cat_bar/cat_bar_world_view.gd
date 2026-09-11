extends Node2D
class_name CatBarWorldView

const HALL_BACKGROUND: Texture2D = preload("res://assets/cat_bar/environment/cat_bar_hall_generated.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(HALL_BACKGROUND, Rect2(0.0, 0.0, 960.0, 540.0), false)
	# 交互和角色继续位于生成背景之上的稳定逻辑层。
	var bar_zone := Rect2(326.0, 186.0, 308.0, 90.0)
	draw_rect(bar_zone, Color(0.95, 0.58, 0.24, 0.025), true)
	draw_rect(bar_zone, Color(0.96, 0.68, 0.32, 0.18), false, 2.0)
	for center: Vector2 in [Vector2(240.0, 398.0), Vector2(480.0, 414.0), Vector2(710.0, 392.0)]:
		draw_circle(center, 18.0, Color(1.0, 0.63, 0.24, 0.055))
