extends Control
class_name BartendingStation

signal drink_ready(result: DrinkResult)
signal interaction_feedback(success: bool, reason: String, feedback_id: StringName)
signal session_cancelled
signal exit_requested(instant: bool)

const DEFAULT_CATALOG: CatBarContentCatalog = preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")
const DiegeticDragItem = preload("res://features/cat_bar/bartending/presentation/diegetic_drag_item.gd")
const ServingGlassViewType = preload("res://features/cat_bar/bartending/presentation/serving_glass_view.gd")
const SHAKER_LID_TEXTURE: Texture2D = preload("res://assets/cat_bar/tools/shaker_lid_generated.png")
const SHAKER_OPEN_TEXTURE: Texture2D = preload("res://assets/cat_bar/tools/shaker_open_generated.png")
const CAT_PAWS_TEXTURE: Texture2D = preload("res://assets/cat_bar/ui/cat_paws_cursor_generated.png")
const ANIMAL_DROPPINGS_TEXTURE: Texture2D = preload("res://assets/cat_bar/ingredients/animal_droppings_generated.png")
const BASE_SPIRIT_IDS: Array[StringName] = [
	&"moon_gin", &"dusk_liqueur", &"sunset_whiskey", &"dawn_vodka", &"daybreak_white_rum",
]
const TOOL_IDS: Array[StringName] = [&"shaker", &"jigger", &"bar_spoon"]
const SUPPORT_IDS: Array[StringName] = [&"clear_ice", &"catnip_spice", &"premium_fish_oil"]
const SHAKER_LID_ID: StringName = &"shaker_lid"
const GLASS_ID: StringName = &"coupe_glass"
const ANIMAL_DROPPINGS_ID: StringName = &"animal_droppings"

enum ShelfMenuLevel { CATEGORIES, CONTENTS }
enum DragMode { NONE, ITEM, SHAKE, POUR_SHAKER, STIR }

@export var content_catalog: CatBarContentCatalog = DEFAULT_CATALOG
@export var auto_start_session: bool = true

var _content := CatBarContentRegistry.new()
var _executors := InteractionExecutorRegistry.new()
var _session := BartendingSessionState.new()
var _input_router: BartendingInputRouter
var _vessel_adapter: MixingVesselAdapter
var _vessel_view: ShakerVesselView
var _serving_glass_view: ServingGlassViewType
var _items: Dictionary[StringName, DiegeticDragItem] = {}
var _scene_sources: Dictionary[StringName, Node2D] = {}
var _scene_source_items: Dictionary[StringName, DiegeticDragItem] = {}
var _context_panel: PanelContainer
var _context_label: Label
var _status_label: Label
var _instruction_label: Label
var _jigger_fill: ColorRect
var _pour_stream: Line2D
var _paw_cursor: TextureRect
var _paw_open_texture: AtlasTexture
var _paw_grab_texture: AtlasTexture
var _pointer_test_override: bool = false
var _animal_sequence_tween: Tween
var _animal_sequence_source_id: StringName = &""
var _active_item: DiegeticDragItem
var _active_drag_id: StringName = &""
var _active_target_id: StringName = &""
var _drag_mode: DragMode = DragMode.NONE
var _drag_offset: Vector2 = Vector2.ZERO
var _interaction_locked: bool = false
var _legacy_jigger_selected: bool = false
var _spoon_drag_started_msec: int = 0
var _spoon_drag_distance: float = 0.0
var _spoon_previous_position: Vector2 = Vector2.ZERO
var _spoon_previous_delta: Vector2 = Vector2.ZERO
var _spoon_drag_reversals: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(960.0, 540.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	var errors := CatBarContentValidator.new().validate(content_catalog, _executors.strategy_ids())
	if not errors.is_empty():
		_build_error_view(errors)
		return
	_content.build(content_catalog)
	_build_presentation()
	visibility_changed.connect(_on_visibility_changed)
	set_process(true)
	if auto_start_session:
		start_session(&"standalone_session", 1, &"moonlit_meow", &"booth_a")


func _process(_delta: float) -> void:
	if _paw_cursor != null and _paw_cursor.visible and not _pointer_test_override:
		_paw_cursor.position = get_viewport().get_mouse_position() - _paw_cursor.size * Vector2(0.5, 0.22)


func _exit_tree() -> void:
	_cancel_animal_sequence()
	_restore_all_scene_sources()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_exit()
		get_viewport().set_input_as_handled()
		return
	if _active_item == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(motion.global_position, motion.relative)
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish_drag(button.global_position)
		get_viewport().set_input_as_handled()


func start_session(session_id: StringName, order_id: int, recipe_id: StringName, booth_id: StringName) -> InteractionResult:
	var result := _session.start(session_id, order_id, recipe_id, booth_id, _content, _executors)
	_set_feedback(result)
	_update_view()
	return result


func reset_session() -> void:
	_cancel_current_session()
	_session = BartendingSessionState.new()
	start_session(&"session_%d" % Time.get_ticks_msec(), 1, &"moonlit_meow", &"booth_a")


func prepare_for_entry() -> bool:
	if _session.state not in [BartendingSessionState.State.IDLE, BartendingSessionState.State.CANCELLED, BartendingSessionState.State.DELIVERED]:
		return false
	_session = BartendingSessionState.new()
	return start_session(&"session_%d" % Time.get_ticks_msec(), 1, &"moonlit_meow", &"booth_a").success


func request_exit(instant: bool = false) -> bool:
	if _session.state in [BartendingSessionState.State.READY_TO_SERVE, BartendingSessionState.State.DELIVERED]:
		return false
	_cancel_current_session()
	exit_requested.emit(instant)
	return true


func request_exit_for_test(instant: bool = true) -> bool:
	return request_exit(instant)


func _cancel_current_session() -> void:
	_cancel_animal_sequence()
	if _drag_mode == DragMode.SHAKE:
		_vessel_adapter.cancel_shake()
	_clear_drag()
	if _input_router != null:
		_input_router.cancel_pointer_capture()
	if _vessel_adapter != null:
		_vessel_adapter.reset()
	_session.cancel()
	_legacy_jigger_selected = false
	_reset_item_positions()
	_restore_all_scene_sources()
	session_cancelled.emit()
	_update_view()


# 兼容自动化与存档迁移的快捷入口；实际玩家流程只使用场景拖拽。
func click_content(content_id: StringName) -> void:
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		var target_id := &"jigger" if ingredient.category == IngredientDefinition.Category.LIQUID and _legacy_jigger_selected else &"shaker"
		_submit_command(InteractionCommand.new(
			content_id, target_id, ingredient.interaction_id, ingredient.default_dose,
			_content.get_interaction(ingredient.interaction_id).gesture
		))
		return
	if content_id == &"jigger":
		if _session.get_draft_snapshot().total_amount(&"jigger") > 0.0:
			_submit_jigger_to_shaker()
			_legacy_jigger_selected = false
		else:
			_legacy_jigger_selected = not _legacy_jigger_selected
	elif content_id == &"shaker":
		toggle_seal()


func simulate_drop_for_test(subject_id: StringName, target_id: StringName) -> InteractionResult:
	return _perform_drop(subject_id, target_id, false)


func get_item_rect(content_id: StringName) -> Rect2:
	var item := _items.get(content_id) as DiegeticDragItem
	return item.get_global_rect() if item != null else Rect2()


func get_highlighted_target_id() -> StringName:
	return _active_target_id


func begin_drag_for_test(content_id: StringName) -> bool:
	var item := _items.get(content_id) as DiegeticDragItem
	if item == null:
		return false
	_on_item_drag_requested(content_id, item.global_position + item.size * 0.5)
	return _active_item != null


func cancel_drag_for_test() -> void:
	_clear_drag()


func move_active_drag_for_test(local_position: Vector2) -> void:
	if _active_item == null:
		return
	_active_item.position = local_position - _active_item.size * 0.5
	_pointer_test_override = true
	get_viewport().warp_mouse(local_position)
	if _paw_cursor != null:
		_paw_cursor.position = local_position - _paw_cursor.size * Vector2(0.5, 0.22)


func get_context_text_for_test(content_id: StringName) -> String:
	return _build_context_text(content_id)


func get_shaker_fill_ratio() -> float:
	return _vessel_view.get_fill_ratio() if _vessel_view != null else 0.0


func get_shaker_liquid_color() -> Color:
	return _vessel_view.get_liquid_color() if _vessel_view != null else Color.TRANSPARENT


func get_serving_glass_fill_ratio() -> float:
	return _serving_glass_view.get_fill_ratio() if _serving_glass_view != null else 0.0


func get_serving_glass_liquid_color() -> Color:
	return _serving_glass_view.liquid_color if _serving_glass_view != null else Color.TRANSPARENT


func is_shaker_lid_aligned() -> bool:
	return _vessel_view.is_lid_aligned() if _vessel_view != null else false


func get_diegetic_item_count() -> int:
	return _items.size()


func has_active_drag() -> bool:
	return _active_item != null or not _animal_sequence_source_id.is_empty()


func finish_active_drag_on_target_for_test() -> bool:
	if _active_item == null or _active_target_id.is_empty():
		return false
	var target := _items.get(_active_target_id) as DiegeticDragItem
	if target == null:
		return false
	_finish_drag(target.get_global_rect().get_center())
	return _interaction_locked


func is_animal_sequence_playing() -> bool:
	return not _animal_sequence_source_id.is_empty()


func configure_scene_grab_sources(sources: Dictionary[StringName, Node2D]) -> void:
	_clear_scene_grab_sources()
	for source_id: StringName in sources:
		var source := sources[source_id]
		if source == null or not is_instance_valid(source) or not source.visible:
			continue
		var texture := source.get("character_texture") as Texture2D
		if texture == null:
			continue
		var item := DiegeticDragItem.new()
		var item_size := Vector2(76.0, 76.0)
		var canvas_origin := source.get_global_transform_with_canvas().origin
		item.configure(source_id, _scene_source_display_name(source_id), texture, item_size, canvas_origin - item_size * Vector2(0.5, 0.82))
		item.set_name_visible(false)
		item.set_visual_visible(false)
		_register_item(item)
		_scene_sources[source_id] = source
		_scene_source_items[source_id] = item


func set_pointer_enabled(enabled: bool) -> void:
	if _paw_cursor != null:
		_paw_cursor.visible = enabled
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if enabled else Input.MOUSE_MODE_VISIBLE)


