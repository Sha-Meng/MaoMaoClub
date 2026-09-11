extends Node
class_name BartendingInputRouter

signal command_created(command: InteractionCommand)
signal pointer_capture_changed(active: bool)

var _capturing: bool = false


func route_click(subject_id: StringName, target_id: StringName, interaction_id: StringName, amount: float = 0.0) -> void:
	command_created.emit(InteractionCommand.new(subject_id, target_id, interaction_id, amount))


func route_gesture(
	subject_id: StringName,
	target_id: StringName,
	interaction_id: StringName,
	gesture: InteractionDefinition.Gesture,
	amount: float,
	metrics: Dictionary[StringName, float]
) -> void:
	command_created.emit(InteractionCommand.new(subject_id, target_id, interaction_id, amount, gesture, metrics))


func begin_pointer_capture() -> bool:
	if _capturing:
		return false
	_capturing = true
	pointer_capture_changed.emit(true)
	return true


func end_pointer_capture() -> void:
	if not _capturing:
		return
	_capturing = false
	pointer_capture_changed.emit(false)


func cancel_pointer_capture() -> void:
	end_pointer_capture()


func is_capturing() -> bool:
	return _capturing

