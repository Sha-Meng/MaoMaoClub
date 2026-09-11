extends Control
class_name BartendingStation

signal drink_ready(result: DrinkResult)
signal interaction_feedback(success: bool, reason: String, feedback_id: StringName)
signal session_cancelled
signal exit_requested(instant: bool)

const DEFAULT_CATALOG: CatBarContentCatalog = preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")

@export var content_catalog: CatBarContentCatalog = DEFAULT_CATALOG
@export var auto_start_session: bool = true

var _content := CatBarContentRegistry.new()
var _executors := InteractionExecutorRegistry.new()
var _session := BartendingSessionState.new()
var _input_router: BartendingInputRouter
var _vessel_adapter: MixingVesselAdapter
var _vessel_view: ShakerVesselView
var _content_buttons: Dictionary[StringName, Button] = {}
var _status_label: Label
var _target_label: Label
var _recipe_label: Label
var _shake_button: Button
var _spoon_drag_ghost: TextureRect
var _selected_tool_id: StringName = &""
var _shake_active: bool = false
var _spoon_drag_active: bool = false
var _spoon_drag_started_msec: int = 0
var _spoon_drag_distance: float = 0.0
var _spoon_previous_position: Vector2 = Vector2.ZERO
var _spoon_previous_delta: Vector2 = Vector2.ZERO
var _spoon_drag_reversals: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(760.0, 340.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	var errors := CatBarContentValidator.new().validate(content_catalog, _executors.strategy_ids())
	if not errors.is_empty():
		_build_error_view(errors)
		return
	_content.build(content_catalog)
	_build_presentation()
	if auto_start_session:
		start_session(&"standalone_session", 1, &"moonlit_meow", &"booth_a")


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_exit()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	var button := event as InputEventMouseButton
	if _spoon_drag_active:
		if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_spoon_drag(_viewport_to_local(motion.position))
			get_viewport().set_input_as_handled()
			return
		if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_finish_spoon_drag(_viewport_to_local(button.position))
			get_viewport().set_input_as_handled()
			return
	if not _shake_active:
		return
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_vessel_adapter.apply_shake_delta(motion.relative, maxf(get_process_delta_time(), 1.0 / 60.0))
		get_viewport().set_input_as_handled()
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish_shake()
		get_viewport().set_input_as_handled()


func start_session(
	session_id: StringName,
	order_id: int,
	recipe_id: StringName,
	booth_id: StringName
) -> InteractionResult:
	var result := _session.start(session_id, order_id, recipe_id, booth_id, _content, _executors)
	_set_feedback(result)
	_update_view()
	return result


func reset_session() -> void:
	_cancel_current_session()
	_session = BartendingSessionState.new()
	start_session(&"session_%d" % Time.get_ticks_msec(), 1, &"moonlit_meow", &"booth_a")


func prepare_for_entry() -> bool:
	if _session.state != BartendingSessionState.State.IDLE and _session.state != BartendingSessionState.State.CANCELLED and _session.state != BartendingSessionState.State.DELIVERED:
		return false
	_session = BartendingSessionState.new()
	var result := start_session(
		&"session_%d" % Time.get_ticks_msec(),
		maxi(_session.order_id, 1),
		&"moonlit_meow",
		&"booth_a"
	)
	return result.success


func request_exit(instant: bool = false) -> bool:
	if _session.state == BartendingSessionState.State.READY_TO_SERVE or _session.state == BartendingSessionState.State.DELIVERED:
		return false
	_cancel_current_session()
	exit_requested.emit(instant)
	return true


func request_exit_for_test(instant: bool = true) -> bool:
	return request_exit(instant)


func _cancel_current_session() -> void:
	if _shake_active:
		_vessel_adapter.cancel_shake()
	_shake_active = false
	if _shake_button != null:
		_shake_button.text = "开始 Shake"
	if _input_router != null:
		_input_router.cancel_pointer_capture()
	_cancel_spoon_drag()
	_selected_tool_id = &""
	if _vessel_adapter != null:
		_vessel_adapter.reset()
	_session.cancel()
	session_cancelled.emit()
	_update_view()


func click_content(content_id: StringName) -> void:
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		var target_id := &"jigger" if ingredient.category == IngredientDefinition.Category.LIQUID and _selected_tool_id == &"jigger" else &"shaker"
		_input_router.route_click(ingredient.content_id, target_id, ingredient.interaction_id)
		return
	var tool := _content.get_tool(content_id)
	if tool != null:
		_handle_tool_clicked(tool)
		return
	if _content.get_glass(content_id) != null:
		_selected_tool_id = content_id
		_update_view()


func submit_stir_gesture(distance_pixels: float, duration_seconds: float, reversals: float = 0.0) -> InteractionResult:
	var command := InteractionCommand.new(
		&"bar_spoon",
		&"shaker",
		&"stir",
		duration_seconds,
		InteractionDefinition.Gesture.CIRCULAR_DRAG,
		{&"duration": duration_seconds, &"distance": distance_pixels, &"reversals": reversals}
	)
	return _submit_command(command)


func begin_spoon_drag_for_test(local_position: Vector2) -> bool:
	return _begin_spoon_drag(local_position)


func update_spoon_drag_for_test(local_position: Vector2) -> void:
	_update_spoon_drag(local_position)


func end_spoon_drag_for_test(local_position: Vector2, duration_seconds: float) -> InteractionResult:
	return _finish_spoon_drag(local_position, duration_seconds)


func get_spoon_drop_target_rect() -> Rect2:
	if _vessel_view == null:
		return Rect2()
	return Rect2(_vessel_view.position - _vessel_view.vessel_size * 0.5, _vessel_view.vessel_size)


func toggle_seal() -> void:
	_input_router.route_gesture(
		&"shaker", &"shaker", &"toggle_seal", InteractionDefinition.Gesture.TOGGLE, 1.0, {}
	)


func begin_shake() -> bool:
	if _shake_active:
		return false
	var result := _session.begin_shake()
	if not result.success or not _vessel_adapter.begin_shake():
		_set_feedback(result)
		return false
	_input_router.begin_pointer_capture()
	_shake_active = true
	_shake_button.text = "拖拽摇杯，松开结束"
	_set_feedback(InteractionResult.accepted(&"shake_started"))
	_update_view()
	return true


func complete_shake_for_test(metrics: Dictionary[StringName, float]) -> InteractionResult:
	if _session.state == BartendingSessionState.State.PREPARING:
		var begin_result := _session.begin_shake()
		if not begin_result.success:
			return begin_result
	var command := InteractionCommand.new(
		&"shaker",
		&"shaker",
		&"shake",
		float(metrics.get(&"duration", 0.0)),
		InteractionDefinition.Gesture.SHAKE,
		metrics
	)
	return _submit_command(command)


func pour_to_glass() -> InteractionResult:
	var begin_result := _session.begin_pour()
	if not begin_result.success:
		_set_feedback(begin_result)
		return begin_result
	var command := InteractionCommand.new(
		&"shaker", &"coupe_glass", &"strain_pour", 0.0, InteractionDefinition.Gesture.POUR
	)
	var result := _submit_command(command)
	if result.success:
		var drink_result := _session.evaluate_current()
		if drink_result != null and drink_result.valid:
			drink_ready.emit(drink_result)
	_update_view()
	return result


func get_session() -> BartendingSessionState:
	return _session


func get_content_button_count() -> int:
	return _content_buttons.size()


func get_zone_count() -> int:
	return content_catalog.station_layout.zones.size()


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func restore_session(save_data: Dictionary, deprecated_ids: Dictionary = {}) -> bool:
	var restored := BartendingSessionState.new()
	if not restored.restore_from_save(save_data, _content, _executors, deprecated_ids):
		return false
	_input_router.cancel_pointer_capture()
	_shake_active = false
	_selected_tool_id = &""
	_vessel_adapter.reset()
	_session = restored
	var draft := _session.get_draft_snapshot()
	for ingredient_id: StringName in draft.get_contents(&"shaker"):
		var ingredient := _content.get_ingredient(ingredient_id)
		if ingredient == null:
			continue
		if ingredient.category == IngredientDefinition.Category.LIQUID:
			_vessel_adapter.add_fluid(ingredient.fluid_id)
		elif ingredient.category == IngredientDefinition.Category.ICE:
			_vessel_adapter.add_ice(roundi(draft.get_contents(&"shaker")[ingredient_id]))
	_vessel_adapter.set_sealed(draft.is_sealed(&"shaker"))
	_update_view()
	return true


func _build_presentation() -> void:
	var background := ColorRect.new()
	background.name = "WorkbenchBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.075, 0.052, 0.06, 0.98)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.text = "CAT BAR · 调酒台"
	title.position = Vector2(22.0, 12.0)
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)

	_input_router = BartendingInputRouter.new()
	_input_router.name = "InputRouter"
	_input_router.command_created.connect(_on_command_created)
	add_child(_input_router)

	_vessel_adapter = MixingVesselAdapter.new()
	_vessel_adapter.name = "MixingVesselAdapter"
	add_child(_vessel_adapter)
	_vessel_view = ShakerVesselView.new()
	_vessel_view.name = "ShakerVesselView"
	_vessel_view.position = Vector2(485.0, 178.0)
	add_child(_vessel_view)
	_vessel_view.bind(_vessel_adapter)

	for zone: StationZoneDefinition in content_catalog.station_layout.zones:
		_build_zone(zone)
	_build_spoon_drag_ghost()

	_target_label = Label.new()
	_target_label.position = Vector2(20.0, 246.0)
	_target_label.size = Vector2(340.0, 24.0)
	add_child(_target_label)
	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 274.0)
	_status_label.size = Vector2(430.0, 52.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_recipe_label = Label.new()
	_recipe_label.position = Vector2(565.0, 48.0)
	_recipe_label.size = Vector2(180.0, 150.0)
	_recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_recipe_label)
	_recipe_label.text = "月夜猫语\n量取月光金酒 30 ml\n暮色甜酒 30 ml\n冰块 ×2 / 猫薄荷 ×1\n封盖 → Shake → 倒杯"

	_add_action_button("封盖/开盖", Vector2(490.0, 268.0), toggle_seal)
	_shake_button = _add_action_button("开始 Shake", Vector2(585.0, 268.0), begin_shake)
	_add_action_button("倒入酒杯", Vector2(675.0, 268.0), pour_to_glass)
	_add_action_button("返回大厅", Vector2(585.0, 305.0), request_exit)
	_add_action_button("重置", Vector2(675.0, 305.0), reset_session)

	var feedback_audio := AudioStreamPlayer.new()
	feedback_audio.name = "FeedbackAudioPlaceholder"
	add_child(feedback_audio)


