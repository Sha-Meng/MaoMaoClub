extends Control
class_name DiegeticDragItem

signal hover_started(content_id: StringName, global_position: Vector2)
signal hover_ended(content_id: StringName)
signal drag_requested(content_id: StringName, global_position: Vector2)

var content_id: StringName = &""
var home_position: Vector2 = Vector2.ZERO
var draggable: bool = true

var _icon: TextureRect
var _name_label: Label
var _highlighted: bool = false
var _highlight_strong: bool = false
var _ready_hint: bool = false


func configure(
	p_content_id: StringName,
	display_name: String,
	texture: Texture2D,
	p_size: Vector2,
	p_position: Vector2,
	p_draggable: bool = true
) -> void:
	content_id = p_content_id
	name = "Item_%s" % content_id
	size = p_size
	position = p_position
	home_position = p_position
	draggable = p_draggable
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = texture
	add_child(_icon)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.position = Vector2(-12.0, size.y - 5.0)
	_name_label.size = Vector2(size.x + 24.0, 25.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.text = display_name
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color("ffe2a8"))
	_name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.025, 0.96))
	_name_label.add_theme_constant_override("outline_size", 5)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	queue_redraw()


func set_highlighted(value: bool, strong: bool = false) -> void:
	if _highlighted == value and _highlight_strong == strong:
		return
	_highlighted = value
	_highlight_strong = strong
	queue_redraw()


func set_ready_hint(value: bool) -> void:
	if _ready_hint == value:
		return
	_ready_hint = value
	queue_redraw()


func reset_to_home() -> void:
	position = home_position
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE


func contains_global_point(point: Vector2) -> bool:
	return get_global_rect().grow(8.0).has_point(point)


func _draw() -> void:
	if _ready_hint:
		draw_rect(Rect2(Vector2(-5.0, -5.0), size + Vector2(10.0, 10.0)), Color(1.0, 0.73, 0.28, 0.13), true)
		draw_rect(Rect2(Vector2(-4.0, -4.0), size + Vector2(8.0, 8.0)), Color(1.0, 0.74, 0.3, 0.72), false, 2.0)
	if not _highlighted:
		return
	var alpha := 0.34 if _highlight_strong else 0.2
	var width := 4.0 if _highlight_strong else 3.0
	draw_rect(Rect2(Vector2(-8.0, -8.0), size + Vector2(16.0, 16.0)), Color(0.38, 1.0, 0.65, alpha), true)
	draw_rect(Rect2(Vector2(-6.0, -6.0), size + Vector2(12.0, 12.0)), Color(0.55, 1.0, 0.72, 0.98), false, width)


func _on_mouse_entered() -> void:
	hover_started.emit(content_id, global_position + Vector2(size.x, 0.0))


func _on_mouse_exited() -> void:
	hover_ended.emit(content_id)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed or not draggable:
		return
	drag_requested.emit(content_id, button.global_position)
	accept_event()
