extends RefCounted
class_name BartendingSessionDraft

var container_contents: Dictionary[StringName, Dictionary] = {}
var sealed_containers: Dictionary[StringName, bool] = {}
var action_totals: Dictionary[StringName, float] = {}
var poured_glass_id: StringName = &""


func duplicate_draft() -> BartendingSessionDraft:
	var result := BartendingSessionDraft.new()
	result.container_contents = container_contents.duplicate(true)
	result.sealed_containers = sealed_containers.duplicate()
	result.action_totals = action_totals.duplicate()
	result.poured_glass_id = poured_glass_id
	return result


func get_contents(container_id: StringName) -> Dictionary[StringName, float]:
	var contents: Dictionary = container_contents.get(container_id, {})
	var typed_contents: Dictionary[StringName, float] = {}
	for ingredient_id: StringName in contents:
		typed_contents[ingredient_id] = float(contents[ingredient_id])
	return typed_contents


func total_amount(container_id: StringName) -> float:
	var total := 0.0
	var contents: Dictionary = container_contents.get(container_id, {})
	for value: Variant in contents.values():
		total += float(value)
	return total


func add_content(container_id: StringName, content_id: StringName, amount: float, capacity: float) -> bool:
	if amount <= 0.0 or total_amount(container_id) + amount > capacity + 0.001:
		return false
	var contents: Dictionary = container_contents.get(container_id, {})
	contents[content_id] = float(contents.get(content_id, 0.0)) + amount
	container_contents[container_id] = contents
	return true


func transfer_all(source_id: StringName, target_id: StringName, target_capacity: float) -> float:
	var source: Dictionary = container_contents.get(source_id, {})
	var amount := total_amount(source_id)
	if source.is_empty() or amount <= 0.0 or total_amount(target_id) + amount > target_capacity + 0.001:
		return 0.0
	var target: Dictionary = container_contents.get(target_id, {})
	for content_id: StringName in source:
		target[content_id] = float(target.get(content_id, 0.0)) + float(source[content_id])
	container_contents[target_id] = target
	container_contents[source_id] = {}
	return amount


func is_sealed(container_id: StringName) -> bool:
	return bool(sealed_containers.get(container_id, false))


func set_sealed(container_id: StringName, value: bool) -> void:
	sealed_containers[container_id] = value


func add_action(metric_id: StringName, value: float) -> void:
	action_totals[metric_id] = float(action_totals.get(metric_id, 0.0)) + value


func to_save_data() -> Dictionary:
	var contents_data: Dictionary = {}
	for container_id: StringName in container_contents:
		var values: Dictionary = {}
		for content_id: StringName in container_contents[container_id]:
			values[String(content_id)] = float(container_contents[container_id][content_id])
		contents_data[String(container_id)] = values
	var sealed_data: Dictionary = {}
	for container_id: StringName in sealed_containers:
		sealed_data[String(container_id)] = sealed_containers[container_id]
	var actions_data: Dictionary = {}
	for action_id: StringName in action_totals:
		actions_data[String(action_id)] = action_totals[action_id]
	return {
		"container_contents": contents_data,
		"sealed_containers": sealed_data,
		"action_totals": actions_data,
		"poured_glass_id": String(poured_glass_id),
	}


static func from_save_data(data: Dictionary, content: CatBarContentRegistry) -> BartendingSessionDraft:
	var result := BartendingSessionDraft.new()
	var raw_contents: Variant = data.get("container_contents", {})
	if raw_contents is Dictionary:
		for raw_container_id: Variant in raw_contents:
			var container_id := StringName(raw_container_id)
			if content.get_tool(container_id) == null and content.get_glass(container_id) == null:
				continue
			var values: Variant = raw_contents[raw_container_id]
			if not values is Dictionary:
				continue
			for raw_content_id: Variant in values:
				var content_id := StringName(raw_content_id)
				if content.get_ingredient(content_id) == null:
					continue
				var amount := clampf(float(values[raw_content_id]), 0.0, 1000.0)
				if amount > 0.0:
					var container: Dictionary = result.container_contents.get(container_id, {})
					container[content_id] = amount
					result.container_contents[container_id] = container
	var raw_sealed: Variant = data.get("sealed_containers", {})
	if raw_sealed is Dictionary:
		for raw_container_id: Variant in raw_sealed:
			var container_id := StringName(raw_container_id)
			if content.get_tool(container_id) != null:
				result.sealed_containers[container_id] = bool(raw_sealed[raw_container_id])
	var raw_actions: Variant = data.get("action_totals", {})
	if raw_actions is Dictionary:
		for raw_action_id: Variant in raw_actions:
			result.action_totals[StringName(raw_action_id)] = clampf(float(raw_actions[raw_action_id]), 0.0, 100000.0)
	var glass_id := StringName(data.get("poured_glass_id", ""))
	if content.get_glass(glass_id) != null:
		result.poured_glass_id = glass_id
	return result