func get_scene_grab_source_count() -> int:
	return _scene_sources.size()


func is_scene_source_displaced(source_id: StringName) -> bool:
	var source := _scene_sources.get(source_id) as Node2D
	return source != null and not source.visible


func is_fullscreen_panel_present() -> bool:
	return get_node_or_null("WorkbenchBackground") != null or get_node_or_null("ShelfMenu") != null


func submit_stir_gesture(distance_pixels: float, duration_seconds: float, reversals: float = 0.0) -> InteractionResult:
	return _submit_command(InteractionCommand.new(
		&"bar_spoon", &"shaker", &"stir", duration_seconds,
		InteractionDefinition.Gesture.CIRCULAR_DRAG,
		{&"duration": duration_seconds, &"distance": distance_pixels, &"reversals": reversals}
	))


func begin_spoon_drag_for_test(local_position: Vector2) -> bool:
	return _begin_spoon_metrics(local_position)


func update_spoon_drag_for_test(local_position: Vector2) -> void:
	_update_spoon_metrics(local_position)


func end_spoon_drag_for_test(local_position: Vector2, duration_seconds: float) -> InteractionResult:
	_update_spoon_metrics(local_position)
	var inside := get_spoon_drop_target_rect().has_point(local_position)
	var result := _complete_spoon_metrics(inside, duration_seconds)
	_clear_drag()
	return result


func get_spoon_drop_target_rect() -> Rect2:
	var shaker := _items.get(&"shaker") as DiegeticDragItem
	return Rect2(shaker.position, shaker.size) if shaker != null else Rect2()


func toggle_seal() -> void:
	_submit_command(InteractionCommand.new(
		&"shaker", &"shaker", &"toggle_seal", 1.0, InteractionDefinition.Gesture.TOGGLE
	))


func begin_shake() -> bool:
	if _interaction_locked or _drag_mode == DragMode.SHAKE:
		return false
	var result := _session.begin_shake()
	if not result.success or not _vessel_adapter.begin_shake():
		_set_feedback(result)
		return false
	_input_router.begin_pointer_capture()
	_drag_mode = DragMode.SHAKE
	_set_feedback(InteractionResult.accepted(&"shake_started"))
	_update_view()
	return true


func complete_shake_for_test(metrics: Dictionary[StringName, float]) -> InteractionResult:
	if _session.state == BartendingSessionState.State.PREPARING:
		var begin_result := _session.begin_shake()
		if not begin_result.success:
			return begin_result
	return _submit_command(InteractionCommand.new(
		&"shaker", &"shaker", &"shake", float(metrics.get(&"duration", 0.0)),
		InteractionDefinition.Gesture.SHAKE, metrics
	))


