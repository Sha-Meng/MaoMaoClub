extends RefCounted
class_name BartendingStepLog

var subject_id: StringName
var target_id: StringName
var interaction_id: StringName
var amount: float
var timestamp_msec: int
var metrics: Dictionary[StringName, float]


func _init(command: InteractionCommand = null, applied_amount: float = 0.0) -> void:
	if command == null:
		return
	subject_id = command.subject_id
	target_id = command.target_id
	interaction_id = command.interaction_id
	amount = applied_amount
	timestamp_msec = command.timestamp_msec
	metrics = command.metrics.duplicate()


func copy() -> BartendingStepLog:
	var result := BartendingStepLog.new()
	result.subject_id = subject_id
	result.target_id = target_id
	result.interaction_id = interaction_id
	result.amount = amount
	result.timestamp_msec = timestamp_msec
	result.metrics = metrics.duplicate()
	return result


func to_save_data() -> Dictionary:
	return {
		"subject_id": String(subject_id),
		"target_id": String(target_id),
		"interaction_id": String(interaction_id),
		"amount": amount,
		"timestamp_msec": timestamp_msec,
		"metrics": metrics.duplicate(),
	}


static func from_save_data(data: Dictionary, content: CatBarContentRegistry) -> BartendingStepLog:
	var result := BartendingStepLog.new()
	result.subject_id = StringName(data.get("subject_id", ""))
	result.target_id = StringName(data.get("target_id", ""))
	result.interaction_id = StringName(data.get("interaction_id", ""))
	if content.get_interaction(result.interaction_id) == null:
		return null
	result.amount = clampf(float(data.get("amount", 0.0)), 0.0, 1000.0)
	result.timestamp_msec = maxi(int(data.get("timestamp_msec", 0)), 0)
	var raw_metrics: Variant = data.get("metrics", {})
	if raw_metrics is Dictionary:
		for metric_id: Variant in raw_metrics:
			result.metrics[StringName(metric_id)] = clampf(float(raw_metrics[metric_id]), 0.0, 100000.0)
	return result
