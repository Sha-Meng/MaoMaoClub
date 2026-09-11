extends RefCounted
class_name InteractionResult

var success: bool
var reason: String
var feedback_id: StringName
var applied_amount: float


func _init(
	p_success: bool = false,
	p_reason: String = "",
	p_feedback_id: StringName = &"",
	p_applied_amount: float = 0.0
) -> void:
	success = p_success
	reason = p_reason
	feedback_id = p_feedback_id
	applied_amount = p_applied_amount


static func accepted(feedback_id: StringName, applied_amount: float = 0.0) -> InteractionResult:
	return InteractionResult.new(true, "", feedback_id, applied_amount)


static func rejected(reason: String, feedback_id: StringName = &"") -> InteractionResult:
	return InteractionResult.new(false, reason, feedback_id, 0.0)

