extends RefCounted
class_name BartendingSessionState

enum State {
	IDLE,
	PREPARING,
	SHAKING,
	POURING,
	EVALUATING,
	READY_TO_SERVE,
	DELIVERED,
	CANCELLED,
}

var session_id: StringName = &""
var order_id: int = -1
var recipe_id: StringName = &""
var booth_id: StringName = &""
var state: State = State.IDLE

var _content: CatBarContentRegistry
var _executors: InteractionExecutorRegistry
var _draft := BartendingSessionDraft.new()
var _step_log: Array[BartendingStepLog] = []
var _last_result: DrinkResult
var _accepted_delivery_keys: Dictionary[StringName, bool] = {}


func start(
	p_session_id: StringName,
	p_order_id: int,
	p_recipe_id: StringName,
	p_booth_id: StringName,
	content: CatBarContentRegistry,
	executors: InteractionExecutorRegistry
) -> InteractionResult:
	if state != State.IDLE and state != State.CANCELLED:
		return InteractionResult.rejected("已有活动调酒会话")
	if p_session_id.is_empty() or p_order_id < 0 or p_booth_id.is_empty():
		return InteractionResult.rejected("会话绑定信息无效")
	if content == null or content.get_recipe(p_recipe_id) == null:
		return InteractionResult.rejected("配方不存在")
	session_id = p_session_id
	order_id = p_order_id
	recipe_id = p_recipe_id
	booth_id = p_booth_id
	_content = content
	_executors = executors
	_draft = BartendingSessionDraft.new()
	_step_log.clear()
	_last_result = null
	_accepted_delivery_keys.clear()
	state = State.PREPARING
	return InteractionResult.accepted(&"session_started")


func submit_command(command: InteractionCommand) -> InteractionResult:
	if _content == null or _executors == null:
		return InteractionResult.rejected("调酒会话尚未初始化")
	var definition := _content.get_interaction(command.interaction_id)
	if definition == null:
		return InteractionResult.rejected("未知交互：%s" % command.interaction_id)
	if command.gesture != definition.gesture:
		return InteractionResult.rejected("输入手势与交互配置不匹配", definition.failure_feedback_id)
	if not _command_allowed(command.interaction_id):
		return InteractionResult.rejected("当前状态不允许该交互", definition.failure_feedback_id)
	var candidate := _draft.duplicate_draft()
	var result := _executors.execute(definition.strategy_id, candidate, command, definition, _content)
	if not result.success:
		return result
	_draft = candidate
	_step_log.append(BartendingStepLog.new(command, result.applied_amount))
	if command.interaction_id == &"shake" and state == State.SHAKING:
		state = State.PREPARING
	elif command.interaction_id == &"strain_pour" and state == State.POURING:
		state = State.EVALUATING
	return result


func begin_shake(container_id: StringName = &"shaker") -> InteractionResult:
	if state != State.PREPARING:
		return InteractionResult.rejected("当前状态不能开始 Shake")
	if not _draft.is_sealed(container_id):
		return InteractionResult.rejected("Shake 前必须封盖")
	state = State.SHAKING
	return InteractionResult.accepted(&"shake_started")


func begin_pour(source_id: StringName = &"shaker") -> InteractionResult:
	if state != State.PREPARING:
		return InteractionResult.rejected("当前状态不能开始倒酒")
	if _draft.total_amount(source_id) <= 0.0:
		return InteractionResult.rejected("源容器为空")
	if float(_draft.action_totals.get(&"shake_duration", 0.0)) <= 0.0:
		return InteractionResult.rejected("配方尚未完成 Shake")
	state = State.POURING
	return InteractionResult.accepted(&"pour_started")


func evaluate_current() -> DrinkResult:
	if state != State.EVALUATING or _content == null:
		return null
	var recipe := _content.get_recipe(recipe_id)
	if recipe == null:
		return null
	_last_result = RecipeEvaluator.new().evaluate(recipe, get_step_log(), _draft.duplicate_draft(), _content)
	if _last_result.valid:
		state = State.READY_TO_SERVE
	return _last_result.copy()


