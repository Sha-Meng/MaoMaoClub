extends Node
class_name DesktopWindowController

signal window_placement_changed(position: Vector2i, size: Vector2i)

var config: DesktopWindowConfig = DesktopWindowConfig.new()
var _last_position: Vector2i
var _placement_check_seconds: float = 0.0
var _dragging_window: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO
var _display_scale: float = 1.0
var _interaction_bounds: Rect2 = Rect2(0.0, 0.0, 960.0, 280.0)

func apply_desktop_window(save_data: Dictionary) -> void:
	get_window().transparent_bg = config.use_transparent_window
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return

	var checkpoint: Variant = save_data.get("tavern", {})
	_display_scale = TavernData.number(checkpoint.get("scale", 1.0), 1.0, 0.8, 1.2) if checkpoint is Dictionary else 1.0
	var target_size: Vector2i = desired_window_size(_display_scale)
	get_window().mode = Window.MODE_WINDOWED
	get_window().borderless = config.use_borderless_window
	get_window().transparent = config.use_transparent_window
	get_window().always_on_top = true
	get_window().unresizable = true
	get_window().size = target_size
	get_window().content_scale_size = config.default_window_size
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

	var saved_position: Vector2i = save_data.get("window_position", Vector2i.ZERO) as Vector2i
	var has_placement: bool = save_data.has("window_position")
	# 旧原型把 (0, 0) 作为初始位置；升级后允许玩家主动保存到左上角。
	if int(save_data.get("window_layout_version", 0)) == 0 and saved_position == Vector2i.ZERO:
		has_placement = false
	var target_position: Vector2i = resolve_window_position(saved_position, target_size)
	if not has_placement:
		target_position = _make_default_position(target_size)
	elif int(save_data.get("window_layout_version", 0)) < 2:
		var old_size: Vector2i = save_data.get("window_size", Vector2i(960, 360)) as Vector2i
		target_position = resolve_window_position(saved_position + Vector2i(0, old_size.y - target_size.y), target_size)
	get_window().position = target_position
	_last_position = target_position
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().focus_entered.connect(restore_desktop_layer)
	restore_desktop_layer()
	window_placement_changed.emit(target_position, target_size)


func _process(delta: float) -> void:
	if get_window().mode == Window.MODE_MINIMIZED:
		return
	if _dragging_window:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			get_window().position = resolve_window_position(DisplayServer.mouse_get_position() - _drag_offset, get_window().size)
		else:
			_dragging_window = false
	_placement_check_seconds += delta
	if _placement_check_seconds < 0.5:
		return
	_placement_check_seconds = 0.0
	var current_position: Vector2i = get_window().position
	if current_position != _last_position:
		_last_position = current_position
		window_placement_changed.emit(current_position, get_window().size)


func begin_window_drag(_window_local_position: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		_drag_offset = DisplayServer.mouse_get_position() - get_window().position
		_dragging_window = true


func _input(event: InputEvent) -> void:
	if not _dragging_window:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		get_window().position = resolve_window_position(DisplayServer.mouse_get_position() - _drag_offset, get_window().size)
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_dragging_window = false


func restore_desktop_layer() -> void:
	if DisplayServer.get_name() == "headless" or get_window().mode == Window.MODE_MINIMIZED:
		return
	get_window().always_on_top = true
	# 同时重申原生标志，避免 Window 缓存为 true 时跳过系统窗口层级更新。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, get_window().get_window_id())


func _on_window_focus_exited() -> void:
	_dragging_window = false
	restore_desktop_layer.call_deferred()


func minimize_window() -> void:
	if DisplayServer.get_name() != "headless":
		_last_position = get_window().position
		get_window().mode = Window.MODE_MINIMIZED
		window_placement_changed.emit(_last_position, get_window().size)


func capture_window_placement() -> Dictionary:
	var captured_size: Vector2i = config.default_window_size
	var captured_position: Vector2i = Vector2i.ZERO
	if DisplayServer.get_name() != "headless":
		captured_size = get_window().size
		var position_to_save: Vector2i = _last_position if get_window().mode == Window.MODE_MINIMIZED else get_window().position
		captured_position = resolve_window_position(position_to_save, captured_size)
	return {
		"window_position": captured_position,
		"window_size": captured_size,
		"window_layout_version": 2
	}


func desired_window_size(preference: float) -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return config.default_window_size
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var factor: float = minf(float(usable.size.y) / 1080.0 * preference, float(usable.size.x) * 0.96 / 960.0)
	factor = maxf(0.4, factor)
	return Vector2i(Vector2(config.default_window_size) * factor)


func apply_display_scale(preference: float) -> void:
	_display_scale = clampf(preference, 0.8, 1.2)
	if DisplayServer.get_name() == "headless":
		return
	var old_bottom: Vector2i = get_window().position + get_window().size
	get_window().size = desired_window_size(_display_scale)
	get_window().position = resolve_window_position(old_bottom - get_window().size, get_window().size)
	_last_position = get_window().position
	set_interaction_bounds(_interaction_bounds)
	window_placement_changed.emit(_last_position, get_window().size)


func set_interaction_bounds(bounds: Rect2) -> void:
	_interaction_bounds = bounds
	if DisplayServer.get_name() == "headless":
		return
	var clipped: Rect2 = bounds.intersection(Rect2(Vector2.ZERO, TavernLayout.SIZE))
	var factor: Vector2 = Vector2(get_window().size) / TavernLayout.SIZE
	var points: PackedVector2Array = PackedVector2Array([clipped.position * factor,
		Vector2(clipped.end.x, clipped.position.y) * factor, clipped.end * factor,
		Vector2(clipped.position.x, clipped.end.y) * factor])
	DisplayServer.window_set_mouse_passthrough(points, get_window().get_window_id())


func is_saved_position_valid(pos: Vector2i, window_size: Vector2i) -> bool:
	var window_rect: Rect2i = Rect2i(pos, window_size)
	for screen_index: int in range(DisplayServer.get_screen_count()):
		if DisplayServer.screen_get_usable_rect(screen_index).encloses(window_rect):
			return true
	return false


func resolve_window_position(pos: Vector2i, window_size: Vector2i) -> Vector2i:
	for screen_index: int in range(DisplayServer.get_screen_count()):
		var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
		if usable_rect.intersects(Rect2i(pos, window_size)):
			return Vector2i(
				clampi(pos.x, usable_rect.position.x, maxi(usable_rect.position.x, usable_rect.end.x - window_size.x)),
				clampi(pos.y, usable_rect.position.y, maxi(usable_rect.position.y, usable_rect.end.y - window_size.y))
			)
	return _make_default_position(window_size)


func _make_default_position(window_size: Vector2i) -> Vector2i:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var x: int = usable_rect.end.x - window_size.x - config.edge_margin
	var y: int = usable_rect.end.y - window_size.y - config.edge_margin
	return Vector2i(maxi(usable_rect.position.x, x), maxi(usable_rect.position.y, y))
