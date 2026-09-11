extends RefCounted
class_name PhonePixelTheme

const INK := Color("100b10")
const PANEL := Color("1d1217")
const PANEL_RAISED := Color("2a191c")
const WOOD := Color("6f3828")
const COPPER := Color("b9673b")
const GOLD := Color("e9b963")
const CREAM := Color("f6dfb8")
const MUTED := Color("aa8d7c")
const WECHAT_GREEN := Color("5cc96f")
const DANGER := Color("d66b72")


static func panel(background: Color = PANEL, border: Color = WOOD, width: int = 2, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


static func style_button(button: Button, accent: Color = COPPER, unavailable: bool = false) -> void:
	var normal_color := Color("24161b") if not unavailable else Color("1b1719")
	var normal := panel(normal_color, accent.darkened(0.32), 2, 2)
	var hover := panel(Color("342026"), accent, 2, 2)
	var pressed := panel(Color("4a2929"), GOLD, 3, 2)
	var disabled := panel(Color("171316"), Color("443138"), 2, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", CREAM if not unavailable else MUTED)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.25))
	button.add_theme_font_size_override("font_size", 15)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func style_tab(button: Button, active: bool) -> void:
	style_button(button, WECHAT_GREEN if active else WOOD)
	if active:
		button.add_theme_stylebox_override("disabled", panel(Color("183020"), WECHAT_GREEN, 2, 2))
		button.add_theme_color_override("font_disabled_color", Color("bdf3c4"))


static func style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override("normal", panel(Color("130e12"), WOOD, 2, 2))
	line_edit.add_theme_stylebox_override("focus", panel(Color("171318"), WECHAT_GREEN, 2, 2))
	line_edit.add_theme_color_override("font_color", CREAM)
	line_edit.add_theme_color_override("font_placeholder_color", MUTED)
	line_edit.add_theme_color_override("caret_color", WECHAT_GREEN)
	line_edit.add_theme_font_size_override("font_size", 14)
