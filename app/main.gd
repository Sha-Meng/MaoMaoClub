extends Node

const TAVERN_LOOP_SCENE: PackedScene = preload("res://features/tavern_loop/tavern_loop.tscn")
const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")

@export var cat_bar_enabled: bool = true

var _save_service: SaveService
var _window_controller: DesktopWindowController
var _tavern_loop: TavernLoopController
var _cat_bar: CatBarController

func _ready() -> void:
	_save_service = SaveService.new()
	_save_service.name = "SaveService"
	add_child(_save_service)

	var save_data: Dictionary = _save_service.load_game()

	_window_controller = DesktopWindowController.new()
	_window_controller.name = "DesktopWindowController"
	add_child(_window_controller)
	_window_controller.apply_a_tier_window(save_data)

	if cat_bar_enabled:
		load_cat_bar(save_data)
	else:
		load_desktop_idle_mvp(save_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_before_quit()
		get_tree().quit()


func load_desktop_idle_mvp(save_data: Dictionary) -> void:
	_tavern_loop = TAVERN_LOOP_SCENE.instantiate() as TavernLoopController
	add_child(_tavern_loop)
	_tavern_loop.setup(_save_service, _window_controller, save_data)


func load_cat_bar(save_data: Dictionary) -> void:
	_cat_bar = CAT_BAR_SCENE.instantiate() as CatBarController
	add_child(_cat_bar)
	_cat_bar.setup(_save_service, _window_controller, save_data)


func save_before_quit() -> void:
	if _cat_bar != null:
		_cat_bar.save_now()
	elif _tavern_loop != null:
		_tavern_loop.save_now()