func _build_zone(zone: StationZoneDefinition) -> void:
	for slot: StationSlotDefinition in zone.slots:
		if not slot.enabled:
			continue
		var button := Button.new()
		button.name = "Content_%s" % slot.content_id
		button.text = _display_name(slot.content_id)
		button.position = Vector2(slot.anchor_pixels)
		button.size = Vector2(96.0, 50.0)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var definition := _get_content_definition(slot.content_id)
		if definition != null and definition.icon_texture != null:
			button.text = ""
			button.size.y = 64.0
			button.icon = definition.icon_texture
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var name_label := Label.new()
			name_label.text = _display_name(slot.content_id)
			name_label.position = Vector2(2.0, 43.0)
			name_label.size = Vector2(92.0, 19.0)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.05, 1.0))
			name_label.add_theme_constant_override("outline_size", 4)
			button.add_child(name_label)
		button.tooltip_text = "%s · %s" % [zone.display_name, _display_name(slot.content_id)]
		button.pressed.connect(click_content.bind(slot.content_id))
		if slot.content_id == &"bar_spoon":
			button.gui_input.connect(_on_spoon_gui_input)
		add_child(button)
		_content_buttons[slot.content_id] = button


func _display_name(content_id: StringName) -> String:
	var tool := _content.get_tool(content_id)
	if tool != null:
		return tool.display_name
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		return ingredient.display_name
	var glass := _content.get_glass(content_id)
	return glass.display_name if glass != null else String(content_id)


