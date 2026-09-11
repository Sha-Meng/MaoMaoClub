extends RefCounted
class_name WechatReplyGenerator

const GREETING_WORDS := ["你好", "嗨", "hello", "hi", "早上好", "晚上好", "在吗"]
const QUESTION_MARKS := ["?", "？", "吗", "怎么", "为什么", "怎样", "要不要"]


func generate_reply(
	contact: WechatContactDefinition,
	player_text: String,
	seed: int,
	message_sequence: int
) -> String:
	if contact == null or player_text.strip_edges().is_empty():
		return ""
	var cleaned := player_text.strip_edges()
	var matched_topic := _matched_topic(contact, cleaned)
	var pool := contact.general_replies
	if _contains_any(cleaned.to_lower(), GREETING_WORDS):
		pool = contact.greeting_replies
	elif _contains_any(cleaned, QUESTION_MARKS):
		pool = contact.question_replies
	elif not matched_topic.is_empty():
		pool = contact.interest_replies
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + message_sequence * 104729 + abs(String(contact.contact_id).hash())
	var reply := pool[rng.randi_range(0, pool.size() - 1)]
	var fallback_topic := contact.interests[0] if not contact.interests.is_empty() else "这件事"
	reply = reply.replace("{topic}", matched_topic if not matched_topic.is_empty() else fallback_topic)
	if not contact.catchphrases.is_empty() and message_sequence % 3 == 2:
		reply = "%s %s" % [reply, contact.catchphrases[message_sequence % contact.catchphrases.size()]]
	return reply.strip_edges()


func _matched_topic(contact: WechatContactDefinition, text: String) -> String:
	for topic: String in contact.interests:
		if text.contains(topic):
			return topic
	for hobby: String in contact.hobbies:
		if text.contains(hobby):
			return hobby
	return ""


func _contains_any(text: String, needles: Array) -> bool:
	for needle: Variant in needles:
		if text.contains(String(needle)):
			return true
	return false
