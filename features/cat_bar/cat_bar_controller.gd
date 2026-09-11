extends Node2D
class_name CatBarController

signal mode_changed(mode: CatBarModeController.Mode)
signal phone_open_rejected(reason: String)
signal drink_awaiting_service(result: DrinkResult)
signal bartender_placed_drink(delivery_key: StringName)
signal worker_picked_drink(delivery_key: StringName)
signal drink_delivered(order_id: int, result: DrinkResult, rewards: Dictionary)

@onready var _camera: Camera2D = %Camera2D
@onready var _camera_controller: CatBarCameraController = %CameraController
@onready var _bartending_station: BartendingStation = %BartendingStation
@onready var _bar_hotspot: Button = %BarHotspot
@onready var _mode_label: Label = %ModeLabel
@onready var _neko: NekoDeliveryActor = %Neko
@onready var _worker_cat: WorkerCatDeliveryActor = %WorkerCat
@onready var _counter_drink: CounterDrinkView = %CounterDrink
@onready var _pickup_marker: Marker2D = %DrinkPickupMarker
@onready var _booth_a_marker: Marker2D = %BoothAMarker
@onready var _patron_ambience: PatronAmbienceController = %PatronAmbience
@onready var _phone_shell: PhoneShell = %PhoneShell

var _mode_controller := CatBarModeController.new()
var _economy: EconomyState
var _progression := CatBarProgressionState.new()
var _settlement := CatBarSettlementService.new()
var _active_order: CatBarServiceOrder
var _wechat := WechatService.new()
var _save_service: SaveService
var _window_controller: DesktopWindowController


func _ready() -> void:
	_mode_controller.name = "ModeController"
	add_child(_mode_controller)
	_mode_controller.mode_changed.connect(_on_mode_changed)
	_mode_controller.focus_owner_changed.connect(_apply_focus_owner)
	_camera_controller.setup(_camera)
	_camera_controller.transition_finished.connect(_on_camera_transition_finished)
	_bar_hotspot.pressed.connect(enter_mixing)
	_bartending_station.drink_ready.connect(_on_drink_ready)
	_bartending_station.exit_requested.connect(_on_bartending_exit_requested)
	_neko.configure_handoff(_pickup_marker)
	_neko.drink_placed_on_bar.connect(_on_neko_drink_placed_on_bar)
	_worker_cat.configure_path(_pickup_marker, [_booth_a_marker])
	_worker_cat.drink_picked_up.connect(_on_worker_drink_picked_up)
	_worker_cat.delivery_completed.connect(_on_worker_delivery_completed)
	_counter_drink.take_drink()
	_phone_shell.bind_wechat(_wechat)
	_wechat.state_changed.connect(_on_wechat_state_changed)
	_phone_shell.open_requested.connect(open_phone)
	_phone_shell.close_requested.connect(close_phone)
	_setup_standalone_services()
	_style_world_controls()
	_bartending_station.visible = false
	_phone_shell.set_open(false)
	_apply_focus_owner(&"world")
	_update_mode_label()


func enter_mixing(instant: bool = false) -> bool:
	if not _mode_controller.request_mode(CatBarModeController.Mode.ENTERING_MIXING):
		return false
	if _bartending_station.prepare_for_entry():
		_refresh_active_order()
	_camera_controller.transition_to_mixing(instant)
	return true


func exit_mixing(instant: bool = false) -> bool:
	if _mode_controller.mode != CatBarModeController.Mode.MIXING and _mode_controller.mode != CatBarModeController.Mode.SERVING:
		return false
	if not _mode_controller.request_mode(CatBarModeController.Mode.RETURNING_OVERVIEW):
		return false
	_camera_controller.transition_to_overview(instant)
	return true


func open_phone() -> bool:
	if not _phone_allowed():
		phone_open_rejected.emit("当前动作中不能打开手机")
		return false
	if not _mode_controller.open_phone():
		phone_open_rejected.emit("当前场景模式不能打开手机")
		return false
	_phone_shell.set_open(true)
	_patron_ambience.set_suspended(true)
	return true


