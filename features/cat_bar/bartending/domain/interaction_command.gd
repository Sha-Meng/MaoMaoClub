extends RefCounted
class_name InteractionCommand

var subject_id: StringName
var target_id: StringName
var interaction_id: StringName
var gesture: InteractionDefinition.Gesture
var amount: float
var timestamp_msec: int
var metrics: Dictionary[StringName, float]


func _init(
	p_subject_id: StringName = &"",
	p_target_id: StringName = &"",
	p_interaction_id: StringName = &"",
	p_amount: float = 0.0,
	p_gesture: InteractionDefinition.Gesture = InteractionDefinition.Gesture.CLICK,
	p_metrics: Dictionary[StringName, float] = {}
) -> void:
	subject_id = p_subject_id
	target_id = p_target_id
	interaction_id = p_interaction_id
	amount = p_amount
	gesture = p_gesture
	metrics = p_metrics.duplicate()
	timestamp_msec = Time.get_ticks_msec()


func copy() -> InteractionCommand:
	var command := InteractionCommand.new(subject_id, target_id, interaction_id, amount, gesture, metrics)
	command.timestamp_msec = timestamp_msec
	return command