func _get_content_definition(content_id: StringName) -> CatBarContentDefinition:
	var tool := _content.get_tool(content_id)
	if tool != null:
		return tool
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		return ingredient
	return _content.get_glass(content_id)


func _handle_tool_clicked(tool: ToolDefinition) -> void:
	match tool.content_id:
		&"jigger":
			if _session.get_draft_snapshot().total_amount(&"jigger") > 0.0:
				_input_router.route_gesture(&"jigger", &"shaker", &"measure", InteractionDefinition.Gesture.DRAG, 0.0, {})
			else:
				_selected_tool_id = &"" if _selected_tool_id == &"jigger" else &"jigger"
				_update_view()
		&"bar_spoon":
			_selected_tool_id = &"bar_spoon"
			_status_label.text = "按住长柄勺，把它拖进开放的 Shake 杯内搅拌后松开。"
		&"shaker":
			toggle_seal()


func _on_command_created(command: InteractionCommand) -> void:
	_submit_command(command)


func _submit_command(command: InteractionCommand) -> InteractionResult:
	var before := _session.get_draft_snapshot()
	var result := _session.submit_command(command)
	if result.success:
		_apply_visual_command(command, result, before)
		if command.interaction_id == &"measure":
			_selected_tool_id = &""
		_pulse_content(command.subject_id)
	_set_feedback(result)
	_update_view()
	return result