func close_phone() -> bool:
	if not _mode_controller.close_phone():
		return false
	_phone_shell.set_open(false)
	_patron_ambience.set_suspended(false)
	return true


func get_mode() -> CatBarModeController.Mode:
	return _mode_controller.mode


func get_focus_owner() -> StringName:
	return _mode_controller.focus_owner


func get_bartending_station() -> BartendingStation:
	return _bartending_station


func is_phone_visible() -> bool:
	return _phone_shell.is_open()


func is_transition_input_locked() -> bool:
	return _mode_controller.focus_owner == &"transition"


func setup_economy(economy: EconomyState, progression: CatBarProgressionState = null) -> void:
	if _economy != null and _economy.get_parent() == self:
		_economy.queue_free()
	_economy = economy
	if _economy.get_parent() == null:
		add_child(_economy)
	if progression != null:
		_progression = progression
	_settlement.setup(_economy, _progression)
	_refresh_active_order()


func setup(save_service: SaveService, window_controller: DesktopWindowController, save_data: Dictionary) -> void:
	_save_service = save_service
	_window_controller = window_controller
	var restored_economy := EconomyState.new()
	restored_economy.name = "EconomyState"
	restored_economy.restore(save_data)
	_progression.restore(
		save_data.get("content_unlocks", {}),
		[&"moonlit_meow", &"starlight_fizz"],
		SaveService.DEPRECATED_CONTENT_IDS
	)
	setup_economy(restored_economy, _progression)
	_wechat.restore(save_data.get("wechat", {}), SaveService.DEPRECATED_CONTENT_IDS)
	_bartending_station.restore_session(save_data.get("bartending", {}), SaveService.DEPRECATED_CONTENT_IDS)
	_refresh_active_order()
	save_now()


func make_save_snapshot() -> Dictionary:
	var result := _economy.to_save_data()
	if _window_controller != null:
		result.merge(_window_controller.capture_window_placement(), true)
	result["bartending"] = _bartending_station.get_session().to_save_data()
	result["wechat"] = _wechat.to_save_data()
	result["content_unlocks"] = _progression.to_save_data()
	return result


func save_now() -> void:
	if _save_service != null:
		_save_service.save_game(make_save_snapshot())


func set_delivery_instant_for_test(enabled: bool) -> void:
	_neko.instant_delivery = enabled
	_worker_cat.instant_delivery = enabled


func get_counter_drink() -> CounterDrinkView:
	return _counter_drink


func get_worker_cat() -> WorkerCatDeliveryActor:
	return _worker_cat


func get_economy() -> EconomyState:
	return _economy


func get_progression() -> CatBarProgressionState:
	return _progression


func get_wechat_service() -> WechatService:
	return _wechat


func get_phone_shell() -> PhoneShell:
	return _phone_shell


func _phone_allowed() -> bool:
	if _mode_controller.mode == CatBarModeController.Mode.OVERVIEW:
		return true
	if _mode_controller.mode != CatBarModeController.Mode.MIXING:
		return false
	var session_state := _bartending_station.get_session().state
	return session_state != BartendingSessionState.State.SHAKING and session_state != BartendingSessionState.State.POURING


func _on_camera_transition_finished(target_mode: CatBarModeController.Mode) -> void:
	if target_mode == CatBarModeController.Mode.MIXING:
		_bartending_station.visible = true
		_mode_controller.request_mode(CatBarModeController.Mode.MIXING)
	elif target_mode == CatBarModeController.Mode.OVERVIEW:
		_bartending_station.visible = false
		_mode_controller.request_mode(CatBarModeController.Mode.OVERVIEW)
	elif target_mode == CatBarModeController.Mode.SERVING:
		_bartending_station.visible = false


