extends Node
class_name CatBarCameraController

signal transition_finished(target_mode: CatBarModeController.Mode)

@export var overview_position: Vector2 = Vector2(480.0, 270.0)
@export var overview_zoom: Vector2 = Vector2.ONE
@export var mixing_position: Vector2 = Vector2(470.0, 185.0)
@export var mixing_zoom: Vector2 = Vector2(1.35, 1.35)
@export_range(0.05, 2.0, 0.05) var transition_seconds: float = 0.35

var _camera: Camera2D
var _active_tween: Tween


func setup(camera: Camera2D) -> void:
	_camera = camera
	_camera.position = overview_position.round()
	_camera.zoom = overview_zoom
	_camera.enabled = true


func transition_to_mixing(instant: bool = false) -> void:
	_transition(mixing_position, mixing_zoom, CatBarModeController.Mode.MIXING, instant)


func transition_to_overview(instant: bool = false) -> void:
	_transition(overview_position, overview_zoom, CatBarModeController.Mode.OVERVIEW, instant)


func transition_to_service_overview(instant: bool = false) -> void:
	_transition(overview_position, overview_zoom, CatBarModeController.Mode.SERVING, instant)


func cancel_transition() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _transition(
	target_position: Vector2,
	target_zoom: Vector2,
	target_mode: CatBarModeController.Mode,
	instant: bool
) -> void:
	if _camera == null:
		transition_finished.emit(target_mode)
		return
	cancel_transition()
	if instant:
		_camera.position = target_position.round()
		_camera.zoom = target_zoom
		transition_finished.emit(target_mode)
		return
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(_camera, "position", target_position, transition_seconds)
	_active_tween.tween_property(_camera, "zoom", target_zoom, transition_seconds)
	_active_tween.chain().tween_callback(_finish_transition.bind(target_position, target_mode))


func _finish_transition(target_position: Vector2, target_mode: CatBarModeController.Mode) -> void:
	if _camera != null:
		_camera.position = target_position.round()
	_active_tween = null
	transition_finished.emit(target_mode)
