extends RefCounted
class_name InteractionExecutorRegistry

var _executors: Dictionary[StringName, InteractionExecutor] = {}


func _init() -> void:
	_register_defaults()


func strategy_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for strategy_id: StringName in _executors:
		result.append(strategy_id)
	result.sort()
	return result


func has_strategy(strategy_id: StringName) -> bool:
	return _executors.has(strategy_id)


func execute(
	strategy_id: StringName,
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	var executor := _executors.get(strategy_id) as InteractionExecutor
	if executor == null:
		return InteractionResult.rejected("未注册交互策略：%s" % strategy_id, definition.failure_feedback_id)
	return executor.execute(draft, command, definition, content)


func _register_defaults() -> void:
	_register(&"pour_fixed_dose", _execute_add_ingredient)
	_register(&"drop_ice", _execute_add_ingredient)
	_register(&"sprinkle", _execute_add_ingredient)
	_register(&"measure", _execute_transfer)
	_register(&"stir_drag", _execute_stir)
	_register(&"seal_toggle", _execute_seal)
	_register(&"shake_drag", _execute_shake)
	_register(&"strain_pour", _execute_strain)


func _register(strategy_id: StringName, callable: Callable) -> void:
	_executors[strategy_id] = InteractionExecutor.new(strategy_id, callable)


func _execute_add_ingredient(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	var ingredient := content.get_ingredient(command.subject_id)
	if ingredient == null:
		return InteractionResult.rejected("交互主体不是已注册原料", definition.failure_feedback_id)
	var capacity := _container_capacity(command.target_id, content)
	if capacity <= 0.0:
		return InteractionResult.rejected("目标不是可接收容器", definition.failure_feedback_id)
	if draft.is_sealed(command.target_id):
		return InteractionResult.rejected("目标容器已封闭", definition.failure_feedback_id)
	var amount := command.amount if command.amount > 0.0 else ingredient.default_dose * definition.dose_multiplier
	if not draft.add_content(command.target_id, ingredient.content_id, amount, capacity):
		return InteractionResult.rejected("目标容量不足或剂量非法", definition.failure_feedback_id)
	return InteractionResult.accepted(definition.success_feedback_id, amount)


func _execute_transfer(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	if draft.is_sealed(command.target_id):
		return InteractionResult.rejected("目标容器已封闭", definition.failure_feedback_id)
	var capacity := _container_capacity(command.target_id, content)
	if capacity <= 0.0:
		return InteractionResult.rejected("目标不是可接收容器", definition.failure_feedback_id)
	var transferred := draft.transfer_all(command.subject_id, command.target_id, capacity)
	if transferred <= 0.0:
		return InteractionResult.rejected("量酒杯为空或目标容量不足", definition.failure_feedback_id)
	return InteractionResult.accepted(definition.success_feedback_id, transferred)


func _execute_stir(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	_content: CatBarContentRegistry
) -> InteractionResult:
	if draft.is_sealed(command.target_id):
		return InteractionResult.rejected("封闭容器不能搅拌", definition.failure_feedback_id)
	if draft.total_amount(command.target_id) <= 0.0:
		return InteractionResult.rejected("空容器不能搅拌", definition.failure_feedback_id)
	var duration := float(command.metrics.get(&"duration", command.amount))
	var distance := float(command.metrics.get(&"distance", 0.0))
	if duration < definition.minimum_duration_seconds or distance < definition.minimum_distance_pixels:
		return InteractionResult.rejected("搅拌时长或轨迹不足", definition.failure_feedback_id)
	draft.add_action(&"stir_duration", duration)
	draft.add_action(&"stir_distance", distance)
	draft.add_action(&"stir_reversals", float(command.metrics.get(&"reversals", 0.0)))
	return InteractionResult.accepted(definition.success_feedback_id, duration)


func _execute_seal(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	var tool := content.get_tool(command.subject_id)
	if tool == null or not tool.capability_tags.has(&"sealable"):
		return InteractionResult.rejected("主体不是可封盖器具", definition.failure_feedback_id)
	if draft.total_amount(command.subject_id) <= 0.0:
		return InteractionResult.rejected("空杯不能开始封盖调酒", definition.failure_feedback_id)
	draft.set_sealed(command.subject_id, not draft.is_sealed(command.subject_id))
	draft.add_action(&"seal_toggle_count", 1.0)
	return InteractionResult.accepted(definition.success_feedback_id, 1.0)


func _execute_shake(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	_content: CatBarContentRegistry
) -> InteractionResult:
	if not draft.is_sealed(command.subject_id):
		return InteractionResult.rejected("Shake 前必须封盖", definition.failure_feedback_id)
	var duration := float(command.metrics.get(&"duration", command.amount))
	var distance := float(command.metrics.get(&"distance", 0.0))
	if duration < definition.minimum_duration_seconds or distance < definition.minimum_distance_pixels:
		return InteractionResult.rejected("Shake 时长或往复距离不足", definition.failure_feedback_id)
	draft.add_action(&"shake_duration", duration)
	draft.add_action(&"shake_distance", distance)
	draft.add_action(&"shake_reversals", float(command.metrics.get(&"reversals", 0.0)))
	draft.add_action(&"shake_peak_speed", float(command.metrics.get(&"peak_speed", 0.0)))
	return InteractionResult.accepted(definition.success_feedback_id, duration)


func _execute_strain(
	draft: BartendingSessionDraft,
	command: InteractionCommand,
	definition: InteractionDefinition,
	content: CatBarContentRegistry
) -> InteractionResult:
	var target_glass := content.get_glass(command.target_id)
	if target_glass == null:
		return InteractionResult.rejected("目标不是已注册酒杯", definition.failure_feedback_id)
	if draft.is_sealed(command.subject_id):
		draft.set_sealed(command.subject_id, false)
	var transferred := draft.transfer_all(command.subject_id, command.target_id, target_glass.capacity_ml)
	if transferred <= 0.0:
		return InteractionResult.rejected("源容器为空或酒杯容量不足", definition.failure_feedback_id)
	draft.poured_glass_id = command.target_id
	return InteractionResult.accepted(definition.success_feedback_id, transferred)


func _container_capacity(content_id: StringName, content: CatBarContentRegistry) -> float:
	var tool := content.get_tool(content_id)
	if tool != null:
		return tool.capacity_ml
	var glass := content.get_glass(content_id)
	if glass != null:
		return glass.capacity_ml
	return 0.0
