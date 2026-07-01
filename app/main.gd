extends Node

const TAVERN_LOOP_SCENE: PackedScene = preload("res://features/tavern_loop/tavern_loop.tscn")

var _save_service: SaveService
var _window_controller: DesktopWindowController
var _tavern_loop: TavernLoopController

func _ready() -> void:
	_save_service = SaveService.new()
	_save_service.name = "SaveService"
	add_child(_save_service)

	var save_data: Dictionary = _save_service.load_game()

	_window_controller = DesktopWindowController.new()
	_window_controller.name = "DesktopWindowController"
	add_child(_window_controller)
	_window_controller.apply_a_tier_window(save_data)

	load_desktop_idle_mvp(save_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_before_quit()
		get_tree().quit()


func load_desktop_idle_mvp(save_data: Dictionary) -> void:
	_tavern_loop = TAVERN_LOOP_SCENE.instantiate() as TavernLoopController
	add_child(_tavern_loop)
	_tavern_loop.setup(_save_service, _window_controller, save_data)


func save_before_quit() -> void:
	if _tavern_loop != null:
		_tavern_loop.save_now()
