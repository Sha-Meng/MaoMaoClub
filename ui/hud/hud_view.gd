extends Control
class_name HudView

signal window_drag_requested(window_local_position: Vector2)
signal minimize_requested
signal quit_requested
signal scale_requested(value: float)
signal layout_edited
signal interaction_changed

var simulation: TavernSimulation
var world: TavernWorldView
var selected_id: String = ""
var panel_open: bool = false
var _toolbar: PanelContainer
var _panel: PanelContainer
var _content: VBoxContainer
var _coins: Label
var _summary: Label
var _detail: Label
var _selection: Label
var _remove: Button
var _status: Label
var _tab: String = "经营"
var _elapsed: float = 0.0
var _selected_profile: String = "manager"
var _theme_font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TavernLayout.SIZE
	_theme_font = SystemFont.new()
	_theme_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font = _theme_font
	ui_theme.default_font_size = 12
	theme = ui_theme


func configure(model: TavernSimulation, world_view: TavernWorldView) -> void:
	simulation = model
	world = world_view
	_build_toolbar()
	_build_panel()
	refresh()


func _process(delta: float) -> void:
	if simulation == null:
		return
	_elapsed += delta
	if _elapsed >= 0.35:
		_elapsed = 0.0
		refresh()


func refresh() -> void:
	if _toolbar == null:
		return
	_coins.text = "营业中 · 常驻   金币 %d" % simulation.coins
	var shop: Vector2 = simulation.layout.shop_position()
	_toolbar.position = Vector2(clampf(shop.x - 120.0, 6.0, 714.0), maxf(5.0, shop.y - 173.0))
	if _summary != null and is_instance_valid(_summary):
		_summary.text = "金币  %d     经营值  %d\n累计服务  %d 位\n店内顾客  %d / %d    座位  %d\n已完成闲聊  %d 次" % [simulation.coins, simulation.business_xp, simulation.served_total, simulation.guest_count(), TavernSimulation.MAX_GUESTS, simulation.layout.chair_ids().size(), simulation.chats_completed]
	if _detail != null and is_instance_valid(_detail):
		var profile: Dictionary = CastCatalog.profile(_selected_profile)
		_detail.text = "%s · %s\n%s\n\n%s\n\n%s" % [profile["name"], profile["trait"], profile["body"], profile["description"], _current_activity(_selected_profile)]
	if _selection != null and is_instance_valid(_selection):
		_selection.text = "当前选择：" + selection_name()
	if _remove != null and is_instance_valid(_remove):
		_remove.disabled = not simulation.layout.objects.has(selected_id) or selected_id == "shop"
	_panel.position = Vector2(clampf(shop.x - 154.0, 5.0, 647.0), 5.0)


func selection_name() -> String:
	if simulation.people.has(selected_id):
		var person: TavernPerson = simulation.people[selected_id] as TavernPerson
		return str(CastCatalog.profile(person.profile_id)["name"])
	if simulation.layout.objects.has(selected_id):
		return {"shop": "店铺", "chair": "座椅", "table": "小桌"}.get(str(simulation.layout.objects[selected_id]["kind"]), "")
	return "点选店铺、人物或家具"


func _current_activity(profile_id: String) -> String:
	for person: TavernPerson in simulation.people.values():
		if person.profile_id == profile_id:
			var names: Dictionary = {"walk": "走动中", "carry_tray": "端盘送饮", "mix_drink": "调制饮品", "pour_drink": "倒入杯中", "place_drink": "整齐出杯", "serve_drink": "轻放酒杯", "collect_glass": "收空杯", "drink": "喝一口", "chat": "正在说话", "listen": "认真倾听", "drag_hold": "正在被移动", "land": "站稳脚步", "story": "分享故事", "loosen_tie": "松开领带", "slow_nod": "慢慢点头", "quip": "轻松逗趣", "sketch": "画两笔", "phone": "抬眼收手机", "greet": "招呼客人", "align_glass": "整理杯子", "apron": "整理围裙", "pay": "付款道谢", "sit_down": "坐下", "stand_up": "起身"}
			names.merge({"order": "点单", "receive_drink": "接过饮品", "wipe_glass": "擦杯子", "wipe_counter": "擦吧台", "pickup_bottle": "整理酒瓶", "toast": "举杯致意", "adjust_chain": "整理项链", "laugh": "开心地笑", "show_sketch": "分享画本", "wipe_table": "擦桌子", "take_tray": "取托盘"})
			return "现在：" + str(names.get(person.action, "自在待着"))
	return "这位顾客还在路上，会自动轮换来店。"