func pour_to_glass(emit_immediately: bool = true) -> InteractionResult:
	var begin_result := _session.begin_pour()
	if not begin_result.success:
		_set_feedback(begin_result)
		return begin_result
	var result := _submit_command(InteractionCommand.new(
		&"shaker", GLASS_ID, &"strain_pour", 0.0, InteractionDefinition.Gesture.POUR
	))
	if result.success:
		var drink_result := _session.evaluate_current()
		if drink_result != null and drink_result.valid:
			_present_finished_drink(drink_result, emit_immediately)
	_update_view()
	return result


func get_session() -> BartendingSessionState:
	return _session


func get_content_button_count() -> int:
	return BASE_SPIRIT_IDS.size() + TOOL_IDS.size() + SUPPORT_IDS.size()


func get_zone_count() -> int:
	return content_catalog.station_layout.zones.size()


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


# 旧菜单查询保留为空壳，避免旧测试调用崩溃；新流程没有菜单。
func get_menu_level() -> ShelfMenuLevel:
	return ShelfMenuLevel.CATEGORIES


func get_current_menu_category() -> StringName:
	return &""


func get_visible_menu_content_ids() -> Array[StringName]:
	return []


func open_menu_category_for_test(_category_id: StringName) -> bool:
	return false


func back_to_category_menu() -> void:
	pass


func menu_entry_has_image_and_name(content_id: StringName) -> bool:
	var definition := _get_content_definition(content_id)
	return definition != null and definition.icon_texture != null and not definition.display_name.strip_edges().is_empty()


func restore_session(save_data: Dictionary, deprecated_ids: Dictionary = {}) -> bool:
	var restored := BartendingSessionState.new()
	if not restored.restore_from_save(save_data, _content, _executors, deprecated_ids):
		return false
	_input_router.cancel_pointer_capture()
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
	_input_router = BartendingInputRouter.new()
	_input_router.name = "InputRouter"
	_input_router.command_created.connect(_on_command_created)
	add_child(_input_router)
	_vessel_adapter = MixingVesselAdapter.new()
	_vessel_adapter.name = "MixingVesselAdapter"
	add_child(_vessel_adapter)
	_build_recipe_note()
	_build_context_panel()
	_build_diegetic_items()
	_build_feedback()
	_build_paw_cursor()
	_pour_stream = Line2D.new()
	_pour_stream.name = "PourStream"
	_pour_stream.width = 5.0
	_pour_stream.default_color = Color(0.95, 0.72, 0.36, 0.9)
	_pour_stream.antialiased = true
	_pour_stream.visible = false
	_pour_stream.z_index = 40
	add_child(_pour_stream)


func _build_paw_cursor() -> void:
	var frame_width := CAT_PAWS_TEXTURE.get_width() / 2
	_paw_open_texture = AtlasTexture.new()
	_paw_open_texture.atlas = CAT_PAWS_TEXTURE
	_paw_open_texture.region = Rect2(0.0, 0.0, frame_width, CAT_PAWS_TEXTURE.get_height())
	_paw_grab_texture = AtlasTexture.new()
	_paw_grab_texture.atlas = CAT_PAWS_TEXTURE
	_paw_grab_texture.region = Rect2(frame_width, 0.0, frame_width, CAT_PAWS_TEXTURE.get_height())
	_paw_cursor = TextureRect.new()
	_paw_cursor.name = "CatPawCursor"
	_paw_cursor.size = Vector2(126.0, 82.0)
	_paw_cursor.pivot_offset = _paw_cursor.size * 0.5
	_paw_cursor.rotation = PI
	_paw_cursor.texture = _paw_open_texture
	_paw_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paw_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_paw_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paw_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paw_cursor.z_index = 100
	add_child(_paw_cursor)
	set_pointer_enabled(visible)


func _build_recipe_note() -> void:
	var note := PanelContainer.new()
	note.name = "RecipeNote"
	note.position = Vector2(302.0, 4.0)
	note.size = Vector2(356.0, 48.0)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.065, 0.07, 0.84)
	style.border_color = Color(0.95, 0.64, 0.28, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	note.add_theme_stylebox_override("panel", style)
	add_child(note)
	var label := Label.new()
	label.text = "月夜猫语｜月光金酒 30 · 暮色甜酒 30 · 冰×2 · 猫薄荷×1\n量取 → 封盖 → Shake → 倒杯"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("ffe0a3"))
	note.add_child(label)


func _build_context_panel() -> void:
	_context_panel = PanelContainer.new()
	_context_panel.name = "ContextCard"
	_context_panel.position = Vector2(22.0, 24.0)
	_context_panel.size = Vector2(275.0, 108.0)
	_context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.045, 0.92)
	style.border_color = Color(0.82, 0.57, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_context_panel.add_theme_stylebox_override("panel", style)
	add_child(_context_panel)
	_context_label = Label.new()
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.add_theme_font_size_override("font_size", 14)
	_context_label.add_theme_color_override("font_color", Color("fff0cf"))
	_context_panel.add_child(_context_label)
	_context_panel.visible = false


func _build_diegetic_items() -> void:
	_add_station_surface(Rect2(215.0, 43.0, 139.0, 84.0), 0.56)
	_add_station_surface(Rect2(548.0, 43.0, 98.0, 84.0), 0.56)
	_add_station_surface(Rect2(168.0, 176.0, 151.0, 64.0), 0.44)
	_add_station_surface(Rect2(592.0, 151.0, 305.0, 94.0), 0.44)
	var bottle_positions: Array[Vector2] = [
		Vector2(224.0, 52.0), Vector2(267.0, 52.0), Vector2(310.0, 52.0),
		Vector2(556.0, 52.0), Vector2(599.0, 52.0),
	]
	for index: int in range(BASE_SPIRIT_IDS.size()):
		_add_content_item(BASE_SPIRIT_IDS[index], Vector2(36.0, 70.0), bottle_positions[index])
	_add_content_item(&"clear_ice", Vector2(44.0, 48.0), Vector2(178.0, 184.0))
	_add_content_item(&"catnip_spice", Vector2(44.0, 48.0), Vector2(225.0, 184.0))
	_add_content_item(&"premium_fish_oil", Vector2(40.0, 54.0), Vector2(274.0, 178.0))
	var jigger := _add_content_item(&"jigger", Vector2(44.0, 58.0), Vector2(604.0, 181.0))
	_jigger_fill = ColorRect.new()
	_jigger_fill.name = "Fill"
	_jigger_fill.position = Vector2(10.0, 54.0)
	_jigger_fill.size = Vector2(24.0, 0.0)
	_jigger_fill.color = Color(0.92, 0.46, 0.24, 0.58)
	_jigger_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jigger.add_child(_jigger_fill)
	var shaker := DiegeticDragItem.new()
	shaker.configure(&"shaker", _display_name(&"shaker"), null, Vector2(62.0, 88.0), Vector2(706.0, 156.0))
	shaker.set_name_visible(false)
	_register_item(shaker)
	_vessel_view = ShakerVesselView.new()
	_vessel_view.name = "ShakerVesselView"
	_vessel_view.position = shaker.size * 0.5 + Vector2(0.0, 2.0)
	_vessel_view.vessel_size = Vector2(48.0, 72.0)
	_vessel_view.body_texture = SHAKER_OPEN_TEXTURE
	_vessel_view.lid_texture = SHAKER_LID_TEXTURE
	shaker.add_child(_vessel_view)
	_vessel_view.bind(_vessel_adapter)
	_add_content_item(&"bar_spoon", Vector2(82.0, 38.0), Vector2(734.0, 205.0))
	var glass_definition := _content.get_glass(GLASS_ID)
	var glass_item := DiegeticDragItem.new()
	glass_item.configure(GLASS_ID, glass_definition.display_name, null, Vector2(58.0, 78.0), Vector2(832.0, 164.0), false)
	glass_item.set_name_visible(false)
	_register_item(glass_item)
	_serving_glass_view = ServingGlassViewType.new()
	_serving_glass_view.name = "ServingGlassView"
	_serving_glass_view.glass_texture = glass_definition.icon_texture
	_serving_glass_view.capacity_ml = glass_definition.capacity_ml
	_serving_glass_view.glass_size = Vector2(50.0, 70.0)
	_serving_glass_view.position = glass_item.size * 0.5
	glass_item.add_child(_serving_glass_view)
	var lid := DiegeticDragItem.new()
	lid.configure(SHAKER_LID_ID, "Shake 杯盖", SHAKER_LID_TEXTURE, Vector2(48.0, 32.0), Vector2(778.0, 178.0))
	lid.set_name_visible(false)
	_register_item(lid)


func _add_station_surface(rect: Rect2, alpha: float) -> void:
	var surface := Panel.new()
	surface.position = rect.position
	surface.size = rect.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.z_index = -5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.075, 0.025, alpha)
	style.border_color = Color(0.64, 0.36, 0.15, minf(alpha + 0.12, 0.82))
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.015, 0.008, 0.006, 0.34)
	style.shadow_size = 2
	surface.add_theme_stylebox_override("panel", style)
	add_child(surface)


