extends Node2D
class_name PatronAmbienceController

signal patron_entered(visitor_id: int, prototype_id: StringName, seat_id: StringName)
signal patron_left(visitor_id: int)

const DEFAULT_CONFIG: PatronAmbienceConfig = preload("res://features/cat_bar/patrons/configs/default_patron_ambience.tres")

@export var config: PatronAmbienceConfig = DEFAULT_CONFIG

var _leases := SeatLeaseService.new()
var _rng := RandomNumberGenerator.new()
var _active: Array[PatronAmbienceActor] = []
var _pool: Array[PatronAmbienceActor] = []
var _next_visitor_id: int = 1
var _spawn_elapsed: float = 0.0
var _suspended: bool = false
var _suspended_elapsed: float = 0.0


func _ready() -> void:
	_leases.configure(config.seats)
	_rng.seed = config.random_seed


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _suspended:
		_suspended_elapsed += delta
		if _suspended_elapsed < 0.5:
			return
		delta = _suspended_elapsed
		_suspended_elapsed = 0.0
	_spawn_elapsed += delta
	if _spawn_elapsed >= config.spawn_interval_seconds:
		_spawn_elapsed = 0.0
		spawn_now()
	for actor: PatronAmbienceActor in _active.duplicate():
		if actor.advance(delta):
			_release_actor(actor)


func spawn_now() -> PatronAmbienceActor:
	if _active.size() >= mini(config.max_active, _leases.enabled_capacity()) or config.prototypes.is_empty():
		return null
	var visitor_id := _next_visitor_id
	var seat_id := _leases.try_lease(visitor_id)
	if seat_id.is_empty():
		return null
	_next_visitor_id += 1
	var prototype := config.prototypes[_rng.randi_range(0, config.prototypes.size() - 1)]
	var actor := _obtain_actor()
	actor.activate(visitor_id, prototype, seat_id, _seat_position(seat_id), config.stay_seconds)
	_active.append(actor)
	patron_entered.emit(visitor_id, prototype.patron_id, seat_id)
	return actor


func set_suspended(value: bool) -> void:
	_suspended = value
	if not value:
		_suspended_elapsed = 0.0


func active_count() -> int:
	return _active.size()


func pooled_count() -> int:
	return _pool.size()


func active_signature() -> PackedStringArray:
	var result := PackedStringArray()
	for actor: PatronAmbienceActor in _active:
		result.append("%s@%s" % [actor.prototype_id, actor.seat_id])
	return result


func get_actor(visitor_id: int) -> PatronAmbienceActor:
	for actor: PatronAmbienceActor in _active:
		if actor.visitor_id == visitor_id:
			return actor
	return null


func _obtain_actor() -> PatronAmbienceActor:
	if not _pool.is_empty():
		return _pool.pop_back()
	var actor := PatronAmbienceActor.new()
	actor.name = "AmbiencePatron"
	add_child(actor)
	return actor


func _release_actor(actor: PatronAmbienceActor) -> void:
	var visitor_id := actor.visitor_id
	_leases.release(actor.seat_id, visitor_id)
	_active.erase(actor)
	actor.deactivate()
	_pool.append(actor)
	patron_left.emit(visitor_id)


func _seat_position(seat_id: StringName) -> Vector2:
	for seat: PatronSeatDefinition in config.seats:
		if seat.seat_id == seat_id:
			return seat.position_pixels
	return Vector2.ZERO
