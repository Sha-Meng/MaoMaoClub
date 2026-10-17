extends Control
class_name TavernLoopController

signal customer_spawned(customer_id: int)
signal service_started(customer_id: int, cat_id: int)
signal service_completed(customer_id: int, cat_id: int, coins: int, business_xp: int)
signal quit_requested

var simulation: TavernSimulation
var world: TavernWorldView
var hud: HudView
var _save_service: SaveService
var _window_controller: DesktopWindowController
var _autosave: float = 0.0
var _input_refresh: float = 0.0
var _is_setup: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TavernLayout.SIZE


func setup(save_service: SaveService, window_controller: DesktopWindowController, save_data: Dictionary) -> void:
	_save_service = save_service
	_window_controller = window_controller
	simulation = TavernSimulation.new(int(Time.get_ticks_usec()))
	simulation.restore(save_data)
	simulation.reward_earned.connect(_on_reward)
	simulation.visitor_arrived.connect(_on_visitor)
	simulation.layout_changed.connect(save_now)
	world = TavernWorldView.new()
	world.name = "World"
	world.simulation = simulation
	add_child(world)
	hud = HudView.new()
	hud.name = "Hud"
	add_child(hud)
	hud.configure(simulation, world)
	world.object_clicked.connect(hud.object_activated)
	world.selection_changed.connect(hud.set_selection)
	hud.window_drag_requested.connect(_window_controller.begin_window_drag)
	hud.minimize_requested.connect(_window_controller.minimize_window)
	hud.quit_requested.connect(quit_requested.emit)
	hud.scale_requested.connect(_window_controller.apply_display_scale)
	hud.layout_edited.connect(save_now)
	hud.interaction_changed.connect(_refresh_input_bounds)
	_save_service.save_failed.connect(_on_save_failed)
	get_window().focus_exited.connect(world.cancel_pointer)
	if _save_service.recovered_from_backup:
		hud.show_status("已从备份恢复进度。")
	_is_setup = true
	save_now()


func _process(delta: float) -> void:
	if not _is_setup:
		return
	simulation.advance(minf(delta, 60.0))
	_autosave += delta
	if _autosave >= 12.0:
		_autosave = 0.0
		save_now()
	_input_refresh += delta
	if _input_refresh >= 0.1:
		_input_refresh = 0.0
		_refresh_input_bounds()


func _refresh_input_bounds() -> void:
	_window_controller.set_interaction_bounds(world.interaction_bounds().merge(hud.interaction_bounds()))


func _on_reward(order_id: int, coins: int, xp: int, point: Vector2) -> void:
	world.show_reward(coins, xp, point)
	hud.refresh()
	service_completed.emit(order_id, 3, coins, xp)
	save_now()


func _on_visitor(person_id: String) -> void:
	customer_spawned.emit(person_id.trim_prefix("guest_").to_int())


func save_now() -> Error:
	if _save_service != null and simulation != null:
		return _save_service.save_game(make_save_snapshot())
	return OK


func _on_save_failed(message: String) -> void:
	hud.show_status(message)
	hud.set_panel_open(true)


func make_save_snapshot() -> Dictionary:
	if simulation == null:
		return {}
	var snapshot: Dictionary = simulation.to_snapshot()
	if _window_controller != null:
		snapshot.merge(_window_controller.capture_window_placement(), true)
	return snapshot