func _build_feedback() -> void:
	_instruction_label = Label.new()
	_instruction_label.name = "Instruction"
	_instruction_label.position = Vector2(270.0, 485.0)
	_instruction_label.size = Vector2(500.0, 24.0)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 15)
	_instruction_label.add_theme_color_override("font_color", Color("ffe2a4"))
	_instruction_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.025, 0.96))
	_instruction_label.add_theme_constant_override("outline_size", 5)
	_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_instruction_label)
	_status_label = Label.new()
	_status_label.name = "Feedback"
	_status_label.position = Vector2(210.0, 510.0)
	_status_label.size = Vector2(620.0, 25.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.025, 0.98))
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	var exit_hint := Label.new()
	exit_hint.position = Vector2(22.0, 505.0)
	exit_hint.text = "Esc  清空本杯"
	exit_hint.add_theme_color_override("font_color", Color("d9b77c"))
	exit_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.025, 0.98))
	exit_hint.add_theme_constant_override("outline_size", 4)
	exit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exit_hint)


func _add_content_item(content_id: StringName, item_size: Vector2, item_position: Vector2) -> DiegeticDragItem:
	var definition := _get_content_definition(content_id)
	var item := DiegeticDragItem.new()
	item.configure(content_id, definition.display_name, definition.icon_texture, item_size, item_position)
	item.set_name_visible(false)
	_register_item(item)
	return item


func _register_item(item: DiegeticDragItem) -> void:
	add_child(item)
	_items[item.content_id] = item
	item.hover_started.connect(_on_item_hover_started)
	item.hover_ended.connect(_on_item_hover_ended)
	item.drag_requested.connect(_on_item_drag_requested)


func _on_item_hover_started(content_id: StringName, _at: Vector2) -> void:
	if _active_item != null:
		return
	_context_label.text = _build_context_text(content_id)
	_context_panel.visible = true


func _on_item_hover_ended(_content_id: StringName) -> void:
	if _active_item == null:
		_context_panel.visible = false


func _build_context_text(content_id: StringName) -> String:
	if _scene_sources.has(content_id):
		return "%s\n场景动物 · 松手投入 Shake 杯\n会留下一份神秘馈赠，然后回到原位" % _scene_source_display_name(content_id)
	if content_id == SHAKER_LID_ID:
		return "Shake 杯盖\n拖到 Shake 杯上完成封盖"
	if content_id == &"shaker":
		return _build_shaker_context()
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		var category := "基酒" if ingredient.category == IngredientDefinition.Category.LIQUID else ("冰块" if ingredient.category == IngredientDefinition.Category.ICE else "辅料")
		var tags := PackedStringArray()
		for tag: StringName in ingredient.flavor_tags:
			tags.append(String(tag))
		return "%s\n%s · 每次 %.0f %s\n风味：%s" % [
			ingredient.display_name, category, ingredient.default_dose,
			"ml" if ingredient.category == IngredientDefinition.Category.LIQUID else "份",
			"、".join(tags) if not tags.is_empty() else "纯净",
		]
	var tool := _content.get_tool(content_id)
	if tool != null:
		return "%s\n调酒工具 · 容量 %.0f ml\n拖拽到发光目标完成操作" % [tool.display_name, tool.capacity_ml]
	var glass := _content.get_glass(content_id)
	return "%s\n成品酒杯 · 容量 %.0f ml" % [glass.display_name, glass.capacity_ml] if glass != null else String(content_id)


func _build_shaker_context() -> String:
	var draft := _session.get_draft_snapshot()
	var contents := draft.get_contents(&"shaker")
	var lines := PackedStringArray(["Shake 杯"])
	if contents.is_empty():
		lines.append("当前为空")
	else:
		for ingredient_id: StringName in contents:
			var ingredient := _content.get_ingredient(ingredient_id)
			if ingredient != null:
				var unit := "ml" if ingredient.category == IngredientDefinition.Category.LIQUID else "份"
				lines.append("%s  %.0f %s" % [ingredient.display_name, contents[ingredient_id], unit])
		lines.append("总量  %.0f ml" % draft.total_amount(&"shaker"))
	lines.append("已封盖" if draft.is_sealed(&"shaker") else "未封盖")
	return "\n".join(lines)


