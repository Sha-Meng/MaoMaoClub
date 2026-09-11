extends Control
class_name WechatView

const PIXEL_THEME = preload("res://features/phone/presentation/phone_pixel_theme.gd")

enum Tab { MESSAGES, CONTACTS, MOMENTS }

var _service: WechatService
var _tab: Tab = Tab.MESSAGES
var _selected_contact_id: StringName = &""
var _scroll_positions: Dictionary[int, int] = {}
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tabs: Array[Button] = []
var _chat_input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func bind(service: WechatService) -> void:
	if _service != null and _service.state_changed.is_connected(refresh):
		_service.state_changed.disconnect(refresh)
	_service = service
	if _service != null:
		_service.state_changed.connect(refresh)
	refresh()


func select_tab(tab: Tab) -> void:
	if _scroll != null:
		_scroll_positions[_tab] = _scroll.scroll_vertical
	_tab = tab
	_selected_contact_id = &""
	refresh()


func open_conversation(contact_id: StringName) -> void:
	if _service == null or not _service.state.unlocked_contact_ids.has(contact_id):
		return
	_tab = Tab.MESSAGES
	_selected_contact_id = contact_id
	_service.mark_conversation_read(contact_id)
	_render()


func activate_contact_double_click_for_test(contact_id: StringName) -> void:
	open_conversation(contact_id)


func submit_chat_text(text: String) -> bool:
	if _service == null or _selected_contact_id.is_empty():
		return false
	var sent := _service.send_player_message(_selected_contact_id, text) != null
	if sent:
		_scroll_conversation_to_bottom()
	return sent


func selected_contact_id() -> StringName:
	return _selected_contact_id


func current_tab() -> Tab:
	return _tab


func visible_entry_count() -> int:
	return _list.get_child_count() if _list != null else 0


