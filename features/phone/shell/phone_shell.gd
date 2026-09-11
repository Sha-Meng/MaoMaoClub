extends CanvasLayer
class_name PhoneShell

const PIXEL_THEME = preload("res://features/phone/presentation/phone_pixel_theme.gd")

signal open_requested
signal close_requested

var _service: WechatService
var _entry_button: Button
var _unread_badge: Label
var _overlay: Control
var _phone_panel: PanelContainer
var _home: VBoxContainer
var _page_host: MarginContainer
var _wechat_view: WechatView
var _status_label: Label
var _page_stack: Array[StringName] = []


func _ready() -> void:
	layer = 30
	_build_ui()
	set_open(false)


func bind_wechat(service: WechatService) -> void:
	if _service != null and _service.state_changed.is_connected(_update_badge):
		_service.state_changed.disconnect(_update_badge)
	_service = service
	if _service != null:
		_service.state_changed.connect(_update_badge)
	_wechat_view.bind(service)
	_update_badge()


func set_open(value: bool) -> void:
	if _overlay == null:
		return
	_overlay.visible = value
	_entry_button.visible = not value
	if not value:
		_show_home()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func set_entry_enabled(value: bool) -> void:
	if _entry_button != null:
		_entry_button.disabled = not value


func open_wechat() -> void:
	if _service == null:
		_status_label.text = "微信状态尚未准备好"
		return
	_home.visible = false
	_page_host.visible = true
	_wechat_view.visible = true
	_page_stack = [&"home", &"wechat"]


func press_unavailable_app(app_name: String) -> void:
	_status_label.text = "%s尚未开放，敬请期待" % app_name


func back() -> void:
	if _page_stack.size() > 1:
		_show_home()
	else:
		close_requested.emit()


func current_page() -> StringName:
	return _page_stack.back() if not _page_stack.is_empty() else &"home"


func get_wechat_view() -> WechatView:
	return _wechat_view


func get_status_text() -> String:
	return _status_label.text


func _build_ui() -> void:
	_entry_button = Button.new()
	_entry_button.name = "PhoneEntry"
	_entry_button.text = "CAT\nPHONE"
	_entry_button.anchor_left = 1.0
	_entry_button.anchor_top = 1.0
	_entry_button.anchor_right = 1.0
	_entry_button.anchor_bottom = 1.0
	_entry_button.offset_left = -92.0
	_entry_button.offset_top = -76.0
	_entry_button.offset_right = -16.0
	_entry_button.offset_bottom = -16.0
	PIXEL_THEME.style_button(_entry_button, PIXEL_THEME.GOLD)
	_entry_button.add_theme_font_size_override("font_size", 13)
	_entry_button.pressed.connect(open_requested.emit)
	add_child(_entry_button)
	_unread_badge = Label.new()
	_unread_badge.position = Vector2(54, -8)
	_unread_badge.add_theme_color_override("font_color", Color.WHITE)
	_unread_badge.add_theme_color_override("font_outline_color", PIXEL_THEME.DANGER)
	_unread_badge.add_theme_constant_override("outline_size", 5)
	_entry_button.add_child(_unread_badge)

	_overlay = Control.new()
	_overlay.name = "PhoneOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.035, 0.018, 0.024, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	_phone_panel = PanelContainer.new()
	_phone_panel.anchor_left = 1.0
	_phone_panel.anchor_top = 0.5
	_phone_panel.anchor_right = 1.0
	_phone_panel.anchor_bottom = 0.5
	_phone_panel.offset_left = -370.0
	_phone_panel.offset_top = -250.0
	_phone_panel.offset_right = -20.0
	_phone_panel.offset_bottom = 250.0
	_phone_panel.add_theme_stylebox_override("panel", PIXEL_THEME.panel(PIXEL_THEME.INK, PIXEL_THEME.GOLD, 4, 8))
	_overlay.add_child(_phone_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_phone_panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	outer.add_child(top)
	var back_button := Button.new()
	back_button.text = "←"
	PIXEL_THEME.style_button(back_button, PIXEL_THEME.COPPER)
	back_button.pressed.connect(back)
	top.add_child(back_button)
	var title := Label.new()
	title.text = "CAT PHONE  ·  22:30"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", PIXEL_THEME.GOLD)
	title.add_theme_color_override("font_outline_color", PIXEL_THEME.INK)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 17)
	top.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	PIXEL_THEME.style_button(close_button, PIXEL_THEME.DANGER)
	close_button.pressed.connect(close_requested.emit)
	top.add_child(close_button)
	_home = VBoxContainer.new()
	_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_home)
	var app_grid := GridContainer.new()
	app_grid.columns = 2
	app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("h_separation", 8)
	app_grid.add_theme_constant_override("v_separation", 8)
	_home.add_child(app_grid)
	_add_app_button(app_grid, "微信", open_wechat)
	_add_app_button(app_grid, "打车", press_unavailable_app.bind("打车"))
	_add_app_button(app_grid, "小红书", press_unavailable_app.bind("小红书"))
	_add_app_button(app_grid, "拍照", press_unavailable_app.bind("拍照"))
	_status_label = Label.new()
	_status_label.text = "选择一个应用"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", PIXEL_THEME.MUTED)
	_status_label.add_theme_font_size_override("font_size", 13)
	_home.add_child(_status_label)
	_page_host = MarginContainer.new()
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_page_host)
	_wechat_view = WechatView.new()
	_wechat_view.visible = false
	_page_host.add_child(_wechat_view)


func _add_app_button(parent: GridContainer, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	var available := label_text == "微信"
	button.text = ("●  " if available else "◇  ") + label_text + ("" if available else "\n即将开放")
	button.custom_minimum_size = Vector2(150, 86)
	PIXEL_THEME.style_button(button, PIXEL_THEME.WECHAT_GREEN if available else PIXEL_THEME.WOOD, not available)
	button.pressed.connect(callback)
	parent.add_child(button)


func _show_home() -> void:
	_page_stack = [&"home"]
	_home.visible = true
	_page_host.visible = false
	_wechat_view.visible = false
	if _status_label != null:
		_status_label.text = "选择一个应用"


func _update_badge() -> void:
	if _unread_badge == null:
		return
	var unread := _service.state.unread_total() if _service != null else 0
	_unread_badge.text = str(unread) if unread > 0 else ""
