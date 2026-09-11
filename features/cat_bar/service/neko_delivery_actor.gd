extends Node2D
class_name NekoDeliveryActor

signal drink_placed_on_bar(delivery_key: StringName, order_id: int, booth_id: StringName, result: DrinkResult)

enum State { IDLE, MOVING_TO_COUNTER, PLACING, RETURNING }

@export_range(0.1, 10.0, 0.1) var movement_seconds: float = 0.34
@export_range(0.5, 15.0, 0.5) var timeout_seconds: float = 3.0
@export var instant_delivery: bool = false
@export var character_texture: Texture2D
@export var character_size: Vector2 = Vector2(76.0, 76.0)

var state: State = State.IDLE
var _home_position := Vector2.ZERO
var _counter_position := Vector2.ZERO
var _delivery_key: StringName = &""
var _order_id: int = 0
var _booth_id: StringName = &""
var _result: DrinkResult
var _placed: bool = false
var _tween: Tween


func _ready() -> void:
	_home_position = position.round()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func configure_handoff(counter: Marker2D) -> void:
	_counter_position = counter.position.round() if counter != null else _home_position


func begin_handoff(delivery_key: StringName, order_id: int, booth_id: StringName, result: DrinkResult) -> bool:
	if state != State.IDLE or delivery_key.is_empty() or result == null or not result.valid:
		return false
	_delivery_key = delivery_key
	_order_id = order_id
	_booth_id = booth_id
	_result = result.copy()
	_placed = false
	if instant_delivery:
		_set_state(State.PLACING)
		_emit_placed_once()
		_finish_return()
		return true
	_set_state(State.MOVING_TO_COUNTER)
	_tween = create_tween()
	_tween.tween_property(self, "position", _counter_position, movement_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_set_state.bind(State.PLACING))
	_tween.tween_interval(0.18)
	_tween.tween_callback(_emit_placed_once)
	_tween.tween_callback(_set_state.bind(State.RETURNING))
	_tween.tween_property(self, "position", _home_position, movement_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_finish_return)
	var timeout := get_tree().create_timer(timeout_seconds)
	timeout.timeout.connect(_on_timeout)
	return true


func _set_state(next_state: State) -> void:
	state = next_state
	queue_redraw()


func _emit_placed_once() -> void:
	if _placed:
		return
	_placed = true
	drink_placed_on_bar.emit(_delivery_key, _order_id, _booth_id, _result.copy())


func _on_timeout() -> void:
	if state == State.IDLE:
		return
	_emit_placed_once()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = _home_position
	_finish_return()


func _finish_return() -> void:
	state = State.IDLE
	_result = null
	queue_redraw()


func _draw() -> void:
	if character_texture != null:
		draw_texture_rect(character_texture, Rect2(-character_size * Vector2(0.5, 0.82), character_size), false)
	else:
		_draw_fallback_cat(Color("bda39a"), Color("6b2738"))
	if state == State.MOVING_TO_COUNTER or state == State.PLACING:
		draw_circle(Vector2(25.0, -5.0), 6.0, Color("d69a53"))


func _draw_fallback_cat(body_color: Color, accent_color: Color) -> void:
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -8), Vector2(-9, -27), Vector2(0, -14)]), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(13, -8), Vector2(9, -27), Vector2(0, -14)]), body_color)
	draw_circle(Vector2(-6, -3), 2.0, Color("20191c"))
	draw_circle(Vector2(6, -3), 2.0, Color("20191c"))
	draw_line(Vector2(-8, 11), Vector2(8, 11), accent_color, 5.0)
