extends Control
class_name HudView

var _coins_label: Label
var _xp_label: Label
var _served_label: Label
var _feedback_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()


func bind_economy(economy: EconomyState) -> void:
	economy.coins_changed.connect(set_coins)
	economy.business_xp_changed.connect(set_business_xp)
	economy.customer_served.connect(set_served_customers)
	set_coins(economy.coins)
	set_business_xp(economy.business_xp)
	set_served_customers(economy.served_customers_total)


func set_coins(value: int) -> void:
	_coins_label.text = "金币 %d" % value


func set_business_xp(value: int) -> void:
	_xp_label.text = "经营值 %d" % value


func set_served_customers(value: int) -> void:
	_served_label.text = "服务 %d" % value


func show_service_reward(coins: int, xp: int, world_pos: Vector2) -> void:
	var label: Label = Label.new()
	label.text = "+%d 金币  +%d 经营" % [coins, xp]
	label.position = world_pos
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_feedback_layer.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)


func _build_layout() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.12, 0.08, 0.06, 0.76)
	panel.position = Vector2(12.0, 10.0)
	panel.size = Vector2(328.0, 34.0)
	add_child(panel)

	_coins_label = _make_label(Vector2(24.0, 16.0), "金币 0")
	_xp_label = _make_label(Vector2(132.0, 16.0), "经营值 0")
	_served_label = _make_label(Vector2(252.0, 16.0), "服务 0")
	_feedback_layer = Control.new()
	_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_feedback_layer)


func _make_label(label_position: Vector2, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = label_position
	label.size = Vector2(110.0, 22.0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	add_child(label)
	return label
