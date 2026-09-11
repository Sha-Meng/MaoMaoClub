extends RefCounted
class_name SeatLeaseService

var _enabled_seats: Array[StringName] = []
var _leases: Dictionary[StringName, int] = {}


func configure(seats: Array[PatronSeatDefinition]) -> PackedStringArray:
	_enabled_seats.clear()
	_leases.clear()
	var errors := PackedStringArray()
	for seat: PatronSeatDefinition in seats:
		if seat == null or seat.seat_id.is_empty():
			errors.append("座位 ID 不能为空")
			continue
		if _enabled_seats.has(seat.seat_id):
			errors.append("重复座位 ID：%s" % seat.seat_id)
			continue
		if seat.enabled:
			_enabled_seats.append(seat.seat_id)
	return errors


func try_lease(visitor_id: int) -> StringName:
	if visitor_id <= 0:
		return &""
	for seat_id: StringName in _enabled_seats:
		if not _leases.has(seat_id):
			_leases[seat_id] = visitor_id
			return seat_id
	return &""


func release(seat_id: StringName, visitor_id: int) -> bool:
	if int(_leases.get(seat_id, -1)) != visitor_id:
		return false
	_leases.erase(seat_id)
	return true


func occupied_count() -> int:
	return _leases.size()


func enabled_capacity() -> int:
	return _enabled_seats.size()

