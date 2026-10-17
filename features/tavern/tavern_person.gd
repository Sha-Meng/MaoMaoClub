extends RefCounted
class_name TavernPerson

var id: String = ""
var profile_id: String = ""
var position: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2.ZERO
var state: String = "idle"
var resume_state: String = ""
var state_time: float = 0.0
var visit_time: float = 0.0
var animation_time: float = 0.0
var walk_phase: float = 0.0
var walk_cycles: float = 0.0
var walking: bool = false
var gait_lift: float = 0.0
var action: String = "idle"
var action_time: float = 0.0
var facing: float = 1.0
var seat_id: String = ""
var order_id: int = 0
var dragging: bool = false
var landing: float = 0.0
var cooldown: float = 0.0
var next_gesture: float = 5.0
var gesture_left: float = 0.0
var gesture_action: String = ""
var chat_partner: String = ""
var speech: String = ""
var speech_left: float = 0.0
var carrying: bool = false
var relaxed: bool = false
var drink_time: float = 0.0


func set_action(value: String) -> void:
	if action != value:
		action = value
		action_time = 0.0


func walk_to(destination: Vector2, delta: float, speed_factor: float = 1.0) -> bool:
	target = Vector2(destination.x, TavernLayout.GROUND)
	position.y = TavernLayout.GROUND
	var difference: float = target.x - position.x
	var distance: float = minf(absf(difference), maxf(0.0, walk_speed() * speed_factor * delta))
	walking = distance > 0.0001
	if walking:
		gait_lift = minf(1.0, gait_lift + delta / 0.15)
		facing = signf(difference)
		position.x += facing * distance
		walk_phase = fposmod(walk_phase + distance / stride_length(), 1.0)
		walk_cycles += distance / stride_length()
	set_action(("carry_tray" if carrying else "walk") if walking else ("hold_tray" if carrying else "idle_stand"))
	return absf(target.x - position.x) < 0.5


func stride_length() -> float:
	return TavernGroundedGait.stride_for(profile_id)


func walk_speed() -> float:
	return TavernGroundedGait.speed_for(profile_id)


func settle_gait(delta: float) -> void:
	if not walking or dragging:
		gait_lift = maxf(0.0, gait_lift - delta / 0.15)


func say(text: String, duration: float = 2.6) -> void:
	speech = text
	speech_left = duration


func to_data() -> Dictionary:
	return {"id": id, "profile": profile_id, "position": position, "home": home, "state": state,
		"resume_state": resume_state, "state_time": state_time, "visit_time": visit_time,
		"facing": facing, "seat": seat_id, "order": order_id, "carrying": carrying,
		"relaxed": relaxed, "drink_time": drink_time, "cooldown": cooldown}


static func from_data(data: Dictionary) -> TavernPerson:
	var person: TavernPerson = TavernPerson.new()
	person.id = str(data.get("id", ""))
	person.profile_id = str(data.get("profile", ""))
	person.position = safe_vector(data.get("position"), Vector2(480.0, 270.0))
	person.home = safe_vector(data.get("home"), person.position)
	person.target = person.position
	person.state = str(data.get("state", "idle"))
	person.resume_state = str(data.get("resume_state", ""))
	person.state_time = TavernData.number(data.get("state_time", 0.0))
	person.visit_time = TavernData.number(data.get("visit_time", 0.0))
	person.facing = -1.0 if TavernData.number(data.get("facing", 1.0), 1.0, -1.0, 1.0) < 0.0 else 1.0
	person.seat_id = str(data.get("seat", ""))
	person.order_id = TavernData.integer(data.get("order", 0), 0, 0, 2000000000)
	person.carrying = bool(data.get("carrying", false))
	person.relaxed = bool(data.get("relaxed", false))
	person.drink_time = TavernData.number(data.get("drink_time", 0.0))
	person.cooldown = TavernData.number(data.get("cooldown", 0.0))
	return person


static func safe_vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		var result: Vector2 = value as Vector2
		if is_finite(result.x) and is_finite(result.y):
			return result
	return fallback
