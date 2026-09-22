extends Node
class_name CatBarModeController

signal mode_changed(previous_mode: Mode, current_mode: Mode)
signal focus_owner_changed(owner_id: StringName)

enum Mode {
	OVERVIEW,
	ENTERING_MIXING,
	MIXING,
	SERVING,
	PHONE_OPEN,
	RETURNING_OVERVIEW,
}

var mode: Mode = Mode.OVERVIEW
var focus_owner: StringName = &"world"
var _mode_before_phone: Mode = Mode.OVERVIEW


func request_mode(next_mode: Mode) -> bool:
	if next_mode == mode or not _is_transition_allowed(mode, next_mode):
		return false
	var previous := mode
	mode = next_mode
	_set_focus_owner(_focus_for_mode(mode))
	mode_changed.emit(previous, mode)
	return true


func open_phone() -> bool:
	if mode != Mode.OVERVIEW and mode != Mode.MIXING:
		return false
	_mode_before_phone = mode
	return request_mode(Mode.PHONE_OPEN)


func close_phone() -> bool:
	if mode != Mode.PHONE_OPEN:
		return false
	var previous := mode
	mode = _mode_before_phone
	_set_focus_owner(_focus_for_mode(mode))
	mode_changed.emit(previous, mode)
	return true


func _set_focus_owner(owner_id: StringName) -> void:
	if focus_owner == owner_id:
		return
	focus_owner = owner_id
	focus_owner_changed.emit(focus_owner)


func _focus_for_mode(value: Mode) -> StringName:
	match value:
		Mode.OVERVIEW:
			return &"world"
		Mode.MIXING:
			return &"bartending"
		Mode.PHONE_OPEN:
			return &"phone"
		Mode.SERVING:
			return &"serving"
	return &"transition"


func _is_transition_allowed(from: Mode, to: Mode) -> bool:
	match from:
		Mode.OVERVIEW:
			return to == Mode.ENTERING_MIXING or to == Mode.SERVING or to == Mode.PHONE_OPEN
		Mode.ENTERING_MIXING:
			return to == Mode.MIXING or to == Mode.RETURNING_OVERVIEW
		Mode.MIXING:
			return to == Mode.SERVING or to == Mode.PHONE_OPEN or to == Mode.RETURNING_OVERVIEW
		Mode.SERVING:
			return to == Mode.RETURNING_OVERVIEW
		Mode.RETURNING_OVERVIEW:
			return to == Mode.OVERVIEW
	return false
