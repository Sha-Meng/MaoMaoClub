extends RefCounted
class_name InteractionExecutor

var strategy_id: StringName
var _executor: Callable


func _init(p_strategy_id: StringName = &"", p_executor: Callable = Callable()) -> void:
	strategy_id = p_strategy_id
	_executor = p_executor


func execute(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	if not _executor.is_valid():
		return InteractionResult.rejected("交互执行器不可用", definition.failure_feedback_id)
	return _executor.call(draft, command, definition, content) as InteractionResult