func _on_item_drag_requested(content_id: StringName, global_pointer: Vector2) -> void:
	if _interaction_locked or _active_item != null:
		return
	var item := _items.get(content_id) as DiegeticDragItem
	if item == null:
		return
	if content_id == &"jigger" and _session.get_draft_snapshot().total_amount(&"jigger") <= 0.0:
		_set_feedback(InteractionResult.rejected("量酒器是空的，请先量取基酒", &"measure_rejected"))
		return
	if content_id == &"shaker" and not _has_completed_shake():
		if not begin_shake():
			return
		_drag_mode = DragMode.SHAKE
	else:
		_drag_mode = DragMode.STIR if content_id == &"bar_spoon" else (DragMode.POUR_SHAKER if content_id == &"shaker" else DragMode.ITEM)
		_input_router.begin_pointer_capture()
	_active_item = item
	_active_drag_id = content_id
	_active_target_id = _target_for(content_id)
	_drag_offset = _viewport_to_local(global_pointer) - item.position
	item.z_index = 30
	if _paw_cursor != null:
		_paw_cursor.texture = _paw_grab_texture
	if _scene_sources.has(content_id):
		var source := _scene_sources[content_id]
		source.visible = false
		item.set_visual_visible(true)
	_context_panel.visible = false
	_set_target_highlight(false)
	if _drag_mode == DragMode.STIR:
		_begin_spoon_metrics(_viewport_to_local(global_pointer))
	_instruction_label.text = _instruction_for_drag(content_id)


func _update_drag(global_pointer: Vector2, relative: Vector2) -> void:
	var local_pointer := _viewport_to_local(global_pointer)
	if _drag_mode == DragMode.SHAKE:
		_vessel_adapter.apply_shake_delta(relative, maxf(get_process_delta_time(), 1.0 / 60.0))
	elif _drag_mode == DragMode.STIR:
		_active_item.position = local_pointer - _drag_offset
		_update_spoon_metrics(local_pointer)
	else:
		_active_item.position = local_pointer - _drag_offset
	var target := _items.get(_active_target_id) as DiegeticDragItem
	_set_target_highlight(target != null and target.contains_global_point(global_pointer))


func _finish_drag(global_pointer: Vector2) -> void:
	var subject_id := _active_drag_id
	var mode := _drag_mode
	var item := _active_item
	var target := _items.get(_active_target_id) as DiegeticDragItem
	var inside_target := target != null and target.contains_global_point(global_pointer)
	if mode == DragMode.SHAKE:
		_finish_shake()
		_clear_drag()
		return
	if mode == DragMode.STIR:
		var duration := float(Time.get_ticks_msec() - _spoon_drag_started_msec) / 1000.0
		var result := _complete_spoon_metrics(inside_target, duration)
		if not result.success:
			_bounce_home(item)
			_clear_drag()
			return
		_clear_drag()
		return
	if _scene_sources.has(subject_id):
		if inside_target:
			var result := _perform_drop(subject_id, _active_target_id, true)
			if result.success:
				_clear_drag(false, false)
				_play_animal_ingredient_sequence(subject_id, item, target)
				return
		else:
			_set_feedback(InteractionResult.rejected("请把动物抱到发光的 Shake 杯上方再松手", &"invalid_drop"))
		_restore_scene_source(subject_id)
		_clear_drag()
		return
	if not inside_target:
		_set_feedback(InteractionResult.rejected("请把物件拖到发光目标后再松开", &"invalid_drop"))
		_bounce_home(item)
		_clear_drag()
		return
	var target_id := _active_target_id
	_clear_drag(false)
	_animate_drop(subject_id, target_id, item, target)


func _target_for(content_id: StringName) -> StringName:
	if _scene_sources.has(content_id):
		return &"shaker"
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		return &"jigger" if ingredient.category == IngredientDefinition.Category.LIQUID else &"shaker"
	match content_id:
		&"jigger", &"bar_spoon", SHAKER_LID_ID:
			return &"shaker"
		&"shaker":
			return GLASS_ID
	return &""


func _instruction_for_drag(content_id: StringName) -> String:
	if _scene_sources.has(content_id):
		return "把%s抱到 Shake 杯上方，松手收集神秘馈赠" % _scene_source_display_name(content_id)
	match content_id:
		&"jigger": return "把量酒器拖到 Shake 杯，倒入量好的基酒"
		&"bar_spoon": return "把长柄勺拖入开放的 Shake 杯内来回搅拌"
		SHAKER_LID_ID: return "把杯盖拖到 Shake 杯完成封盖"
		&"shaker": return "上下左右摇动，或在完成 Shake 后拖到成品杯"
	var ingredient := _content.get_ingredient(content_id)
	return "把%s拖到%s" % [ingredient.display_name, "量酒器" if ingredient != null and ingredient.category == IngredientDefinition.Category.LIQUID else "Shake 杯"]


func _set_target_highlight(strong: bool) -> void:
	for item_id: StringName in _items:
		var item := _items[item_id] as DiegeticDragItem
		item.set_highlighted(item_id == _active_target_id, strong and item_id == _active_target_id)


func _clear_drag(reset_item: bool = true, restore_scene_source: bool = true) -> void:
	var clearing_id := _active_drag_id
	if _active_item != null:
		_active_item.z_index = 0
		if reset_item:
			_active_item.reset_to_home()
	if restore_scene_source and _scene_sources.has(clearing_id):
		_restore_scene_source(clearing_id)
	if _input_router != null:
		_input_router.end_pointer_capture()
	_active_item = null
	_active_drag_id = &""
	_active_target_id = &""
	_drag_mode = DragMode.NONE
	_pointer_test_override = false
	if _paw_cursor != null:
		_paw_cursor.texture = _paw_open_texture
	_set_target_highlight(false)
	if _instruction_label != null:
		_instruction_label.text = "拖拽吧台物件开始调酒"


