extends Node
class_name DesktopWindowController

signal window_placement_changed(position: Vector2i, size: Vector2i)

var config: DesktopWindowConfig = DesktopWindowConfig.new()

func apply_a_tier_window(save_data: Dictionary) -> void:
	var target_size: Vector2i = save_data.get("window_size", config.default_window_size) as Vector2i
	if target_size.x <= 0 or target_size.y <= 0:
		target_size = config.default_window_size

	DisplayServer.window_set_size(target_size)
	if config.use_borderless_window:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	var saved_position: Vector2i = save_data.get("window_position", _make_default_position(target_size)) as Vector2i
	var target_position: Vector2i = saved_position
	if not is_saved_position_valid(saved_position, target_size):
		target_position = _make_default_position(target_size)
	DisplayServer.window_set_position(target_position)
	window_placement_changed.emit(target_position, target_size)


func capture_window_placement() -> Dictionary:
	var captured_size: Vector2i = DisplayServer.window_get_size()
	if captured_size.x <= 0 or captured_size.y <= 0:
		captured_size = config.default_window_size
	var captured_position: Vector2i = DisplayServer.window_get_position()
	if not is_saved_position_valid(captured_position, captured_size):
		captured_position = _make_default_position(captured_size)
	return {
		"window_position": captured_position,
		"window_size": captured_size
	}


func is_saved_position_valid(pos: Vector2i, size: Vector2i) -> bool:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var window_rect: Rect2i = Rect2i(pos, size)
	return usable_rect.intersects(window_rect)


func _make_default_position(size: Vector2i) -> Vector2i:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var x: int = usable_rect.position.x + usable_rect.size.x - size.x - config.edge_margin
	var y: int = usable_rect.position.y + usable_rect.size.y - size.y - config.edge_margin
	return Vector2i(maxi(usable_rect.position.x, x), maxi(usable_rect.position.y, y))
