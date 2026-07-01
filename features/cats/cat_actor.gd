extends Control
class_name CatActor

signal clicked(cat_id: int)
signal drag_started(cat_id: int)
signal drag_ended(cat_id: int)

const BODY_SIZE: Vector2 = Vector2(72.0, 56.0)
const VALID_MARGIN: float = 8.0

var cat_id: int = 0
var config: CatConfig = CatConfig.new()
var state: int = CatState.State.IDLE
var assigned_customer_id: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drag_offset: Vector2 = Vector2.ZERO
var _home_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait_seconds: float = 0.0

func _ready() -> void:
	custom_minimum_size = BODY_SIZE
	size = BODY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_home_position = position
	_choose_next_wander_target()


func _process(delta: float) -> void:
	match state:
		CatState.State.DRAGGED:
			global_position = get_global_mouse_position() - _drag_offset
			_clamp_to_parent()
		CatState.State.WANDERING:
			_process_wandering(delta)
		CatState.State.RETURNING:
			_process_returning(delta)


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_drag_offset = get_global_mouse_position() - global_position
			state = CatState.State.DRAGGED
			drag_started.emit(cat_id)
			accept_event()
		else:
			if state == CatState.State.DRAGGED:
				state = CatState.State.RETURNING
				drag_ended.emit(cat_id)
				accept_event()

	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.double_click:
		play_click_feedback()
		clicked.emit(cat_id)
		accept_event()


func _draw() -> void:
	var body_rect: Rect2 = Rect2(Vector2(9.0, 18.0), Vector2(54.0, 30.0))
	draw_rect(body_rect, config.body_color, true)
	draw_circle(Vector2(36.0, 20.0), 22.0, config.body_color.lightened(0.08))
	draw_polygon(PackedVector2Array([Vector2(19.0, 8.0), Vector2(27.0, 0.0), Vector2(31.0, 14.0)]), PackedColorArray([config.body_color]))
	draw_polygon(PackedVector2Array([Vector2(41.0, 14.0), Vector2(45.0, 0.0), Vector2(53.0, 8.0)]), PackedColorArray([config.body_color]))
	draw_circle(Vector2(28.0, 18.0), 2.5, Color.BLACK)
	draw_circle(Vector2(44.0, 18.0), 2.5, Color.BLACK)
	draw_circle(Vector2(36.0, 25.0), 2.0, Color(0.95, 0.38, 0.48))
	if state == CatState.State.SERVING or state == CatState.State.ASSIGNED_TO_CUSTOMER:
		draw_arc(Vector2(36.0, 30.0), 26.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.45), 3.0)


func is_service_available() -> bool:
	return assigned_customer_id == -1 and state != CatState.State.DRAGGED and state != CatState.State.SERVING and state != CatState.State.ASSIGNED_TO_CUSTOMER


func assign_customer(customer_id: int) -> void:
	assigned_customer_id = customer_id
	state = CatState.State.SERVING
	queue_redraw()


func complete_service() -> void:
	assigned_customer_id = -1
	state = CatState.State.RETURNING
	queue_redraw()


func play_click_feedback() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func set_home_position(home_position: Vector2) -> void:
	_home_position = home_position


func _process_wandering(delta: float) -> void:
	if _wander_wait_seconds > 0.0:
		_wander_wait_seconds -= delta
		return
	position = position.move_toward(_wander_target, config.wander_speed * delta)
	if position.distance_to(_wander_target) < 2.0:
		state = CatState.State.IDLE
		_wander_wait_seconds = _rng.randf_range(0.6, 1.8)
		_choose_next_wander_target()


func _process_returning(delta: float) -> void:
	position = position.move_toward(_home_position, config.drag_return_speed * delta)
	if position.distance_to(_home_position) < 2.0:
		position = _home_position
		state = CatState.State.IDLE
		_choose_next_wander_target()
		queue_redraw()


func _choose_next_wander_target() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		_wander_target = _home_position
		return
	var max_x: float = maxf(VALID_MARGIN, parent_control.size.x - size.x - VALID_MARGIN)
	var max_y: float = maxf(VALID_MARGIN, parent_control.size.y - size.y - VALID_MARGIN)
	_wander_target = Vector2(_rng.randf_range(VALID_MARGIN, max_x), _rng.randf_range(155.0, max_y))
	if state == CatState.State.IDLE:
		state = CatState.State.WANDERING


func _clamp_to_parent() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return
	position = Vector2(
		clampf(position.x, VALID_MARGIN, maxf(VALID_MARGIN, parent_control.size.x - size.x - VALID_MARGIN)),
		clampf(position.y, VALID_MARGIN, maxf(VALID_MARGIN, parent_control.size.y - size.y - VALID_MARGIN))
	)