func _animate_drop(subject_id: StringName, target_id: StringName, source: DiegeticDragItem, target: DiegeticDragItem) -> void:
	_interaction_locked = true
	source.z_index = 35
	var target_center := target.position + target.size * 0.5
	var source_goal := target_center - Vector2(source.size.x * 0.5 + 18.0, source.size.y + 12.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(source, "position", source_goal, 0.18)
	tween.parallel().tween_property(source, "rotation", -0.62, 0.18)
	tween.tween_callback(_show_pour_stream.bind(source, target))
	tween.tween_interval(0.28)
	tween.tween_callback(_finish_animated_drop.bind(subject_id, target_id, source))


func _show_pour_stream(source: DiegeticDragItem, target: DiegeticDragItem) -> void:
	_pour_stream.points = PackedVector2Array([
		source.position + source.size * Vector2(0.85, 0.72),
		target.position + target.size * Vector2(0.5, 0.28),
	])
	_pour_stream.visible = true
	_pour_stream.modulate = Color.WHITE
	var tween := _pour_stream.create_tween()
	tween.tween_property(_pour_stream, "modulate:a", 0.15, 0.28)


func _finish_animated_drop(subject_id: StringName, target_id: StringName, source: DiegeticDragItem) -> void:
	_pour_stream.visible = false
	var result := _perform_drop(subject_id, target_id, true)
	source.reset_to_home()
	source.z_index = 0
	_interaction_locked = result.success and subject_id == &"shaker" and target_id == GLASS_ID
	if result.success and subject_id == SHAKER_LID_ID:
		_play_shaker_ready_feedback()


func _perform_drop(subject_id: StringName, target_id: StringName, show_feedback: bool = true) -> InteractionResult:
	var result: InteractionResult
	if _scene_sources.has(subject_id) and target_id == &"shaker":
		result = _submit_ingredient(ANIMAL_DROPPINGS_ID, target_id)
	elif _content.get_ingredient(subject_id) != null:
		result = _submit_ingredient(subject_id, target_id)
	elif subject_id == &"jigger" and target_id == &"shaker":
		result = _submit_jigger_to_shaker()
	elif subject_id == SHAKER_LID_ID and target_id == &"shaker":
		result = _submit_lid_to_shaker()
	elif subject_id == &"shaker" and target_id == GLASS_ID:
		# 玩家拖拽时先展示成品杯液体；测试快捷入口保持同步完成。
		result = pour_to_glass(not show_feedback)
	else:
		result = InteractionResult.rejected("这个物件不能放到这里", &"invalid_drop")
		if show_feedback:
			_set_feedback(result)
	return result


func _submit_ingredient(content_id: StringName, target_id: StringName) -> InteractionResult:
	var ingredient := _content.get_ingredient(content_id)
	if ingredient == null:
		return InteractionResult.rejected("原料不存在")
	var expected_target := &"jigger" if ingredient.category == IngredientDefinition.Category.LIQUID else &"shaker"
	if target_id != expected_target:
		var rejected := InteractionResult.rejected("%s需要放入%s" % [ingredient.display_name, _display_name(expected_target)], &"invalid_drop")
		_set_feedback(rejected)
		return rejected
	return _submit_command(InteractionCommand.new(
		content_id, target_id, ingredient.interaction_id, ingredient.default_dose,
		_content.get_interaction(ingredient.interaction_id).gesture
	))


func _submit_jigger_to_shaker() -> InteractionResult:
	return _submit_command(InteractionCommand.new(
		&"jigger", &"shaker", &"measure", 0.0, InteractionDefinition.Gesture.DRAG
	))


func _submit_lid_to_shaker() -> InteractionResult:
	var draft := _session.get_draft_snapshot()
	if draft.total_amount(&"shaker") <= 0.0:
		var rejected := InteractionResult.rejected("Shake 杯还是空的，请先加入原料", &"seal_rejected")
		_set_feedback(rejected)
		return rejected
	if draft.is_sealed(&"shaker"):
		var rejected := InteractionResult.rejected("Shake 杯已经封盖", &"seal_rejected")
		_set_feedback(rejected)
		return rejected
	return _submit_command(InteractionCommand.new(
		&"shaker", &"shaker", &"toggle_seal", 1.0, InteractionDefinition.Gesture.TOGGLE
	))


func _on_command_created(command: InteractionCommand) -> void:
	_submit_command(command)


func _submit_command(command: InteractionCommand) -> InteractionResult:
	var before := _session.get_draft_snapshot()
	var result := _session.submit_command(command)
	if result.success:
		_apply_visual_command(command, result, before)
	_set_feedback(result)
	_update_view()
	return result


func _apply_visual_command(command: InteractionCommand, result: InteractionResult, before: BartendingSessionDraft) -> void:
	var ingredient := _content.get_ingredient(command.subject_id)
	if ingredient != null and command.target_id == &"shaker":
		if ingredient.category == IngredientDefinition.Category.LIQUID:
			_vessel_adapter.add_fluid(ingredient.fluid_id)
		elif ingredient.category == IngredientDefinition.Category.ICE:
			_vessel_adapter.add_ice(roundi(result.applied_amount))
	elif command.interaction_id == &"measure":
		for ingredient_id: StringName in before.get_contents(command.subject_id):
			var measured := _content.get_ingredient(ingredient_id)
			if measured != null and measured.category == IngredientDefinition.Category.LIQUID:
				_vessel_adapter.add_fluid(measured.fluid_id)
	elif command.interaction_id == &"toggle_seal":
		_vessel_adapter.set_sealed(_session.get_draft_snapshot().is_sealed(&"shaker"))
	elif command.interaction_id == &"strain_pour":
		# 领域容器已经转空，物理表现必须在同一确认点清空，避免空杯仍残留粒子。
		_vessel_adapter.reset()


func _finish_shake() -> void:
	var metrics := _vessel_adapter.end_shake()
	_input_router.end_pointer_capture()
	_input_router.route_gesture(
		&"shaker", &"shaker", &"shake", InteractionDefinition.Gesture.SHAKE,
		float(metrics.get(&"duration", 0.0)), metrics
	)
	_update_view()


func _begin_spoon_metrics(local_position: Vector2) -> bool:
	_spoon_drag_started_msec = Time.get_ticks_msec()
	_spoon_drag_distance = 0.0
	_spoon_drag_reversals = 0
	_spoon_previous_position = local_position
	_spoon_previous_delta = Vector2.ZERO
	return true


func _update_spoon_metrics(local_position: Vector2) -> void:
	var delta := local_position - _spoon_previous_position
	if get_spoon_drop_target_rect().has_point(local_position):
		_spoon_drag_distance += delta.length()
		if not _spoon_previous_delta.is_zero_approx() and delta.dot(_spoon_previous_delta) < 0.0:
			_spoon_drag_reversals += 1
		_spoon_previous_delta = delta
	_spoon_previous_position = local_position


func _complete_spoon_metrics(inside_target: bool, duration: float) -> InteractionResult:
	if not inside_target:
		return _reject_spoon_drag("请把长柄勺拖入 Shake 杯后再松开")
	var draft := _session.get_draft_snapshot()
	if draft.is_sealed(&"shaker"):
		return _reject_spoon_drag("Shake 杯已封盖，请先开盖")
	if draft.total_amount(&"shaker") <= 0.0:
		return _reject_spoon_drag("空杯不能搅拌，请先加入原料")
	var definition := _content.get_interaction(&"stir")
	if _spoon_drag_distance < definition.minimum_distance_pixels or duration < definition.minimum_duration_seconds:
		return _reject_spoon_drag("请在杯内多拖动几圈完成搅拌")
	return submit_stir_gesture(_spoon_drag_distance, duration, float(_spoon_drag_reversals))


func _reject_spoon_drag(reason: String) -> InteractionResult:
	var result := InteractionResult.rejected(reason, &"stir_rejected")
	_set_feedback(result)
	return result


func _play_shaker_ready_feedback() -> void:
	var shaker := _items.get(&"shaker") as DiegeticDragItem
	shaker.set_ready_hint(true)
	var tween := shaker.create_tween()
	tween.tween_property(shaker, "rotation", 0.035, 0.06)
	tween.tween_property(shaker, "rotation", -0.035, 0.06)
	tween.tween_property(shaker, "rotation", 0.02, 0.05)
	tween.tween_property(shaker, "rotation", 0.0, 0.05)


func _bounce_home(item: DiegeticDragItem) -> void:
	if item == null:
		return
	var tween := item.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "position", item.home_position, 0.2)
	tween.parallel().tween_property(item, "rotation", 0.0, 0.2)