func _on_mode_changed(_previous: CatBarModeController.Mode, current: CatBarModeController.Mode) -> void:
	_update_mode_label()
	mode_changed.emit(current)


func _apply_focus_owner(owner_id: StringName) -> void:
	_bar_hotspot.disabled = owner_id != &"world"
	_phone_shell.set_entry_enabled(owner_id == &"world" or owner_id == &"bartending")
	_bartending_station.mouse_filter = Control.MOUSE_FILTER_STOP if owner_id == &"bartending" else Control.MOUSE_FILTER_IGNORE


func _on_drink_ready(result: DrinkResult) -> void:
	if _mode_controller.request_mode(CatBarModeController.Mode.SERVING):
		_bartending_station.visible = false
		_camera_controller.transition_to_service_overview()
		drink_awaiting_service.emit(result.copy())
		_neko.begin_handoff(
			_bartending_station.get_session().make_delivery_key(),
			_bartending_station.get_session().order_id,
			_bartending_station.get_session().booth_id,
			result
		)


func _on_neko_drink_placed_on_bar(
	delivery_key: StringName,
	order_id: int,
	booth_id: StringName,
	result: DrinkResult
) -> void:
	_counter_drink.show_drink(result)
	bartender_placed_drink.emit(delivery_key)
	_worker_cat.begin_delivery(delivery_key, order_id, booth_id, result)


func _on_worker_drink_picked_up(
	delivery_key: StringName,
	_order_id: int,
	_booth_id: StringName,
	_result: DrinkResult
) -> void:
	_counter_drink.take_drink()
	worker_picked_drink.emit(delivery_key)


func _on_worker_delivery_completed(
	delivery_key: StringName,
	order_id: int,
	_booth_id: StringName,
	result: DrinkResult
) -> void:
	var rewards := _settlement.settle_delivery(
		_active_order, _bartending_station.get_session(), delivery_key, result
	)
	if not bool(rewards.get("success", false)):
		return
	drink_delivered.emit(order_id, result.copy(), rewards.duplicate(true))
	_wechat.consume_event(StringName("delivery_%s" % delivery_key), &"order_delivered")
	save_now()
	exit_mixing(true)


func _on_bartending_exit_requested(instant: bool) -> void:
	_counter_drink.take_drink()
	save_now()
	exit_mixing(instant)


func _setup_standalone_services() -> void:
	if _economy == null:
		_economy = EconomyState.new()
		_economy.name = "CatBarEconomy"
		add_child(_economy)
	_settlement.setup(_economy, _progression)
	_refresh_active_order()


func _refresh_active_order() -> void:
	var session := _bartending_station.get_session()
	_active_order = CatBarServiceOrder.new(session.order_id, session.session_id, session.booth_id, session.recipe_id)


func _update_mode_label() -> void:
	if _mode_label != null:
		_mode_label.text = "模式：%s" % CatBarModeController.Mode.keys()[_mode_controller.mode]


func _on_wechat_state_changed() -> void:
	save_now()


func _style_world_controls() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.035, 0.045, 0.16)
	normal.border_color = Color(0.88, 0.55, 0.25, 0.38)
	normal.set_border_width_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.07, 0.08, 0.72)
	hover.border_color = Color(1.0, 0.72, 0.34, 0.95)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.35, 0.12, 0.11, 0.88)
	_bar_hotspot.add_theme_stylebox_override("normal", normal)
	_bar_hotspot.add_theme_stylebox_override("hover", hover)
	_bar_hotspot.add_theme_stylebox_override("pressed", pressed)
	_bar_hotspot.add_theme_color_override("font_color", Color(0.95, 0.78, 0.54, 0.72))
	_bar_hotspot.add_theme_color_override("font_hover_color", Color("ffe0a0"))
	_bar_hotspot.add_theme_font_size_override("font_size", 17)
	_mode_label.add_theme_color_override("font_color", Color("f6d8a2"))
	_mode_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.025, 0.95))
	_mode_label.add_theme_constant_override("outline_size", 5)
