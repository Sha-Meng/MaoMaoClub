extends RefCounted
class_name WechatGenerator


func generate_message(
	state: WechatState, catalog: WechatContentCatalog, event_tag: StringName
) -> WechatMessageInstance:
	var candidates: Array[WechatMessageTemplate] = []
	for template: WechatMessageTemplate in catalog.message_templates:
		if _message_eligible(template, state, event_tag):
			candidates.append(template)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: WechatMessageTemplate, b: WechatMessageTemplate) -> bool: return a.template_id < b.template_id)
	var selected := _weighted_select(candidates, state.seed, state.cursor, 17) as WechatMessageTemplate
	var author := _select_author(selected.author_ids, state, 31)
	if author.is_empty() or selected.text.strip_edges().is_empty():
		return null
	state.last_template_cursor[selected.template_id] = state.cursor
	if not selected.mutex_key.is_empty():
		state.last_mutex_cursor[selected.mutex_key] = state.cursor
	var value := WechatMessageInstance.new()
	value.instance_id = StringName("message_%d_%s" % [state.cursor, selected.template_id])
	value.author_id = author
	value.text = selected.text
	value.time_label = "第 %d 日 · 刚刚" % (state.cursor + 1)
	value.sequence = state.allocate_message_sequence()
	return value


func generate_moment(
	state: WechatState, catalog: WechatContentCatalog, event_tag: StringName
) -> WechatMomentInstance:
	var candidates: Array[WechatMomentTemplate] = []
	for template: WechatMomentTemplate in catalog.moment_templates:
		if _moment_eligible(template, state, event_tag):
			candidates.append(template)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: WechatMomentTemplate, b: WechatMomentTemplate) -> bool: return a.template_id < b.template_id)
	var selected := _weighted_select(candidates, state.seed, state.cursor, 73) as WechatMomentTemplate
	var author := _select_author(selected.author_ids, state, 97)
	if author.is_empty() or selected.text.strip_edges().is_empty():
		return null
	state.last_template_cursor[selected.template_id] = state.cursor
	if not selected.mutex_key.is_empty():
		state.last_mutex_cursor[selected.mutex_key] = state.cursor
	var value := WechatMomentInstance.new()
	value.instance_id = StringName("moment_%d_%s" % [state.cursor, selected.template_id])
	value.author_id = author
	value.text = selected.text
	value.time_label = "第 %d 日" % (state.cursor + 1)
	value.category = selected.category
	value.image_ids = selected.image_ids.duplicate()
	value.sequence = state.cursor
	return value


func _message_eligible(template: WechatMessageTemplate, state: WechatState, tag: StringName) -> bool:
	return template != null and template.trigger_tags.has(tag) and _has_unlocked_author(template.author_ids, state) and _cooled_down(template.template_id, template.cooldown_events, state) and _mutex_available(template.mutex_key, state)


func _moment_eligible(template: WechatMomentTemplate, state: WechatState, tag: StringName) -> bool:
	return template != null and template.trigger_tags.has(tag) and _has_unlocked_author(template.author_ids, state) and _cooled_down(template.template_id, template.cooldown_events, state) and _mutex_available(template.mutex_key, state)


func _has_unlocked_author(authors: Array[StringName], state: WechatState) -> bool:
	for author_id: StringName in authors:
		if state.unlocked_contact_ids.has(author_id):
			return true
	return false


func _cooled_down(template_id: StringName, cooldown: int, state: WechatState) -> bool:
	return not state.last_template_cursor.has(template_id) or state.cursor - int(state.last_template_cursor[template_id]) > cooldown


func _mutex_available(mutex_key: StringName, state: WechatState) -> bool:
	return mutex_key.is_empty() or int(state.last_mutex_cursor.get(mutex_key, -1)) != state.cursor


func _select_author(authors: Array[StringName], state: WechatState, salt: int) -> StringName:
	var available: Array[StringName] = []
	for author_id: StringName in authors:
		if state.unlocked_contact_ids.has(author_id):
			available.append(author_id)
	if available.is_empty():
		return &""
	available.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = state.seed + state.cursor * 7919 + salt
	return available[rng.randi_range(0, available.size() - 1)]


func _weighted_select(candidates: Array, seed: int, cursor: int, salt: int) -> Resource:
	var total := 0
	for candidate: Resource in candidates:
		total += maxi(int(candidate.get("weight")), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + cursor * 7919 + salt
	var roll := rng.randi_range(1, total)
	for candidate: Resource in candidates:
		roll -= maxi(int(candidate.get("weight")), 1)
		if roll <= 0:
			return candidate
	return candidates.back()
