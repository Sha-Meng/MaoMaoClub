extends Node

const TAVERN_LOOP_SCENE: PackedScene = preload("res://features/tavern_loop/tavern_loop.tscn")

@export var save_path: String = SaveService.SAVE_PATH
@export var session_port: int = SessionGuard.SESSION_PORT

var _save_service: SaveService
var _window_controller: DesktopWindowController
var _tavern_loop: TavernLoopController
var _session_guard: SessionGuard

func _ready() -> void:
	Engine.max_fps = 30
	_session_guard = SessionGuard.new()
	if not _session_guard.acquire(session_port):
		push_warning("酒馆已经运行，请从任务栏恢复；本实例不会修改存档。")
		get_tree().quit()
		return
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_quit_after_save)
	_save_service = SaveService.new()
	_save_service.save_path = save_path
	_save_service.name = "SaveService"
	add_child(_save_service)

	var save_data: Dictionary = _save_service.load_game()

	_window_controller = DesktopWindowController.new()
	_window_controller.name = "DesktopWindowController"
	add_child(_window_controller)
	_window_controller.apply_desktop_window(save_data)

	load_desktop_idle_mvp(save_data)
	_window_controller.window_placement_changed.connect(_on_window_placement_changed)


func _quit_after_save() -> void:
	if save_before_quit() == OK:
		get_tree().quit()


func _on_window_placement_changed(_position: Vector2i, _size: Vector2i) -> void:
	_tavern_loop.save_now()


func load_desktop_idle_mvp(save_data: Dictionary) -> void:
	_tavern_loop = TAVERN_LOOP_SCENE.instantiate() as TavernLoopController
	add_child(_tavern_loop)
	_tavern_loop.setup(_save_service, _window_controller, save_data)
	_tavern_loop.quit_requested.connect(_quit_after_save)


func save_before_quit() -> Error:
	if _tavern_loop != null:
		return _tavern_loop.save_now()
	return OK


func _exit_tree() -> void:
	if _session_guard != null:
		_session_guard.release()
