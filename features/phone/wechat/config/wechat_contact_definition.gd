extends Resource
class_name WechatContactDefinition

@export var contact_id: StringName = &""
@export var display_name: String = "好友"
@export var avatar_id: StringName = &"avatar_placeholder"
@export var relationship_label: String = "朋友"
@export var initially_unlocked: bool = false
@export var unlock_event: StringName = &""
@export_multiline var profile_summary: String = ""
@export var interests: PackedStringArray = []
@export var hobbies: PackedStringArray = []
@export var personality_traits: PackedStringArray = []
@export_multiline var reply_style: String = ""
@export var catchphrases: PackedStringArray = []
@export var greeting_replies: PackedStringArray = []
@export var question_replies: PackedStringArray = []
@export var interest_replies: PackedStringArray = []
@export var general_replies: PackedStringArray = []


func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if contact_id.is_empty():
		errors.append("contact_id 不能为空")
	if display_name.strip_edges().is_empty():
		errors.append("%s: display_name 不能为空" % contact_id)
	if avatar_id.is_empty():
		errors.append("%s: avatar_id 不能为空" % contact_id)
	if profile_summary.strip_edges().is_empty():
		errors.append("%s: profile_summary 不能为空" % contact_id)
	if interests.is_empty() or hobbies.is_empty() or personality_traits.is_empty():
		errors.append("%s: 兴趣、爱好和人格特征必须完整" % contact_id)
	if reply_style.strip_edges().is_empty():
		errors.append("%s: reply_style 不能为空" % contact_id)
	for pair: Array in [
		["greeting_replies", greeting_replies], ["question_replies", question_replies],
		["interest_replies", interest_replies], ["general_replies", general_replies],
	]:
		var values := pair[1] as PackedStringArray
		if values.is_empty():
			errors.append("%s: %s 不能为空" % [contact_id, pair[0]])
			continue
		for value: String in values:
			if value.strip_edges().is_empty():
				errors.append("%s: %s 不能包含空文本" % [contact_id, pair[0]])
	return errors