func refresh() -> void:
	if not is_node_ready() or _list == null:
		return
	_render()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = PIXEL_THEME.PANEL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 6.0
	root.offset_top = 4.0
	root.offset_right = -6.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 7)
	add_child(root)
	_title = Label.new()
	_title.text = "微信"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", PIXEL_THEME.GOLD)
	_title.add_theme_color_override("font_outline_color", PIXEL_THEME.INK)
	_title.add_theme_constant_override("outline_size", 4)
	_title.add_theme_font_size_override("font_size", 18)
	root.add_child(_title)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root.add_child(tab_bar)
	var tab_names := ["消息", "联系人", "朋友圈"]
	for index: int in range(tab_names.size()):
		var button := Button.new()
		button.text = tab_names[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PIXEL_THEME.style_tab(button, false)
		button.pressed.connect(select_tab.bind(index as Tab))
		tab_bar.add_child(button)
		_tabs.append(button)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(300, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	_scroll.add_child(_list)
	_render()


func _render() -> void:
	_chat_input = null
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for index: int in range(_tabs.size()):
		_tabs[index].disabled = index == _tab
		PIXEL_THEME.style_tab(_tabs[index], index == _tab)
	if _service == null:
		_add_empty("微信状态尚未初始化")
		return
	if not _selected_contact_id.is_empty():
		_render_conversation()
	else:
		match _tab:
			Tab.MESSAGES:
				_render_messages()
			Tab.CONTACTS:
				_render_contacts()
			Tab.MOMENTS:
				_render_moments()
	_scroll.scroll_vertical = int(_scroll_positions.get(_tab, 0))


func _render_messages() -> void:
	_title.text = "微信 · 消息"
	var summaries := _service.conversation_summaries()
	if summaries.is_empty():
		_add_empty("暂时没有新消息")
		return
	for summary: Dictionary in summaries:
		var contact := _service.get_contact(summary["contact_id"])
		if contact == null:
			continue
		var button := Button.new()
		button.text = "%s  %s\n%s" % [contact.display_name, "(%d)" % summary["unread"] if int(summary["unread"]) > 0 else "", summary["latest_text"]]
		button.custom_minimum_size = Vector2(300, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		PIXEL_THEME.style_button(button, PIXEL_THEME.WECHAT_GREEN)
		button.pressed.connect(open_conversation.bind(contact.contact_id))
		_list.add_child(button)


func _render_conversation() -> void:
	var contact := _service.get_contact(_selected_contact_id)
	_title.text = "微信 · %s" % (contact.display_name if contact != null else "会话")
	var back := Button.new()
	back.text = "← 返回消息"
	PIXEL_THEME.style_button(back, PIXEL_THEME.COPPER)
	back.pressed.connect(func() -> void: _selected_contact_id = &""; _render())
	_list.add_child(back)
	if contact != null:
		var profile_panel := PanelContainer.new()
		profile_panel.add_theme_stylebox_override("panel", PIXEL_THEME.panel(Color("17161a"), PIXEL_THEME.WOOD, 1, 2))
		var profile := Label.new()
		profile.text = "%s｜%s" % [contact.relationship_label, contact.reply_style]
		profile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		profile.add_theme_color_override("font_color", PIXEL_THEME.MUTED)
		profile.custom_minimum_size = Vector2(290, 38)
		profile_panel.add_child(profile)
		_list.add_child(profile_panel)
	var count := 0
	for message: WechatMessageInstance in _service.state.messages:
		if message.author_id != _selected_contact_id:
			continue
		var bubble := PanelContainer.new()
		bubble.custom_minimum_size = Vector2(290, 52)
		bubble.add_theme_stylebox_override(
			"panel",
			PIXEL_THEME.panel(Color("183020"), PIXEL_THEME.WECHAT_GREEN.darkened(0.18), 2, 3)
			if message.from_player
			else PIXEL_THEME.panel(Color("2a1a1d"), PIXEL_THEME.WOOD, 2, 3)
		)
		var label := Label.new()
		var speaker := "我" if message.from_player else (contact.display_name if contact != null else "好友")
		label.text = "%s · %s\n%s" % [speaker, message.time_label, message.text]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(290, 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if message.from_player else HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_color_override("font_color", Color("c8f4ce") if message.from_player else PIXEL_THEME.CREAM)
		bubble.add_child(label)
		_list.add_child(bubble)
		count += 1
	if count == 0:
		_add_empty("还没有聊天记录")
	var composer := HBoxContainer.new()
	composer.custom_minimum_size = Vector2(300, 42)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "输入消息（好友会立即回复）"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.max_length = 280
	PIXEL_THEME.style_line_edit(_chat_input)
	_chat_input.text_submitted.connect(func(text: String) -> void: submit_chat_text(text))
	composer.add_child(_chat_input)
	var send := Button.new()
	send.text = "发送"
	PIXEL_THEME.style_button(send, PIXEL_THEME.WECHAT_GREEN)
	send.pressed.connect(func() -> void: submit_chat_text(_chat_input.text if _chat_input != null else ""))
	composer.add_child(send)
	_list.add_child(composer)


func _render_contacts() -> void:
	_title.text = "微信 · 联系人"
	var contacts := _service.unlocked_contacts()
	if contacts.is_empty():
		_add_empty("还没有联系人")
	for contact: WechatContactDefinition in contacts:
		var button := Button.new()
		button.name = "Contact_%s" % contact.contact_id
		button.text = "●  %s\n    %s · 双击聊天" % [contact.display_name, contact.relationship_label]
		button.tooltip_text = "%s\n兴趣：%s\n爱好：%s" % [contact.profile_summary, "、".join(contact.interests), "、".join(contact.hobbies)]
		button.custom_minimum_size = Vector2(300, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		PIXEL_THEME.style_button(button, _avatar_color(contact.contact_id))
		button.gui_input.connect(_on_contact_gui_input.bind(contact.contact_id))
		_list.add_child(button)


func _render_moments() -> void:
	_title.text = "微信 · 朋友圈"
	if _service.state.moments.is_empty():
		_add_empty("朋友圈还很安静")
		return
	for moment: WechatMomentInstance in _service.state.moments:
		var contact := _service.get_contact(moment.author_id)
		if contact == null:
			continue
		var card_panel := PanelContainer.new()
		card_panel.add_theme_stylebox_override("panel", PIXEL_THEME.panel(Color("23171b"), PIXEL_THEME.WOOD, 2, 3))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(300, 0)
		card.add_theme_constant_override("separation", 5)
		card_panel.add_child(card)
		var header := Label.new()
		header.text = "%s · %s\n%s" % [contact.display_name, _category_name(moment.category), moment.time_label]
		header.add_theme_color_override("font_color", PIXEL_THEME.GOLD)
		card.add_child(header)
		var text_label := Label.new()
		text_label.text = moment.text
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size = Vector2(290, 42)
		text_label.add_theme_color_override("font_color", PIXEL_THEME.CREAM)
		card.add_child(text_label)
		if not moment.image_ids.is_empty():
			var images := HBoxContainer.new()
			for image_id: StringName in moment.image_ids.slice(0, 3):
				var placeholder := ColorRect.new()
				placeholder.custom_minimum_size = Vector2(82, 56)
				placeholder.color = _avatar_color(image_id)
				placeholder.tooltip_text = String(image_id)
				placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				images.add_child(placeholder)
			card.add_child(images)
		_list.add_child(card_panel)


func _add_empty(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(300, 80)
	label.add_theme_color_override("font_color", PIXEL_THEME.MUTED)
	_list.add_child(label)


func _avatar_color(id: StringName) -> Color:
	var hue := float(abs(String(id).hash()) % 1000) / 1000.0
	return Color.from_hsv(hue, 0.38, 0.78)


func _category_name(category: StringName) -> String:
	match category:
		&"daily":
			return "日常"
		&"bar_checkin":
			return "酒吧打卡"
		&"travel_vlog":
			return "旅行 vlog"
		&"reflection":
			return "人生感悟"
		&"work_grumble":
			return "职业吐槽"
	return String(category)


func _on_contact_gui_input(event: InputEvent, contact_id: StringName) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_button.pressed and mouse_button.double_click:
		open_conversation(contact_id)
		accept_event()


func _scroll_conversation_to_bottom() -> void:
	await get_tree().process_frame
	if _scroll != null:
		_scroll.scroll_vertical = roundi(_scroll.get_v_scroll_bar().max_value)
