extends RefCounted
class_name WechatService

signal state_changed

const DEFAULT_CATALOG: WechatContentCatalog = preload("res://features/phone/wechat/configs/default_wechat_catalog.tres")

var catalog: WechatContentCatalog
var state := WechatState.new()
var last_diagnostic: String = ""
var _generator := WechatGenerator.new()
var _reply_generator := WechatReplyGenerator.new()


func _init(content: WechatContentCatalog = DEFAULT_CATALOG) -> void:
	catalog = content
	state.make_default(catalog)
	_seed_initial_moments(catalog.initial_moment_count)


func consume_event(
	event_id: StringName,
	event_tag: StringName,
	unlock_contact_id: StringName = &""
) -> bool:
	if event_id.is_empty() or state.processed_event_ids.has(event_id):
		last_diagnostic = "事件为空或已处理"
		return false
	state.processed_event_ids.append(event_id)
	if not unlock_contact_id.is_empty() and get_contact(unlock_contact_id) != null and not state.unlocked_contact_ids.has(unlock_contact_id):
		state.unlocked_contact_ids.append(unlock_contact_id)
	var message := _generator.generate_message(state, catalog, event_tag)
	var moment := _generator.generate_moment(state, catalog, event_tag)
	state.cursor += 1
	if message != null:
		state.messages.append(message)
	if moment != null:
		state.moments.push_front(moment)
	_trim_history()
	_trim_events()
	last_diagnostic = "已生成内容" if message != null or moment != null else "没有满足条件的模板"
	state_changed.emit()
	return true


func get_contact(contact_id: StringName) -> WechatContactDefinition:
	for contact: WechatContactDefinition in catalog.contacts:
		if contact.contact_id == contact_id:
			return contact
	return null


func unlocked_contacts() -> Array[WechatContactDefinition]:
	var result: Array[WechatContactDefinition] = []
	for contact: WechatContactDefinition in catalog.contacts:
		if state.unlocked_contact_ids.has(contact.contact_id):
			result.append(contact)
	return result


func mark_conversation_read(contact_id: StringName) -> void:
	state.mark_conversation_read(contact_id)
	state_changed.emit()


func send_player_message(contact_id: StringName, raw_text: String) -> WechatMessageInstance:
	var text := raw_text.strip_edges()
	var contact := get_contact(contact_id)
	if text.is_empty():
		last_diagnostic = "消息不能为空"
		return null
	if contact == null or not state.unlocked_contact_ids.has(contact_id):
		last_diagnostic = "联系人不存在或尚未解锁"
		return null
	var player_message := WechatMessageInstance.new()
	player_message.sequence = state.allocate_message_sequence()
	player_message.instance_id = StringName("chat_%d_player_%s" % [player_message.sequence, contact_id])
	player_message.author_id = contact_id
	player_message.text = text
	player_message.time_label = "刚刚"
	player_message.unread = false
	player_message.from_player = true
	state.messages.append(player_message)

	var reply_sequence := state.allocate_message_sequence()
	var reply_text := _reply_generator.generate_reply(contact, text, state.seed, reply_sequence)
	if reply_text.is_empty():
		state.messages.pop_back()
		state.next_message_sequence = maxi(state.next_message_sequence - 2, 0)
		last_diagnostic = "联系人回复配置无可用文本"
		return null
	var reply := WechatMessageInstance.new()
	reply.sequence = reply_sequence
	reply.instance_id = StringName("chat_%d_reply_%s" % [reply.sequence, contact_id])
	reply.author_id = contact_id
	reply.text = reply_text
	reply.time_label = "刚刚"
	reply.unread = false
	reply.from_player = false
	state.messages.append(reply)
	_trim_history()
	last_diagnostic = "已发送并收到秒回"
	state_changed.emit()
	return reply


func conversation_summaries() -> Array[Dictionary]:
	var by_contact: Dictionary[StringName, Dictionary] = {}
	for message: WechatMessageInstance in state.messages:
		var summary: Dictionary = by_contact.get(message.author_id, {
			"contact_id": message.author_id, "latest_text": "", "latest_sequence": -1, "unread": 0,
		})
		if message.sequence >= int(summary["latest_sequence"]):
			summary["latest_text"] = message.text
			summary["latest_sequence"] = message.sequence
		if message.unread:
			summary["unread"] = int(summary["unread"]) + 1
		by_contact[message.author_id] = summary
	var result: Array[Dictionary] = []
	for value: Dictionary in by_contact.values():
		result.append(value.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["latest_sequence"]) > int(b["latest_sequence"]))
	return result


