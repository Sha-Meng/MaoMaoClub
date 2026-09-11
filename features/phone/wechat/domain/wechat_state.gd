extends RefCounted
class_name WechatState

var unlocked_contact_ids: Array[StringName] = []
var messages: Array[WechatMessageInstance] = []
var moments: Array[WechatMomentInstance] = []
var seed: int = 20260903
var cursor: int = 0
var next_message_sequence: int = 0
var processed_event_ids: Array[StringName] = []
var last_template_cursor: Dictionary[StringName, int] = {}
var last_mutex_cursor: Dictionary[StringName, int] = {}


func make_default(catalog: WechatContentCatalog) -> void:
	unlocked_contact_ids.clear()
	messages.clear()
	moments.clear()
	cursor = 0
	next_message_sequence = 0
	processed_event_ids.clear()
	last_template_cursor.clear()
	last_mutex_cursor.clear()
	for contact: WechatContactDefinition in catalog.contacts:
		if contact.initially_unlocked and not unlocked_contact_ids.has(contact.contact_id):
			unlocked_contact_ids.append(contact.contact_id)


func unread_total() -> int:
	var total := 0
	for message: WechatMessageInstance in messages:
		if message.unread:
			total += 1
	return total


func mark_conversation_read(contact_id: StringName) -> void:
	for message: WechatMessageInstance in messages:
		if message.author_id == contact_id:
			message.unread = false


func allocate_message_sequence() -> int:
	var result := next_message_sequence
	next_message_sequence += 1
	return result


func to_save_data() -> Dictionary:
	var contacts := PackedStringArray()
	for contact_id: StringName in unlocked_contact_ids:
		contacts.append(String(contact_id))
	var message_data: Array[Dictionary] = []
	for message: WechatMessageInstance in messages:
		message_data.append(message.to_save_data())
	var moment_data: Array[Dictionary] = []
	for moment: WechatMomentInstance in moments:
		moment_data.append(moment.to_save_data())
	var events := PackedStringArray()
	for event_id: StringName in processed_event_ids:
		events.append(String(event_id))
	var template_cursors: Dictionary = {}
	for template_id: StringName in last_template_cursor:
		template_cursors[String(template_id)] = last_template_cursor[template_id]
	var mutex_cursors: Dictionary = {}
	for mutex_id: StringName in last_mutex_cursor:
		mutex_cursors[String(mutex_id)] = last_mutex_cursor[mutex_id]
	return {
		"unlocked_contact_ids": contacts, "messages": message_data, "moments": moment_data,
		"seed": seed, "cursor": cursor, "next_message_sequence": next_message_sequence,
		"processed_event_ids": events,
		"last_template_cursor": template_cursors,
		"last_mutex_cursor": mutex_cursors,
	}
