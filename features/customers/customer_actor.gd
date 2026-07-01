extends Control
class_name CustomerActor

signal service_requested(customer_id: int)
signal left_scene(customer_id: int)

const BODY_SIZE: Vector2 = Vector2(54.0, 72.0)

var customer_id: int = 0
var config: CustomerConfig = CustomerConfig.new()
var state: int = CustomerState.State.ENTERING

var _target_position: Vector2 = Vector2.ZERO
var _speech: String = ""

func _ready() -> void:
	custom_minimum_size = BODY_SIZE
	size = BODY_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if state == CustomerState.State.ENTERING or state == CustomerState.State.LEAVING:
		position = position.move_toward(_target_position, config.move_speed * delta)
		if position.distance_to(_target_position) < 2.0:
			_on_target_reached()


func _draw() -> void:
	draw_circle(Vector2(27.0, 26.0), 22.0, config.body_color)
	draw_rect(Rect2(Vector2(11.0, 39.0), Vector2(32.0, 27.0)), config.body_color.darkened(0.08), true)
	draw_circle(Vector2(20.0, 23.0), 2.3, Color.BLACK)
	draw_circle(Vector2(34.0, 23.0), 2.3, Color.BLACK)
	draw_arc(Vector2(27.0, 30.0), 7.0, 0.15, PI - 0.15, 12, Color.BLACK, 1.6)
	if not _speech.is_empty():
		draw_rect(Rect2(Vector2(-8.0, -19.0), Vector2(70.0, 20.0)), Color(1.0, 0.96, 0.82), true)
		draw_string(ThemeDB.fallback_font, Vector2(-2.0, -5.0), _speech, HORIZONTAL_ALIGNMENT_LEFT, 66.0, 13, Color(0.24, 0.16, 0.09))


func enter_to(request_position: Vector2) -> void:
	state = CustomerState.State.ENTERING
	_target_position = request_position
	_speech = "想点单"
	queue_redraw()


func mark_waiting() -> void:
	state = CustomerState.State.WAITING_FOR_CAT
	_speech = "等猫猫"
	queue_redraw()


func start_service(cat_id: int) -> void:
	state = CustomerState.State.BEING_SERVED
	_speech = "服务中"
	queue_redraw()


func complete_service() -> void:
	state = CustomerState.State.PAYING
	_speech = "谢谢!"
	queue_redraw()


func leave_to(exit_position: Vector2) -> void:
	state = CustomerState.State.LEAVING
	_target_position = exit_position
	_speech = ""
	queue_redraw()


func _on_target_reached() -> void:
	if state == CustomerState.State.ENTERING:
		state = CustomerState.State.REQUESTING_SERVICE
		service_requested.emit(customer_id)
	elif state == CustomerState.State.LEAVING:
		left_scene.emit(customer_id)
		queue_free()