func restore(save_data: Dictionary, deprecated_ids: Dictionary = {}) -> void:
	var restored := WechatState.new()
	restored.make_default(catalog)
	restored.seed = int(save_data.get("seed", restored.seed))
	restored.cursor = clampi(int(save_data.get("cursor", 0)), 0, 100000000)
	restored.next_message_sequence = clampi(int(save_data.get("next_message_sequence", 0)), 0, 100000000)
	for raw_contact_id: Variant in save_data.get("unlocked_contact_ids", []):
		var contact_id := _mapped_id(raw_contact_id, deprecated_ids)
		if get_contact(contact_id) != null and not restored.unlocked_contact_ids.has(contact_id):
			restored.unlocked_contact_ids.append(contact_id)
	var seen_messages: Dictionary[StringName, bool] = {}
	for raw_message: Variant in save_data.get("messages", []):
		if not raw_message is Dictionary:
			continue
		var message := WechatMessageInstance.from_save_data(raw_message)
		message.author_id = _mapped_id(message.author_id, deprecated_ids)
		if message.instance_id.is_empty() or message.text.strip_edges().is_empty() or not restored.unlocked_contact_ids.has(message.author_id) or seen_messages.has(message.instance_id):
			continue
		seen_messages[message.instance_id] = true
		restored.messages.append(message)
		restored.next_message_sequence = maxi(restored.next_message_sequence, message.sequence + 1)
	var known_images := _known_image_ids()
	var seen_moments: Dictionary[StringName, bool] = {}
	for raw_moment: Variant in save_data.get("moments", []):
		if not raw_moment is Dictionary:
			continue
		var moment := WechatMomentInstance.from_save_data(raw_moment)
		moment.author_id = _mapped_id(moment.author_id, deprecated_ids)
		if moment.instance_id.is_empty() or moment.text.strip_edges().is_empty() or not restored.unlocked_contact_ids.has(moment.author_id) or seen_moments.has(moment.instance_id):
			continue
		var filtered_images: Array[StringName] = []
		for image_id: StringName in moment.image_ids:
			if known_images.has(image_id):
				filtered_images.append(image_id)
		moment.image_ids = filtered_images
		seen_moments[moment.instance_id] = true
		restored.moments.append(moment)
	for raw_event_id: Variant in save_data.get("processed_event_ids", []):
		var event_id := StringName(raw_event_id)
		if not event_id.is_empty() and not restored.processed_event_ids.has(event_id):
			restored.processed_event_ids.append(event_id)
	var known_templates := _known_template_ids()
	var raw_template_cursors: Variant = save_data.get("last_template_cursor", {})
	if raw_template_cursors is Dictionary:
		for raw_template_id: Variant in raw_template_cursors:
			var template_id := StringName(raw_template_id)
			if known_templates.has(template_id):
				restored.last_template_cursor[template_id] = clampi(int(raw_template_cursors[raw_template_id]), 0, restored.cursor)
	var raw_mutex_cursors: Variant = save_data.get("last_mutex_cursor", {})
	if raw_mutex_cursors is Dictionary:
		for raw_mutex_id: Variant in raw_mutex_cursors:
			var mutex_id := StringName(raw_mutex_id)
			if not mutex_id.is_empty():
				restored.last_mutex_cursor[mutex_id] = clampi(int(raw_mutex_cursors[raw_mutex_id]), 0, restored.cursor)
	state = restored
	if not save_data.has("moments"):
		_seed_initial_moments(catalog.initial_moment_count)
	_trim_history()
	_trim_events()
	state_changed.emit()


func to_save_data() -> Dictionary:
	return state.to_save_data()


func _trim_history() -> void:
	while state.messages.size() > catalog.message_history_limit:
		state.messages.pop_front()
	while state.moments.size() > catalog.moment_history_limit:
		state.moments.pop_back()


func _trim_events() -> void:
	while state.processed_event_ids.size() > catalog.processed_event_limit:
		state.processed_event_ids.pop_front()


func _mapped_id(raw_id: Variant, deprecated_ids: Dictionary) -> StringName:
	return StringName(deprecated_ids.get(raw_id, deprecated_ids.get(String(raw_id), raw_id)))


func _known_template_ids() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for template: WechatMessageTemplate in catalog.message_templates:
		result[template.template_id] = true
	for template: WechatMomentTemplate in catalog.moment_templates:
		result[template.template_id] = true
	return result


func _known_image_ids() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for template: WechatMomentTemplate in catalog.moment_templates:
		for image_id: StringName in template.image_ids:
			result[image_id] = true
	return result


func _seed_initial_moments(target_count: int) -> void:
	if target_count <= 0 or not state.moments.is_empty():
		return
	var tags: Array[StringName] = [&"new_day", &"order_delivered"]
	var attempts := 0
	while state.moments.size() < target_count and attempts < target_count * 4:
		var moment := _generator.generate_moment(state, catalog, tags[attempts % tags.size()])
		state.cursor += 1
		if moment != null:
			state.moments.push_front(moment)
		attempts += 1
	_trim_history()