func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.name = "ResidentToolbar"
	_toolbar.add_theme_stylebox_override("panel", _style(Color(0.16, 0.12, 0.09, 0.84)))
	add_child(_toolbar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_toolbar.add_child(row)
	_coins = Label.new()
	_coins.custom_minimum_size = Vector2(173.0, 23.0)
	_coins.add_theme_color_override("font_color", Color("f4deb0"))
	_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_coins)
	var move: Button = _button("MoveWindow", "↔", row)
	move.custom_minimum_size = Vector2(25.0, 23.0)
	move.tooltip_text = "按住拖动整个酒馆窗口"
	move.gui_input.connect(func(event: InputEvent) -> void:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			window_drag_requested.emit(mouse.global_position))
	var menu: Button = _button("MenuButton", "⋯", row)
	menu.custom_minimum_size = Vector2(25.0, 23.0)
	menu.tooltip_text = "经营、人物与自由摆放"
	menu.pressed.connect(func() -> void: set_panel_open(not panel_open))


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "SummaryPanel"
	_panel.custom_minimum_size = Vector2(308.0, 265.0)
	_panel.size = Vector2(308.0, 265.0)
	_panel.add_theme_stylebox_override("panel", _style(Color(0.14, 0.11, 0.09, 0.97)))
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = Label.new()
	title.text = "猫猫 Club"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button("PanelClose", "×", header).pressed.connect(func() -> void: set_panel_open(false))
	var tabs: HBoxContainer = HBoxContainer.new()
	column.add_child(tabs)
	for title_text: String in ["经营", "人物", "摆放"]:
		var tab_button: Button = _button("Tab" + title_text, title_text, tabs)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(_show_tab.bind(title_text))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290.0, 133.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(285.0, 0.0)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	var footer: HBoxContainer = HBoxContainer.new()
	column.add_child(footer)
	var scale_picker: OptionButton = OptionButton.new()
	scale_picker.name = "ScaleSelector"
	for text: String in ["80%", "100%", "120%"]:
		scale_picker.add_item(text)
	scale_picker.selected = clampi(roundi((simulation.display_scale - 0.8) / 0.2), 0, 2)
	scale_picker.item_selected.connect(func(index: int) -> void:
		simulation.display_scale = [0.8, 1.0, 1.2][index]
		scale_requested.emit(simulation.display_scale)
		layout_edited.emit())
	footer.add_child(scale_picker)
	var minimize: Button = _button("Minimize", "最小化", footer)
	minimize.pressed.connect(minimize_requested.emit)
	var quit_button: Button = _button("Quit", "保存退出", footer)
	quit_button.pressed.connect(quit_requested.emit)
	_status = Label.new()
	_status.text = "横向拖动摆位 · 调酒员固定 · Esc 收起"
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color("cbb791"))
	column.add_child(_status)
	_show_tab("经营")
	set_panel_open(false)


func _show_tab(title_text: String) -> void:
	_tab = title_text
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_summary = null
	_detail = null
	_selection = null
	_remove = null
	match title_text:
		"经营":
			_summary = _label("", _content)
			_label("顾客会自动入座、点单与消费。\n店长陪大家聊天，店员负责营业。", _content)
		"人物":
			var picker: OptionButton = OptionButton.new()
			picker.name = "CharacterPicker"
			var ids: Array[String] = CastCatalog.all_ids()
			for id: String in ids:
				picker.add_item(str(CastCatalog.profile(id)["name"]) + " · " + str(CastCatalog.profile(id)["trait"]))
			picker.selected = maxi(0, ids.find(_selected_profile))
			picker.item_selected.connect(func(index: int) -> void:
				_selected_profile = ids[index]
				refresh())
			_content.add_child(picker)
			_detail = _label("", _content)
		"摆放":
			var toggle: CheckButton = CheckButton.new()
			toggle.name = "ArrangementToggle"
			toggle.text = "摆放模式（优先选中家具）"
			toggle.button_pressed = world.edit_mode
			toggle.toggled.connect(func(enabled: bool) -> void: world.edit_mode = enabled)
			_content.add_child(toggle)
			_selection = _label("", _content)
			var row: HBoxContainer = HBoxContainer.new()
			_content.add_child(row)
			_button("AddChair", "+ 座椅", row).pressed.connect(_add_furniture.bind("chair"))
			_button("AddTable", "+ 小桌", row).pressed.connect(_add_furniture.bind("table"))
			_remove = _button("RemoveSelected", "移除", row)
			_remove.pressed.connect(func() -> void:
				if simulation.remove_furniture(selected_id):
					selected_id = ""
					world.selected_id = ""
					layout_edited.emit()
					refresh())
			_button("ResetLayout", "恢复默认布局", _content).pressed.connect(func() -> void:
				world.cancel_pointer()
				simulation.reset_layout()
				layout_edited.emit()
				refresh())
	refresh()


func _add_furniture(kind: String) -> void:
	selected_id = simulation.layout.add_furniture(kind)
	world.selected_id = selected_id
	world.edit_mode = true
	_show_tab("摆放")
	layout_edited.emit()
	if selected_id.is_empty():
		show_status("家具已达到上限，请先移除一些。")


func object_activated(id: String) -> void:
	selected_id = id
	var person: TavernPerson = simulation.people.get(id) as TavernPerson
	if person != null:
		simulation.click_person(id)
		_selected_profile = person.profile_id
		_show_tab("人物")
	elif id == "shop":
		_show_tab("经营")
		set_panel_open(not panel_open)
	else:
		_show_tab("摆放")
		set_panel_open(true)
	refresh()


func set_selection(id: String) -> void:
	selected_id = id
	refresh()


func set_panel_open(value: bool) -> void:
	panel_open = value
	_panel.visible = value
	refresh()
	interaction_changed.emit()


func show_status(message: String) -> void:
	if _status != null:
		_status.text = message


func interaction_bounds() -> Rect2:
	return Rect2(_panel.position, _panel.size) if panel_open else Rect2(_toolbar.position, _toolbar.size)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_panel_open(false)
		world.edit_mode = false
		world.cancel_pointer()
		get_viewport().set_input_as_handled()


func _button(id: String, text: String, parent: Node) -> Button:
	var result: Button = Button.new()
	result.name = id
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size.y = 23.0
	result.add_theme_color_override("font_color", Color("f6e3be"))
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		result.add_theme_stylebox_override(state_name, _style(Color("493a2c") if state_name == "normal" else Color("65533b")))
	parent.add_child(result)
	return result


func _label(text: String, parent: Node) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 278.0
	result.add_theme_color_override("font_color", Color("f1dfbd"))
	parent.add_child(result)
	return result


func _style(color: Color) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = Color(0.65, 0.51, 0.32, 0.7)
	result.set_border_width_all(1)
	result.set_corner_radius_all(6)
	result.content_margin_left = 6.0
	result.content_margin_right = 6.0
	result.content_margin_top = 3.0
	result.content_margin_bottom = 3.0
	return result