func _apply_visual_command(
	command: InteractionCommand,
	result: InteractionResult,
	before: BartendingSessionDraft
) -> void:
	var ingredient := _content.get_ingredient(command.subject_id)
	if ingredient != null and command.target_id == &"shaker":
		if ingredient.category == IngredientDefinition.Category.LIQUID:
			_vessel_adapter.add_fluid(ingredient.fluid_id)
		elif ingredient.category == IngredientDefinition.Category.ICE:
			_vessel_adapter.add_ice(roundi(result.applied_amount))
	elif command.interaction_id == &"measure":
		for ingredient_id: StringName in before.get_contents(command.subject_id):
			var measured_ingredient := _content.get_ingredient(ingredient_id)
			if measured_ingredient != null and measured_ingredient.category == IngredientDefinition.Category.LIQUID:
				_vessel_adapter.add_fluid(measured_ingredient.fluid_id)
	elif command.interaction_id == &"toggle_seal":
		_vessel_adapter.set_sealed(_session.get_draft_snapshot().is_sealed(&"shaker"))


func _finish_shake() -> void:
	var metrics := _vessel_adapter.end_shake()
	_shake_active = false
	_input_router.end_pointer_capture()
	_shake_button.text = "开始 Shake"
	_input_router.route_gesture(
		&"shaker", &"shaker", &"shake", InteractionDefinition.Gesture.SHAKE,
		float(metrics.get(&"duration", 0.0)), metrics
	)
	_update_view()


func _on_spoon_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	_begin_spoon_drag(_viewport_to_local(button.global_position))
	accept_event()


func _build_spoon_drag_ghost() -> void:
	_spoon_drag_ghost = TextureRect.new()
	_spoon_drag_ghost.name = "SpoonDragGhost"
	_spoon_drag_ghost.size = Vector2(82.0, 72.0)
	_spoon_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spoon_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spoon_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spoon_drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var spoon := _content.get_tool(&"bar_spoon")
	if spoon != null:
		_spoon_drag_ghost.texture = spoon.icon_texture
	_spoon_drag_ghost.visible = false
	add_child(_spoon_drag_ghost)


func _begin_spoon_drag(local_position: Vector2) -> bool:
	if _spoon_drag_active or _shake_active or _input_router == null or not _input_router.begin_pointer_capture():
		return false
	_spoon_drag_active = true
	_spoon_drag_started_msec = Time.get_ticks_msec()
	_spoon_drag_distance = 0.0
	_spoon_drag_reversals = 0
	_spoon_previous_position = local_position
	_spoon_previous_delta = Vector2.ZERO
	_selected_tool_id = &"bar_spoon"
	if _spoon_drag_ghost != null:
		_spoon_drag_ghost.visible = true
		_spoon_drag_ghost.position = local_position - _spoon_drag_ghost.size * 0.5
	_set_spoon_target_highlight(false)
	return true


