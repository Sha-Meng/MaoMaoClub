extends Resource
class_name InteractionDefinition

enum Gesture {
	CLICK,
	HOLD,
	DRAG,
	CIRCULAR_DRAG,
	TOGGLE,
	SHAKE,
	POUR,
}

@export var interaction_id: StringName = &""
@export var gesture: Gesture = Gesture.CLICK
@export var strategy_id: StringName = &""
@export var minimum_duration_seconds: float = 0.0
@export var maximum_duration_seconds: float = 30.0
@export var minimum_distance_pixels: float = 0.0
@export var dose_multiplier: float = 1.0
@export var required_subject_tags: Array[StringName] = []
@export var required_target_tags: Array[StringName] = []
@export var success_feedback_id: StringName = &""
@export var failure_feedback_id: StringName = &""


func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if interaction_id.is_empty():
		errors.append("interaction_id 不能为空")
	if strategy_id.is_empty():
		errors.append("%s: strategy_id 不能为空" % interaction_id)
	if minimum_duration_seconds < 0.0:
		errors.append("%s: minimum_duration_seconds 不能为负数" % interaction_id)
	if maximum_duration_seconds < minimum_duration_seconds:
		errors.append("%s: maximum_duration_seconds 小于最小值" % interaction_id)
	if minimum_distance_pixels < 0.0:
		errors.append("%s: minimum_distance_pixels 不能为负数" % interaction_id)
	if dose_multiplier <= 0.0:
		errors.append("%s: dose_multiplier 必须大于 0" % interaction_id)
	return errors