func _has_completed_shake() -> bool:
	return float(_session.get_draft_snapshot().action_totals.get(&"shake_duration", 0.0)) > 0.0


func _update_view() -> void:
	if _status_label == null:
		return
	var draft := _session.get_draft_snapshot()
	if _jigger_fill != null:
		var ratio := clampf(draft.total_amount(&"jigger") / 60.0, 0.0, 1.0)
		_jigger_fill.position.y = 54.0 - 20.0 * ratio
		_jigger_fill.size.y = 20.0 * ratio
	var shaker := _items.get(&"shaker") as DiegeticDragItem
	if shaker != null:
		shaker.set_ready_hint(draft.is_sealed(&"shaker") and not _has_completed_shake())
	if _vessel_view != null:
		_vessel_view.set_fill_ratio(draft.total_amount(&"shaker") / 300.0)
		_vessel_view.set_liquid_color(_mixed_liquid_color(draft.get_contents(&"shaker")))
	var lid := _items.get(SHAKER_LID_ID) as DiegeticDragItem
	if lid != null:
		lid.visible = not draft.is_sealed(&"shaker")
	if draft.total_amount(GLASS_ID) <= 0.0 and _serving_glass_view != null:
		_serving_glass_view.clear_contents()


func _mixed_liquid_color(contents: Dictionary[StringName, float]) -> Color:
	var total_liquid := 0.0
	var weighted := Color(0.0, 0.0, 0.0, 0.0)
	for ingredient_id: StringName in contents:
		var ingredient := _content.get_ingredient(ingredient_id)
		if ingredient == null or ingredient.category != IngredientDefinition.Category.LIQUID:
			continue
		var amount: float = contents[ingredient_id]
		total_liquid += amount
		weighted += ingredient.color * amount
	if total_liquid <= 0.0:
		return Color(0.72, 0.26, 0.34, 0.78)
	weighted /= total_liquid
	weighted.a = 0.82
	return weighted


func _present_finished_drink(result: DrinkResult, emit_immediately: bool) -> void:
	var amount := float(result.appearance.get(&"liquid_amount_ml", 0.0))
	var color: Color = result.appearance.get(&"color", Color(0.72, 0.26, 0.34, 0.82))
	color.a = 0.84
	if emit_immediately:
		_serving_glass_view.set_contents(amount, color)
		drink_ready.emit(result)
		return
	_serving_glass_view.set_contents(0.0, color)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_serving_glass_fill.bind(color), 0.0, amount, 0.42)
	tween.tween_interval(0.38)
	tween.tween_callback(_finish_drink_presentation.bind(result))


func _set_serving_glass_fill(amount: float, color: Color) -> void:
	_serving_glass_view.set_contents(amount, color)


func _finish_drink_presentation(result: DrinkResult) -> void:
	_interaction_locked = false
	drink_ready.emit(result)


func _set_feedback(result: InteractionResult) -> void:
	if _status_label != null:
		_status_label.text = "✓ %s" % result.feedback_id if result.success else "× %s" % result.reason
		_status_label.add_theme_color_override("font_color", Color("aef3bd") if result.success else Color("ffaaa2"))
	interaction_feedback.emit(result.success, result.reason, result.feedback_id)


func _display_name(content_id: StringName) -> String:
	var definition := _get_content_definition(content_id)
	return definition.display_name if definition != null else ("Shake 杯盖" if content_id == SHAKER_LID_ID else String(content_id))


func _get_content_definition(content_id: StringName) -> CatBarContentDefinition:
	var tool := _content.get_tool(content_id)
	if tool != null:
		return tool
	var ingredient := _content.get_ingredient(content_id)
	if ingredient != null:
		return ingredient
	return _content.get_glass(content_id)


func _reset_item_positions() -> void:
	for item: DiegeticDragItem in _items.values():
		item.reset_to_home()
		item.set_highlighted(false)
		item.set_ready_hint(false)
	if _serving_glass_view != null:
		_serving_glass_view.clear_contents()
	_restore_all_scene_sources()


func _play_animal_ingredient_sequence(
	source_id: StringName,
	animal_item: DiegeticDragItem,
	target: DiegeticDragItem
) -> void:
	if animal_item == null or target == null:
		_restore_scene_source(source_id)
		return
	_interaction_locked = true
	_animal_sequence_source_id = source_id
	animal_item.z_index = 46
	animal_item.set_visual_visible(true)
	var perch_position := target.position + Vector2(
		target.size.x * 0.5 - animal_item.size.x * 0.5,
		-animal_item.size.y * 0.72
	)
	var squat_position := perch_position + Vector2(0.0, 7.0)
	_instruction_label.text = "%s正在贡献神秘原料……" % _scene_source_display_name(source_id)
	_animal_sequence_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_animal_sequence_tween.tween_property(animal_item, "position", perch_position, 0.18)
	_animal_sequence_tween.parallel().tween_property(animal_item, "rotation", 0.0, 0.18)
	_animal_sequence_tween.tween_property(animal_item, "position", squat_position, 0.1)
	_animal_sequence_tween.parallel().tween_property(animal_item, "scale", Vector2(1.08, 0.86), 0.1)
	_animal_sequence_tween.tween_callback(_spawn_droppings_fall.bind(animal_item, target))
	_animal_sequence_tween.tween_interval(0.42)
	_animal_sequence_tween.tween_callback(_begin_litter_bury_feedback.bind(target))
	for swipe_index: int in range(3):
		_animal_sequence_tween.tween_property(animal_item, "position:x", perch_position.x - 9.0, 0.1)
		_animal_sequence_tween.parallel().tween_property(animal_item, "rotation", -0.11, 0.1)
		_animal_sequence_tween.tween_callback(_spawn_litter_dust.bind(target, -1.0))
		_animal_sequence_tween.tween_property(animal_item, "position:x", perch_position.x + 9.0, 0.1)
		_animal_sequence_tween.parallel().tween_property(animal_item, "rotation", 0.11, 0.1)
		_animal_sequence_tween.tween_callback(_spawn_litter_dust.bind(target, 1.0))
	_animal_sequence_tween.tween_property(animal_item, "position", animal_item.home_position, 0.3)
	_animal_sequence_tween.parallel().tween_property(animal_item, "rotation", 0.0, 0.3)
	_animal_sequence_tween.parallel().tween_property(animal_item, "scale", Vector2.ONE, 0.3)
	_animal_sequence_tween.tween_callback(_finish_animal_ingredient_sequence.bind(source_id))