func _update_spoon_drag(local_position: Vector2) -> void:
	if not _spoon_drag_active:
		return
	var target_rect := get_spoon_drop_target_rect()
	var delta := local_position - _spoon_previous_position
	if target_rect.has_point(local_position) and target_rect.has_point(_spoon_previous_position):
		_spoon_drag_distance += delta.length()
		if not _spoon_previous_delta.is_zero_approx() and delta.dot(_spoon_previous_delta) < 0.0:
			_spoon_drag_reversals += 1
		_spoon_previous_delta = delta
	_spoon_previous_position = local_position
	if _spoon_drag_ghost != null:
		_spoon_drag_ghost.position = local_position - _spoon_drag_ghost.size * 0.5
	_set_spoon_target_highlight(target_rect.has_point(local_position))


func _finish_spoon_drag(local_position: Vector2, duration_override: float = -1.0) -> InteractionResult:
	if not _spoon_drag_active:
		return InteractionResult.rejected("长柄勺尚未拿起", &"stir_rejected")
	_update_spoon_drag(local_position)
	var target_rect := get_spoon_drop_target_rect()
	var inside_target := target_rect.has_point(local_position)
	var duration := duration_override if duration_override >= 0.0 else float(Time.get_ticks_msec() - _spoon_drag_started_msec) / 1000.0
	var draft := _session.get_draft_snapshot()
	_cancel_spoon_drag()
	if not inside_target:
		return _reject_spoon_drag("请把长柄勺拖入 Shake 杯后再松开")
	if draft.is_sealed(&"shaker"):
		return _reject_spoon_drag("Shake 杯已封盖，请先开盖")
	if draft.total_amount(&"shaker") <= 0.0:
		return _reject_spoon_drag("空杯不能搅拌，请先加入原料")
	var stir_definition := _content.get_interaction(&"stir")
	var minimum_distance := stir_definition.minimum_distance_pixels if stir_definition != null else 80.0
	var minimum_duration := stir_definition.minimum_duration_seconds if stir_definition != null else 0.35
	if _spoon_drag_distance < minimum_distance or duration < minimum_duration:
		return _reject_spoon_drag("请在杯内多拖动几圈完成搅拌")
	return submit_stir_gesture(_spoon_drag_distance, duration, float(_spoon_drag_reversals))


func _reject_spoon_drag(reason: String) -> InteractionResult:
	var result := InteractionResult.rejected(reason, &"stir_rejected")
	_set_feedback(result)
	return result


func _cancel_spoon_drag() -> void:
	if _spoon_drag_active and _input_router != null:
		_input_router.end_pointer_capture()
	_spoon_drag_active = false
	if _spoon_drag_ghost != null:
		_spoon_drag_ghost.visible = false
	_set_spoon_target_highlight(false)


func _set_spoon_target_highlight(pointer_inside: bool) -> void:
	if _vessel_view == null:
		return
	var open_and_ready := not _session.get_draft_snapshot().is_sealed(&"shaker")
	_vessel_view.set_drop_highlighted(pointer_inside and open_and_ready)


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _pulse_content(content_id: StringName) -> void:
	var button := _content_buttons.get(content_id) as Button
	if button == null:
		return
	var tween := button.create_tween()
	tween.tween_property(button, "modulate", Color(1.25, 1.15, 0.75), 0.08)
	tween.tween_property(button, "modulate", Color.WHITE, 0.14)


func _set_feedback(result: InteractionResult) -> void:
	if _status_label != null:
		_status_label.text = "✓ %s" % result.feedback_id if result.success else "× %s" % result.reason
	interaction_feedback.emit(result.success, result.reason, result.feedback_id)


func _update_view() -> void:
	if _target_label == null:
		return
	_target_label.text = "当前目标：%s｜状态：%s" % [
		_display_name(_selected_tool_id) if not _selected_tool_id.is_empty() else "Shake 杯",
		BartendingSessionState.State.keys()[_session.state],
	]
	for content_id: StringName in _content_buttons:
		var button := _content_buttons[content_id]
		button.modulate = Color(1.15, 0.95, 0.62) if content_id == _selected_tool_id else Color.WHITE


func _add_action_button(label_text: String, at: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.position = at
	button.size = Vector2(86.0, 32.0)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _build_error_view(errors: PackedStringArray) -> void:
	var label := Label.new()
	label.text = "CatBar 调酒台配置错误：\n- %s" % "\n- ".join(errors)
	label.position = Vector2(16.0, 16.0)
	label.size = Vector2(720.0, 300.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