func mark_delivered(delivery_key: StringName) -> bool:
	if state != State.READY_TO_SERVE or delivery_key.is_empty():
		return false
	if _accepted_delivery_keys.has(delivery_key):
		return false
	_accepted_delivery_keys[delivery_key] = true
	state = State.DELIVERED
	return true


func cancel() -> bool:
	if state == State.DELIVERED or state == State.CANCELLED or state == State.IDLE:
		return false
	state = State.CANCELLED
	_draft = BartendingSessionDraft.new()
	_step_log.clear()
	_last_result = null
	return true


func get_step_log() -> Array[BartendingStepLog]:
	var result: Array[BartendingStepLog] = []
	for entry: BartendingStepLog in _step_log:
		result.append(entry.copy())
	return result


func get_draft_snapshot() -> BartendingSessionDraft:
	return _draft.duplicate_draft()


func get_last_result() -> DrinkResult:
	return _last_result.copy() if _last_result != null else null


func make_delivery_key() -> StringName:
	return StringName("%s:%d:%s" % [session_id, order_id, booth_id])


func to_save_data() -> Dictionary:
	var logs: Array[Dictionary] = []
	for entry: BartendingStepLog in _step_log:
		logs.append(entry.to_save_data())
	var delivery_keys := PackedStringArray()
	for key: StringName in _accepted_delivery_keys:
		delivery_keys.append(String(key))
	return {
		"active": state != State.IDLE and state != State.CANCELLED and state != State.DELIVERED,
		"session_id": String(session_id), "order_id": order_id,
		"recipe_id": String(recipe_id), "booth_id": String(booth_id), "state": state,
		"draft": _draft.to_save_data(), "step_log": logs,
		"last_result": _last_result.to_save_data() if _last_result != null else {},
		"accepted_delivery_keys": delivery_keys,
	}


func restore_from_save(
	data: Dictionary,
	content: CatBarContentRegistry,
	executors: InteractionExecutorRegistry,
	deprecated_ids: Dictionary = {}
) -> bool:
	if not bool(data.get("active", false)):
		return false
	var restored_recipe_id := _mapped_id(StringName(data.get("recipe_id", "")), deprecated_ids)
	var restored_session_id := StringName(data.get("session_id", ""))
	var restored_booth_id := StringName(data.get("booth_id", ""))
	var restored_order_id := int(data.get("order_id", -1))
	if restored_session_id.is_empty() or restored_booth_id.is_empty() or restored_order_id < 0 or content.get_recipe(restored_recipe_id) == null:
		return false
	session_id = restored_session_id
	order_id = restored_order_id
	recipe_id = restored_recipe_id
	booth_id = restored_booth_id
	_content = content
	_executors = executors
	var raw_draft: Variant = data.get("draft", {})
	_draft = BartendingSessionDraft.from_save_data(raw_draft if raw_draft is Dictionary else {}, content)
	_step_log.clear()
	var raw_logs: Variant = data.get("step_log", [])
	if raw_logs is Array:
		for raw_log: Variant in raw_logs:
			if not raw_log is Dictionary:
				continue
			var log := BartendingStepLog.from_save_data(raw_log, content)
			if log != null:
				_step_log.append(log)
	_last_result = null
	var raw_result: Variant = data.get("last_result", {})
	if raw_result is Dictionary and not raw_result.is_empty():
		_last_result = DrinkResult.from_save_data(raw_result, content)
	var restored_state := clampi(int(data.get("state", State.PREPARING)), State.PREPARING, State.READY_TO_SERVE)
	state = State.PREPARING if restored_state == State.SHAKING or restored_state == State.POURING else restored_state
	if state == State.READY_TO_SERVE and (_last_result == null or not _last_result.valid):
		state = State.PREPARING
	_accepted_delivery_keys.clear()
	return true


func _mapped_id(value: StringName, deprecated_ids: Dictionary) -> StringName:
	return StringName(deprecated_ids.get(value, deprecated_ids.get(String(value), value)))


func _command_allowed(interaction_id: StringName) -> bool:
	match state:
		State.PREPARING:
			return interaction_id in [&"pour_direct", &"drop_ice", &"sprinkle", &"measure", &"stir", &"toggle_seal"]
		State.SHAKING:
			return interaction_id == &"shake"
		State.POURING:
			return interaction_id == &"strain_pour"
	return false