func _spawn_droppings_fall(animal_item: DiegeticDragItem, target: DiegeticDragItem) -> void:
	var icon := Sprite2D.new()
	var cropped_droppings := AtlasTexture.new()
	cropped_droppings.atlas = ANIMAL_DROPPINGS_TEXTURE
	cropped_droppings.region = Rect2(300.0, 320.0, 440.0, 440.0)
	icon.texture = cropped_droppings
	icon.position = animal_item.position + Vector2(animal_item.size.x * 0.5, animal_item.size.y * 0.9)
	icon.scale = Vector2(0.1, 0.1)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(1.25, 1.15, 0.95, 1.0)
	icon.z_index = 60
	add_child(icon)
	var target_position := target.position + Vector2(target.size.x * 0.5, target.size.y * 0.42)
	var tween := icon.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "position", target_position, 0.38)
	tween.parallel().tween_property(icon, "scale", Vector2(0.065, 0.065), 0.38)
	tween.parallel().tween_property(icon, "rotation", 0.22, 0.38)
	tween.tween_callback(_spawn_cup_impact.bind(target))
	tween.tween_property(icon, "modulate:a", 0.0, 0.12)
	tween.tween_callback(icon.queue_free)


func _spawn_cup_impact(target: DiegeticDragItem) -> void:
	for index: int in range(8):
		var mote := ColorRect.new()
		mote.color = Color("ffe1a1") if index % 2 == 0 else Color("d99b56")
		mote.size = Vector2(5.0, 5.0)
		mote.position = target.position + Vector2(target.size.x * 0.5, target.size.y * 0.3)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.z_index = 61
		add_child(mote)
		var angle := -2.7 + float(index) * 0.32
		var destination := mote.position + Vector2(cos(angle), sin(angle)) * (12.0 + float(index % 2) * 5.0)
		var tween := mote.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "position", destination, 0.2)
		tween.parallel().tween_property(mote, "modulate:a", 0.0, 0.2)
		tween.tween_callback(mote.queue_free)


func _begin_litter_bury_feedback(_target: DiegeticDragItem) -> void:
	_instruction_label.text = "猫猫正在认真埋好不存在的猫砂……"


func _spawn_litter_dust(target: DiegeticDragItem, direction: float) -> void:
	for streak_index: int in range(2):
		var streak := ColorRect.new()
		streak.color = Color("ffe0a0")
		streak.size = Vector2(18.0 - float(streak_index) * 4.0, 3.0)
		streak.position = target.position + Vector2(
			target.size.x * 0.5 - streak.size.x * 0.5,
			target.size.y * 0.04 + float(streak_index) * 8.0
		)
		streak.rotation = direction * (0.2 + float(streak_index) * 0.12)
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.z_index = 62
		add_child(streak)
		var streak_tween := streak.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		streak_tween.tween_property(streak, "position:x", streak.position.x + direction * 18.0, 0.24)
		streak_tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.24)
		streak_tween.tween_callback(streak.queue_free)
	for index: int in range(7):
		var grain := ColorRect.new()
		grain.color = Color("f0d092") if index % 2 == 0 else Color("aa7747")
		grain.size = Vector2(7.0 + float(index % 3), 7.0 + float(index % 3))
		grain.position = target.position + Vector2(target.size.x * 0.5, target.size.y * 0.16)
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grain.z_index = 61
		add_child(grain)
		var destination := grain.position + Vector2(direction * (14.0 + float(index) * 5.0), -10.0 - float(index % 3) * 8.0)
		var tween := grain.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(grain, "position", destination, 0.28)
		tween.parallel().tween_property(grain, "modulate:a", 0.0, 0.28)
		tween.tween_callback(grain.queue_free)


func _finish_animal_ingredient_sequence(source_id: StringName) -> void:
	_restore_scene_source(source_id)
	_animal_sequence_tween = null
	_animal_sequence_source_id = &""
	_interaction_locked = false
	_instruction_label.text = "猫猫埋好猫砂，已经回到原位"


func _cancel_animal_sequence() -> void:
	if _animal_sequence_tween != null and _animal_sequence_tween.is_valid():
		_animal_sequence_tween.kill()
	if not _animal_sequence_source_id.is_empty():
		_restore_scene_source(_animal_sequence_source_id)
	_animal_sequence_tween = null
	_animal_sequence_source_id = &""
	_interaction_locked = false


func _restore_scene_source(source_id: StringName) -> void:
	var source := _scene_sources.get(source_id) as Node2D
	if source != null and is_instance_valid(source):
		source.visible = true
	var item := _scene_source_items.get(source_id) as DiegeticDragItem
	if item != null:
		item.reset_to_home()
		item.set_visual_visible(false)


func _restore_all_scene_sources() -> void:
	for source_id: StringName in _scene_sources:
		_restore_scene_source(source_id)


func _clear_scene_grab_sources() -> void:
	_restore_all_scene_sources()
	for source_id: StringName in _scene_source_items.keys():
		var item := _scene_source_items[source_id]
		_items.erase(source_id)
		item.queue_free()
	_scene_source_items.clear()
	_scene_sources.clear()


func _scene_source_display_name(source_id: StringName) -> String:
	match source_id:
		&"bartender_cat": return "调酒师猫猫"
		&"worker_cat": return "打工猫猫"
	return "酒吧动物"


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	set_pointer_enabled(visible and mouse_filter != Control.MOUSE_FILTER_IGNORE)


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _build_error_view(errors: PackedStringArray) -> void:
	var label := Label.new()
	label.text = "CatBar 调酒台配置错误：\n- %s" % "\n- ".join(errors)
	label.position = Vector2(16.0, 16.0)
	label.size = Vector2(720.0, 300.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
