extends RefCounted
class_name TavernSimulation

signal reward_earned(order_id: int, coins: int, xp: int, position: Vector2)
signal visitor_arrived(person_id: String)
signal layout_changed

const MAX_GUESTS: int = 4
const DRINK_DURATION: float = 22.0
const CHAT_DURATION: float = 5.2
const GUEST_STATES: Array[String] = ["entering", "seating", "waiting", "drinking", "paying", "standing", "leaving", "reseating"]
const ORDER_PHASES: Array[String] = ["queued", "mixing", "pouring", "placing", "ready", "pickup", "delivering", "serving", "drinking", "paid"]

var layout: TavernLayout = TavernLayout.new()
var people: Dictionary = {}
var orders: Dictionary = {}
var coins: int = 0
var business_xp: int = 0
var served_total: int = 0
var clock: float = 0.0
var display_scale: float = 1.0
var auto_spawn: bool = true
var spawn_in: float = 0.8
var next_guest_id: int = 1
var next_order_id: int = 1
var roster_index: int = 0
var dragged_object: String = ""
var conversation: Dictionary = {}
var chats_completed: int = 0
var chats_declined: int = 0
var seen_actions: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _settled_ids: Array[int] = []
var _pair_cooldowns: Dictionary = {}
var _dragged_seat_occupant: String = ""


func _init(random_seed: int = 17) -> void:
	rng.seed = random_seed
	_create_staff()


func _create_staff() -> void:
	for id: String in CastCatalog.STAFF_IDS:
		var person: TavernPerson = TavernPerson.new()
		person.id = id
		person.profile_id = id
		person.position = layout.homes[id] as Vector2
		person.home = person.position
		person.target = person.position
		person.next_gesture = rng.randf_range(4.0, 9.0)
		people[id] = person


func guest_count() -> int:
	return people.size() - CastCatalog.STAFF_IDS.size()


func spawn_guest(profile_id: String = "") -> TavernPerson:
	if guest_count() >= MAX_GUESTS:
		return null
	var chosen: String = profile_id
	if chosen.is_empty():
		chosen = CastCatalog.CUSTOMER_IDS[roster_index % CastCatalog.CUSTOMER_IDS.size()]
		roster_index += 1
	if not CastCatalog.is_customer(chosen):
		return null
	var person: TavernPerson = TavernPerson.new()
	person.id = "guest_%d" % next_guest_id
	next_guest_id += 1
	person.profile_id = chosen
	person.state = "entering"
	person.position = Vector2(35.0 if next_guest_id % 2 == 0 else 925.0, TavernLayout.GROUND)
	person.home = person.position
	person.target = person.position
	person.next_gesture = rng.randf_range(3.0, 7.0)
	people[person.id] = person
	_reserve_seat(person)
	visitor_arrived.emit(person.id)
	return person


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var remaining: float = minf(delta, 60.0)
	while remaining > 0.00001:
		var step: float = minf(remaining, 0.1)
		_tick(step)
		remaining -= step


func _tick(delta: float) -> void:
	clock += delta
	if fmod(clock, 10.0) < delta:
		for pair: String in _pair_cooldowns.keys():
			if float(_pair_cooldowns[pair]) < clock:
				_pair_cooldowns.erase(pair)
	for order: TavernOrder in orders.values():
		if order.phase == "ready":
			order.elapsed += delta
	for person: TavernPerson in people.values():
		person.walking = false
		person.visit_time += delta
		person.cooldown = maxf(0.0, person.cooldown - delta)
		person.speech_left = maxf(0.0, person.speech_left - delta)
		if person.speech_left == 0.0:
			person.speech = ""
		if person.dragging:
			person.set_action("drag_hold")
		elif person.landing > 0.0:
			person.landing = maxf(0.0, person.landing - delta)
			person.set_action("land")
		else:
			person.animation_time += delta
			person.action_time += delta
			if person.seat_id.is_empty() or dragged_object != person.seat_id:
				person.state_time += delta
	if auto_spawn:
		spawn_in -= delta
		if spawn_in <= 0.0 and guest_count() < MAX_GUESTS:
			spawn_guest()
			spawn_in = rng.randf_range(6.0, 9.0)
	_update_guests(delta)
	_update_bartender(delta)
	_update_server(delta)
	_update_manager(delta)
	_update_conversation(delta)
	_try_guest_conversation()
	for person: TavernPerson in people.values():
		seen_actions[person.action] = int(seen_actions.get(person.action, 0)) + 1
		person.settle_gait(delta)


func _blocked(person: TavernPerson) -> bool:
	return person.dragging or person.landing > 0.0 or (not person.seat_id.is_empty() and dragged_object == person.seat_id)


func _reserve_seat(person: TavernPerson) -> bool:
	if not person.seat_id.is_empty() and layout.objects.has(person.seat_id):
		return true
	var seat: String = layout.nearest_free_chair(person.position, dragged_object)
	if seat.is_empty():
		return false
	layout.objects[seat]["occupant"] = person.id
	person.seat_id = seat
	return true


func _release_seat(person: TavernPerson, leave_empty_cup: bool = false) -> void:
	if layout.objects.has(person.seat_id):
		var chair: Dictionary = layout.objects[person.seat_id]
		if str(chair.get("occupant", "")) == person.id:
			chair["occupant"] = ""
			chair["dirty"] = leave_empty_cup
			chair["cup"] = "empty" if leave_empty_cup else "none"
			chair["order"] = person.order_id if leave_empty_cup else 0
	person.seat_id = ""


func _set_state(person: TavernPerson, value: String) -> void:
	person.state = value
	person.state_time = 0.0
	person.gesture_left = 0.0


func _update_guests(delta: float) -> void:
	for id: String in people.keys():
		var person: TavernPerson = people[id] as TavernPerson
		if not CastCatalog.is_customer(person.profile_id) or _blocked(person):
			continue
		match person.state:
			"entering", "reseating":
				if not _reserve_seat(person):
					person.set_action("idle_stand")
					continue
				var destination: Vector2 = layout.objects[person.seat_id]["position"] as Vector2
				if person.walk_to(destination, delta):
					_set_state(person, "seating")
					person.set_action("sit_down")
			"seating":
				person.set_action("sit_down")
				if person.state_time >= 0.55:
					if person.order_id == 0:
						_queue_order(person)
					var order: TavernOrder = orders.get(person.order_id) as TavernOrder
					if order != null and order.delivered:
						_set_state(person, "drinking")
						layout.objects[person.seat_id]["cup"] = "full"
					else:
						_set_state(person, "waiting")
						person.set_action("order")
						person.gesture_left = 0.7
			"waiting":
				if person.order_id == 0:
					_queue_order(person)
				_idle_person(person, delta, true)
			"drinking":
				if person.action == "receive_drink" and person.gesture_left > 0.0:
					person.gesture_left -= delta
					continue
				if person.chat_partner.is_empty():
					person.drink_time += delta
					if fmod(person.drink_time, 6.0) < 1.35:
						person.set_action("drink")
					else:
						_idle_person(person, delta, true)
				if person.drink_time >= DRINK_DURATION:
					end_conversation(person.id)
					_set_state(person, "paying")
					settle_order(person.order_id)
					person.set_action("pay")
					person.say("谢谢，下次见！", 2.0)
			"paying":
				person.set_action("pay")
				if person.state_time >= 1.2:
					_set_state(person, "standing")
			"standing":
				person.set_action("stand_up")
				if person.state_time >= 0.5:
					_release_seat(person, true)
					_set_state(person, "leaving")
			"leaving":
				var destination: Vector2 = Vector2(24.0 if person.position.x < 480.0 else 936.0, person.position.y)
				if person.walk_to(destination, delta):
					end_conversation(person.id)
					var order: TavernOrder = orders.get(person.order_id) as TavernOrder
					if order != null and order.paid and not _order_has_cup(order.id):
						orders.erase(order.id)
					people.erase(id)
		person.relaxed = person.visit_time > 8.0


func _queue_order(person: TavernPerson) -> void:
	var order: TavernOrder = TavernOrder.new()
	order.id = next_order_id
	next_order_id += 1
	order.customer_id = person.id
	order.coins = rng.randi_range(5, 12)
	orders[order.id] = order
	person.order_id = order.id
	person.say("一杯，谢谢。", 1.6)


func _idle_person(person: TavernPerson, delta: float, seated: bool = false) -> void:
	if not person.chat_partner.is_empty():
		return
	if person.action in ["react_click", "order"] and person.gesture_left > 0.0:
		person.gesture_left -= delta
		return
	person.next_gesture -= delta
	if person.gesture_left > 0.0:
		person.gesture_left -= delta
		person.set_action(person.gesture_action if not person.gesture_action.is_empty() else str(CastCatalog.profile(person.profile_id)["gesture"]))
	elif person.next_gesture <= 0.0:
		person.gesture_left = 1.8
		person.next_gesture = rng.randf_range(7.0, 14.0)
		person.gesture_action = str(CastCatalog.profile(person.profile_id)["gesture"])
		if person.visit_time > 18.0:
			var variants: Array = {"bartender": ["align_glass", "wipe_glass", "wipe_counter", "pickup_bottle"], "manager": ["greet", "toast", "adjust_chain", "laugh"], "customer_rabbit": ["sketch", "show_sketch"], "server": ["apron", "greet"]}.get(person.profile_id, [person.gesture_action])
			person.gesture_action = str(variants[rng.randi_range(0, variants.size() - 1)])
		person.set_action(person.gesture_action)
	else:
		person.set_action("idle_sit" if seated else ("idle" if person.id == "manager" else "idle_work"))


func _update_bartender(delta: float) -> void:
	var bartender: TavernPerson = people["bartender"] as TavernPerson
	if _blocked(bartender) or dragged_object == "shop":
		return
	var home: Vector2 = layout.homes["bartender"] as Vector2
	if bartender.position.distance_to(home) > 1.0:
		bartender.walk_to(home, delta)
		return
	var order: TavernOrder = orders.get(bartender.order_id) as TavernOrder
	if order == null or order.phase not in ["mixing", "pouring", "placing"]:
		bartender.order_id = 0
		for candidate: TavernOrder in orders.values():
			var customer: TavernPerson = people.get(candidate.customer_id) as TavernPerson
			if candidate.phase == "queued" and customer != null and not _blocked(customer) and not customer.seat_id.is_empty():
				end_conversation("bartender")
				order = candidate
				bartender.order_id = candidate.id
				candidate.change_phase("mixing")
				break
	if bartender.order_id == 0:
		_idle_person(bartender, delta)
		return
	var customer: TavernPerson = people.get(order.customer_id) as TavernPerson
	if customer == null or _blocked(customer) or customer.seat_id.is_empty():
		bartender.set_action("idle_work")
		return
	order.elapsed += delta
	match order.phase:
		"mixing":
			bartender.set_action("mix_drink")
			if order.elapsed >= 3.2:
				order.change_phase("pouring")
		"pouring":
			bartender.set_action("pour_drink")
			if order.elapsed >= 1.2:
				order.change_phase("placing")
		"placing":
			bartender.set_action("place_drink")
			if order.elapsed >= 0.8:
				order.change_phase("ready")
				bartender.order_id = 0


func _update_server(delta: float) -> void:
	var server: TavernPerson = people["server"] as TavernPerson
	if _blocked(server):
		return
	if server.state in ["to_collect", "collect"]:
		_update_collection(server, delta)
		return
	var order: TavernOrder = orders.get(server.order_id) as TavernOrder
	if order == null or order.phase not in ["pickup", "delivering", "serving"]:
		server.order_id = 0
		server.carrying = false
		for candidate: TavernOrder in orders.values():
			var guest: TavernPerson = people.get(candidate.customer_id) as TavernPerson
			if candidate.phase == "ready" and candidate.elapsed >= 0.3 and guest != null and not _blocked(guest) and not guest.seat_id.is_empty():
				end_conversation("server")
				order = candidate
				server.order_id = order.id
				_set_state(server, "to_pickup")
				order.change_phase("pickup")
				break
	if server.order_id == 0:
		for chair_id: String in layout.chair_ids():
			if bool(layout.objects[chair_id].get("dirty", false)) and dragged_object != chair_id:
				end_conversation("server")
				server.seat_id = chair_id
				_set_state(server, "to_collect")
				return
		if server.state in ["to_wipe", "wipe_table"]:
			if not layout.objects.has(server.seat_id):
				server.seat_id = ""
				_set_state(server, "idle")
				return
			var table_point: Vector2 = layout.objects[server.seat_id]["position"] as Vector2
			if server.state == "to_wipe":
				if server.walk_to(layout.clamp_position(table_point + Vector2(34.0, 0.0)), delta):
					_set_state(server, "wipe_table")
			else:
				server.set_action("wipe_table")
				if server.state_time > 1.6:
					server.seat_id = ""
					_set_state(server, "idle")
			return
		if fmod(clock, 23.0) < 0.1:
			for item_id: String in layout.objects:
				if layout.objects[item_id]["kind"] == "table" and dragged_object != item_id:
					server.seat_id = item_id
					_set_state(server, "to_wipe")
					return
		var home: Vector2 = layout.homes["server"] as Vector2
		if server.position.distance_to(home) > 1.0:
			server.walk_to(home, delta)
		else:
			_set_state(server, "idle")
			_idle_person(server, delta)
		return
	var customer: TavernPerson = people.get(order.customer_id) as TavernPerson
	if customer == null or _blocked(customer) or customer.seat_id.is_empty():
		server.set_action("idle_work")
		return
	match order.phase:
		"pickup":
			if dragged_object == "shop":
				server.set_action("idle_work")
				return
			if server.walk_to(layout.pickup_position(), delta):
				server.set_action("take_tray")
				order.elapsed += delta
				if order.elapsed >= 0.45:
					server.carrying = true
					order.change_phase("delivering")
		"delivering":
			var destination: Vector2 = _service_position(customer.seat_id)
			if server.walk_to(destination, delta, 0.65 if server.position.distance_to(destination) < 30.0 else 1.0):
				end_conversation(customer.id)
				order.change_phase("serving")
		"serving":
			var destination: Vector2 = _service_position(customer.seat_id)
			if server.position.distance_to(destination) > 2.0:
				order.change_phase("delivering")
				return
			end_conversation(customer.id)
			server.set_action("serve_drink")
			order.elapsed += delta
			if order.elapsed >= 1.0:
				order.delivered = true
				order.change_phase("drinking")
				layout.objects[customer.seat_id]["cup"] = "full"
				_set_state(customer, "drinking")
				customer.set_action("receive_drink")
				customer.gesture_left = 0.65
				server.carrying = false
				server.order_id = 0
				server.say(str(CastCatalog.profile("server")["quote"]), 2.0)


func _service_position(chair_id: String) -> Vector2:
	if not layout.objects.has(chair_id):
		return layout.pickup_position()
	var position: Vector2 = layout.objects[chair_id]["position"] as Vector2
	return layout.clamp_position(position + Vector2(61.0 if position.x < layout.shop_position().x else -61.0, 0.0))


func _update_collection(server: TavernPerson, delta: float) -> void:
	if not layout.objects.has(server.seat_id) or not bool(layout.objects[server.seat_id].get("dirty", false)):
		server.seat_id = ""
		_set_state(server, "idle")
		return
	if dragged_object == server.seat_id:
		server.set_action("idle_work")
		return
	if server.state == "to_collect":
		if server.walk_to(_service_position(server.seat_id), delta):
			_set_state(server, "collect")
	else:
		if server.position.distance_to(_service_position(server.seat_id)) > 2.0:
			_set_state(server, "to_collect")
			return
		server.set_action("collect_glass")
		if server.state_time >= 0.8:
			var chair: Dictionary = layout.objects[server.seat_id]
			var order_id: int = int(chair.get("order", 0))
			chair["dirty"] = false
			chair["cup"] = "none"
			chair["order"] = 0
			var order: TavernOrder = orders.get(order_id) as TavernOrder
			if order != null and order.paid and not people.has(order.customer_id):
				orders.erase(order_id)
			server.seat_id = ""
			_set_state(server, "idle")


func settle_order(order_id: int) -> bool:
	var order: TavernOrder = orders.get(order_id) as TavernOrder
	if order == null or not order.delivered or order.paid or order_id in _settled_ids:
		return false
	order.paid = true
	order.change_phase("paid")
	_settled_ids.append(order_id)
	if _settled_ids.size() > 512:
		_settled_ids.pop_front()
	coins += order.coins
	business_xp += order.xp
	served_total += 1
	var customer: TavernPerson = people.get(order.customer_id) as TavernPerson
	if customer != null:
		_set_state(customer, "paying")
	reward_earned.emit(order_id, order.coins, order.xp, customer.position if customer != null else layout.shop_position())
	return true


func _order_has_cup(order_id: int) -> bool:
	for chair_id: String in layout.chair_ids():
		if int(layout.objects[chair_id].get("order", 0)) == order_id:
			return true
	return false


func _update_manager(delta: float) -> void:
	var manager: TavernPerson = people["manager"] as TavernPerson
	if _blocked(manager) or not manager.chat_partner.is_empty():
		return
	if manager.state == "wander":
		if manager.walk_to(manager.target, delta):
			_set_state(manager, "idle")
			manager.next_gesture = rng.randf_range(2.5, 5.0)
		return
	_idle_person(manager, delta)
	if manager.state_time < 3.5:
		return
	if manager.cooldown <= 0.0:
		var social_targets: Array = people.values().filter(func(person: TavernPerson) -> bool: return CastCatalog.is_customer(person.profile_id))
		if social_targets.is_empty():
			social_targets = [people["bartender"], people["server"]]
		for guest: TavernPerson in social_targets:
			if not _can_socialize(guest):
				continue
			if manager.position.distance_to(guest.position) < 110.0:
				if try_start_chat(manager.id, guest.id):
					return
			elif guest.cooldown <= 0.0:
				manager.target = layout.clamp_position(guest.position + Vector2(-65.0 if guest.position.x > manager.position.x else 65.0, 0.0))
				_set_state(manager, "wander")
				return
	manager.target = layout.clamp_position((layout.homes["manager"] as Vector2) + Vector2(rng.randf_range(-140.0, 140.0), 0.0))
	_set_state(manager, "wander")


func _can_socialize(person: TavernPerson) -> bool:
	if _blocked(person) or not person.chat_partner.is_empty() or person.cooldown > 0.0:
		return false
	if person.id == "manager":
		return person.state in ["idle", "wander"]
	if person.id in ["bartender", "server"]:
		return person.order_id == 0 and person.state == "idle" and not person.carrying
	if person.state not in ["waiting", "drinking"] or person.action == "drink":
		return false
	var order: TavernOrder = orders.get(person.order_id) as TavernOrder
	return order == null or order.phase not in ["serving", "delivering"]


func _social_state_valid(person: TavernPerson) -> bool:
	if person.id == "manager":
		return person.state in ["idle", "wander"]
	if person.id in ["bartender", "server"]:
		return person.order_id == 0 and person.state == "idle" and not person.carrying
	return person.state in ["waiting", "drinking"]


func try_start_chat(first_id: String, second_id: String) -> bool:
	if not conversation.is_empty() or first_id == second_id:
		return false
	var first: TavernPerson = people.get(first_id) as TavernPerson
	var second: TavernPerson = people.get(second_id) as TavernPerson
	if first == null or second == null or not _can_socialize(first) or not _can_socialize(second):
		return false
	if first.position.distance_to(second.position) > 160.0:
		return false
	var pair_key: String = _pair_key(first_id, second_id)
	if clock < float(_pair_cooldowns.get(pair_key, -1.0)):
		return false
	var profile: Dictionary = CastCatalog.profile(second.profile_id)
	if second.visit_time < float(profile["warmup"]):
		chats_declined += 1
		first.cooldown = 10.0
		second.cooldown = 8.0
		_pair_cooldowns[pair_key] = clock + 15.0
		second.say("先坐一会儿。", 1.5)
		return false
	first.chat_partner = second_id
	second.chat_partner = first_id
	first.gesture_left = 0.0
	second.gesture_left = 0.0
	first.facing = -1.0 if second.position.x < first.position.x else 1.0
	second.facing = -first.facing
	conversation = {"first": first_id, "second": second_id, "elapsed": 0.0, "turn": -1}
	return true


func _pair_key(first: String, second: String) -> String:
	return first + ":" + second if first < second else second + ":" + first


func _update_conversation(delta: float) -> void:
	if conversation.is_empty():
		return
	var first: TavernPerson = people.get(str(conversation["first"])) as TavernPerson
	var second: TavernPerson = people.get(str(conversation["second"])) as TavernPerson
	if first == null or second == null:
		end_conversation()
		return
	if _blocked(first) or _blocked(second) or not _social_state_valid(first) or not _social_state_valid(second):
		end_conversation()
		return
	conversation["elapsed"] = float(conversation["elapsed"]) + delta
	var elapsed: float = float(conversation["elapsed"])
	if elapsed >= CHAT_DURATION:
		chats_completed += 1
		end_conversation()
		return
	var turn: int = int(elapsed / 1.3)
	var speaker: TavernPerson = first if turn % 2 == 0 else second
	var listener: TavernPerson = second if turn % 2 == 0 else first
	speaker.set_action("chat")
	listener.set_action("listen")
	if turn != int(conversation["turn"]):
		conversation["turn"] = turn
		speaker.say(str(CastCatalog.profile(speaker.profile_id)["quote" if turn < 2 else "reply"]), 1.25)
		listener.speech = ""
		listener.speech_left = 0.0


func end_conversation(person_id: String = "") -> void:
	if conversation.is_empty():
		return
	var first_id: String = str(conversation["first"])
	var second_id: String = str(conversation["second"])
	if not person_id.is_empty() and person_id not in [first_id, second_id]:
		return
	for id: String in [first_id, second_id]:
		var person: TavernPerson = people.get(id) as TavernPerson
		if person != null:
			person.chat_partner = ""
			person.cooldown = 18.0
			person.speech = ""
			person.speech_left = 0.0
			person.set_action("idle_sit" if CastCatalog.is_customer(person.profile_id) else "idle")
			if id == "manager":
				_set_state(person, "idle")
	_pair_cooldowns[_pair_key(first_id, second_id)] = clock + 30.0
	conversation.clear()


func _try_guest_conversation() -> void:
	if not conversation.is_empty() or fmod(clock, 4.0) > 0.1:
		return
	for first: TavernPerson in people.values():
		if not CastCatalog.is_customer(first.profile_id) or not _can_socialize(first) or float(CastCatalog.profile(first.profile_id)["social"]) < 0.7:
			continue
		for second: TavernPerson in people.values():
			if first.id == second.id or not CastCatalog.is_customer(second.profile_id):
				continue
			if first.position.distance_to(second.position) < 140.0 and try_start_chat(first.id, second.id):
				return


func click_person(id: String) -> void:
	var person: TavernPerson = people.get(id) as TavernPerson
	if person == null or _blocked(person):
		return
	person.say(str(CastCatalog.profile(person.profile_id)["reply"]), 2.6)
	if person.id == "manager":
		person.set_action("react_click")
		person.gesture_left = 0.8
		person.next_gesture = 3.0


func can_drag(id: String) -> bool:
	return id != "bartender" and (people.has(id) or layout.objects.has(id))


func begin_drag(id: String) -> bool:
	if not dragged_object.is_empty() or not can_drag(id):
		return false
	dragged_object = id
	_dragged_seat_occupant = ""
	var person: TavernPerson = people.get(id) as TavernPerson
	if person != null:
		end_conversation(id)
		person.dragging = true
		person.walking = false
		person.resume_state = person.state
		person.set_action("drag_hold")
		if CastCatalog.is_customer(person.profile_id):
			var order: TavernOrder = orders.get(person.order_id) as TavernOrder
			_release_seat(person, order != null and order.paid)
	elif layout.objects[id]["kind"] == "chair":
		var occupant_id: String = str(layout.objects[id].get("occupant", ""))
		if not occupant_id.is_empty():
			end_conversation(occupant_id)
			var occupant: TavernPerson = people.get(occupant_id) as TavernPerson
			if occupant != null and occupant.state in ["entering", "reseating"]:
				# A reservation is not a seated guest. Release it without moving the guest.
				_release_seat(occupant)
			else:
				_dragged_seat_occupant = occupant_id
	return true


func drag_to(point: Vector2) -> void:
	if dragged_object.is_empty() or not is_finite(point.x) or not is_finite(point.y):
		return
	var person: TavernPerson = people.get(dragged_object) as TavernPerson
	if person != null:
		person.position = layout.clamp_position(point)
		return
	var item: Dictionary = layout.objects[dragged_object]
	var old_position: Vector2 = item["position"] as Vector2
	var new_position: Vector2 = layout.clamp_position(point, str(item["kind"]))
	item["position"] = new_position
	var offset: Vector2 = new_position - old_position
	if item["kind"] == "shop":
		for id: String in ["bartender", "server"]:
			layout.homes[id] = layout.clamp_position((layout.homes[id] as Vector2) + offset)
			var worker: TavernPerson = people[id] as TavernPerson
			worker.home = layout.homes[id] as Vector2
			if id == "bartender" or worker.position.distance_to(old_position) < 112.0:
				worker.position = layout.clamp_position(worker.position + offset)
		# Assign the locked role directly; repeated delta additions can accumulate rounding drift.
		layout.homes["bartender"] = new_position
		var bartender: TavernPerson = people["bartender"] as TavernPerson
		bartender.position = new_position
		bartender.home = new_position
		bartender.target = new_position
	elif item["kind"] == "chair":
		var occupant: TavernPerson = people.get(_dragged_seat_occupant) as TavernPerson
		if occupant != null:
			occupant.position = new_position


func end_drag() -> void:
	if dragged_object.is_empty():
		return
	var person: TavernPerson = people.get(dragged_object) as TavernPerson
	if person != null:
		person.dragging = false
		person.position = layout.place_position(person.position)
		person.home = person.position
		person.target = person.position
		person.landing = 0.35
		person.set_action("land")
		if CastCatalog.is_customer(person.profile_id):
			_set_state(person, "leaving" if person.resume_state in ["paying", "standing", "leaving"] else "reseating")
		else:
			layout.homes[person.id] = person.position
			if person.id == "manager":
				_set_state(person, "idle")
	else:
		var item: Dictionary = layout.objects[dragged_object]
		var old_position: Vector2 = item["position"] as Vector2
		drag_to(layout.place_position(old_position, str(item["kind"])))
	dragged_object = ""
	_dragged_seat_occupant = ""
	layout_changed.emit()


func remove_furniture(id: String) -> bool:
	if not layout.objects.has(id) or id == "shop" or dragged_object == id:
		return false
	var item: Dictionary = layout.objects[id]
	if item["kind"] == "chair":
		var occupant: TavernPerson = people.get(str(item.get("occupant", ""))) as TavernPerson
		if occupant != null:
			end_conversation(occupant.id)
			_release_seat(occupant)
			var guest_order: TavernOrder = orders.get(occupant.order_id) as TavernOrder
			_set_state(occupant, "leaving" if guest_order != null and guest_order.paid else "reseating")
		var order_id: int = int(item.get("order", 0))
		var order: TavernOrder = orders.get(order_id) as TavernOrder
		if order != null and order.paid and not people.has(order.customer_id):
			orders.erase(order_id)
	layout.objects.erase(id)
	layout_changed.emit()
	return true


func reset_layout() -> void:
	end_conversation()
	if not dragged_object.is_empty():
		end_drag()
	layout.reset()
	for person: TavernPerson in people.values():
		person.seat_id = ""
		if CastCatalog.is_customer(person.profile_id):
			if person.state not in ["leaving", "paying", "standing"]:
				_set_state(person, "reseating")
		else:
			person.position = layout.homes[person.id] as Vector2
			person.home = person.position
			person.target = person.position
			if person.id == "manager" or person.state in ["to_collect", "collect", "to_wipe", "wipe_table"]:
				_set_state(person, "idle")
	for order_id: int in orders.keys():
		var order: TavernOrder = orders[order_id] as TavernOrder
		if order.paid and not people.has(order.customer_id):
			orders.erase(order_id)
	layout_changed.emit()


func to_snapshot() -> Dictionary:
	var actor_data: Array[Dictionary] = []
	var order_data: Array[Dictionary] = []
	for person: TavernPerson in people.values():
		actor_data.append(person.to_data())
	for order: TavernOrder in orders.values():
		order_data.append(order.to_data())
	return {"coins": coins, "business_xp": business_xp, "served_customers_total": served_total,
		"tavern": {"layout": layout.to_data(), "people": actor_data, "orders": order_data,
		"next_guest": next_guest_id, "next_order": next_order_id, "roster": roster_index,
		"clock": clock, "spawn_in": spawn_in, "scale": display_scale, "rng_state": rng.state,
		"settled": _settled_ids.duplicate(), "chats_completed": chats_completed}}


func restore(snapshot: Dictionary) -> void:
	coins = TavernData.integer(snapshot.get("coins", 0), 0, 0, 2000000000)
	business_xp = TavernData.integer(snapshot.get("business_xp", 0), 0, 0, 2000000000)
	served_total = TavernData.integer(snapshot.get("served_customers_total", 0), 0, 0, 2000000000)
	var raw: Variant = snapshot.get("tavern", {})
	var data: Dictionary = raw as Dictionary if raw is Dictionary else {}
	var layout_data: Variant = data.get("layout", {})
	layout.restore(layout_data as Dictionary if layout_data is Dictionary else {})
	people.clear()
	orders.clear()
	conversation.clear()
	_pair_cooldowns.clear()
	dragged_object = ""
	_dragged_seat_occupant = ""
	_create_staff()
	next_guest_id = TavernData.integer(data.get("next_guest", 1), 1, 1, 2000000000)
	next_order_id = TavernData.integer(data.get("next_order", 1), 1, 1, 2000000000)
	roster_index = TavernData.integer(data.get("roster", 0), 0, 0, 2000000000)
	clock = _safe_time(data.get("clock", 0.0))
	spawn_in = clampf(_safe_time(data.get("spawn_in", 0.8)), 0.0, 9.0)
	display_scale = clampf(_safe_time(data.get("scale", 1.0)), 0.8, 1.2)
	chats_completed = TavernData.integer(data.get("chats_completed", 0))
	_settled_ids.clear()
	var settled: Variant = data.get("settled", [])
	if settled is Array:
		for value: Variant in settled:
			if _settled_ids.size() < 512:
				var settled_id: int = TavernData.integer(value, 0, 0, 2000000000)
				_settled_ids.append(settled_id)
				next_order_id = maxi(next_order_id, settled_id + 1)
	var actors: Variant = data.get("people", [])
	if actors is Array:
		for value: Variant in actors:
			if not value is Dictionary:
				continue
			var person: TavernPerson = TavernPerson.from_data(value as Dictionary)
			if not CastCatalog.PROFILES.has(person.profile_id) or person.id.is_empty():
				continue
			if CastCatalog.is_customer(person.profile_id):
				if guest_count() >= MAX_GUESTS or not person.id.begins_with("guest_") or people.has(person.id):
					continue
				if person.state not in GUEST_STATES:
					person.state = "entering"
				next_guest_id = maxi(next_guest_id, person.id.trim_prefix("guest_").to_int() + 1)
			elif person.id != person.profile_id:
				continue
			person.position = layout.clamp_position(person.position)
			person.home = layout.clamp_position(person.home)
			person.state_time = _safe_time(person.state_time)
			person.visit_time = _safe_time(person.visit_time)
			person.drink_time = _safe_time(person.drink_time)
			person.cooldown = maxf(_safe_time(person.cooldown), 3.0)
			person.next_gesture = rng.randf_range(4.0, 9.0)
			people[person.id] = person
	var saved_orders: Variant = data.get("orders", [])
	if saved_orders is Array:
		for value: Variant in saved_orders:
			if not value is Dictionary or orders.size() >= 32:
				continue
			var order: TavernOrder = TavernOrder.from_data(value as Dictionary)
			if order.id <= 0 or orders.has(order.id) or order.phase not in ORDER_PHASES:
				continue
			order.elapsed = _safe_time(order.elapsed)
			if order.id in _settled_ids:
				order.paid = true
			if order.paid:
				order.phase = "paid"
				order.delivered = true
			orders[order.id] = order
			next_order_id = maxi(next_order_id, order.id + 1)
	if data.get("rng_state") is int:
		rng.state = int(data["rng_state"])
	_repair_restored_links()


func _safe_time(value: Variant) -> float:
	return TavernData.number(value)


func _repair_restored_links() -> void:
	for chair_id: String in layout.chair_ids():
		layout.objects[chair_id]["occupant"] = ""
	for person: TavernPerson in people.values():
		if not CastCatalog.is_customer(person.profile_id):
			if person.id == "manager":
				person.state = "idle"
			continue
		var order: TavernOrder = orders.get(person.order_id) as TavernOrder
		if order == null or order.customer_id != person.id:
			person.order_id = 0
			order = null
			if person.state == "drinking":
				person.state = "waiting"
		if order != null and order.delivered and not order.paid:
			order.phase = "drinking"
		elif order != null and not order.delivered and person.state == "drinking":
			person.state = "waiting"
		if order != null and order.paid and person.state not in ["paying", "standing", "leaving"]:
			person.state = "paying"
		if not layout.objects.has(person.seat_id) or layout.objects[person.seat_id]["kind"] != "chair" or str(layout.objects[person.seat_id].get("occupant", "")) != "" or bool(layout.objects[person.seat_id].get("dirty", false)):
			person.seat_id = ""
			if person.state not in ["paying", "standing", "leaving"]:
				person.state = "reseating"
		else:
			layout.objects[person.seat_id]["occupant"] = person.id
			if person.state not in ["entering", "reseating"]:
				person.position = layout.objects[person.seat_id]["position"] as Vector2
	for order_id: int in orders.keys():
		var order: TavernOrder = orders[order_id] as TavernOrder
		var customer: TavernPerson = people.get(order.customer_id) as TavernPerson
		if customer == null:
			if not order.paid or not _order_has_cup(order_id):
				orders.erase(order_id)
		elif customer.order_id != order_id:
			orders.erase(order_id)
	var bartender: TavernPerson = people["bartender"] as TavernPerson
	var server: TavernPerson = people["server"] as TavernPerson
	bartender.position = layout.shop_position()
	bartender.home = bartender.position
	bartender.target = bartender.position
	for order: TavernOrder in orders.values():
		if order.phase in ["mixing", "pouring", "placing"]:
			if bartender.order_id == 0 or bartender.order_id == order.id:
				bartender.order_id = order.id
			else:
				order.change_phase("queued")
		if order.phase in ["pickup", "delivering", "serving"]:
			if server.order_id == 0 or server.order_id == order.id:
				server.order_id = order.id
				server.carrying = order.phase != "pickup"
			else:
				order.change_phase("ready")
	if not orders.has(bartender.order_id):
		bartender.order_id = 0
	if not orders.has(server.order_id):
		server.order_id = 0
		server.carrying = false
	if server.state in ["collect", "to_collect", "to_wipe", "wipe_table"] and not layout.objects.has(server.seat_id):
		server.state = "idle"
	for chair_id: String in layout.chair_ids():
		var chair: Dictionary = layout.objects[chair_id]
		if str(chair.get("occupant", "")).is_empty() and not bool(chair.get("dirty", false)):
			chair["cup"] = "none"


func validate_invariants() -> Array[String]:
	var errors: Array[String] = []
	var occupants: Array[String] = []
	for chair_id: String in layout.chair_ids():
		var occupant: String = str(layout.objects[chair_id].get("occupant", ""))
		if occupant.is_empty():
			continue
		if occupant in occupants or not people.has(occupant):
			errors.append("座位占用不唯一或人物不存在: " + chair_id)
		else:
			occupants.append(occupant)
			var person: TavernPerson = people[occupant] as TavernPerson
			if person.seat_id != chair_id:
				errors.append("人椅引用不一致: " + occupant)
	for person: TavernPerson in people.values():
		if not is_finite(person.position.x) or not is_finite(person.position.y):
			errors.append("位置非有限值: " + person.id)
		if person.position.y != TavernLayout.GROUND:
			errors.append("人物离开水平基线: " + person.id)
		if CastCatalog.is_customer(person.profile_id) and not person.seat_id.is_empty():
			if not layout.objects.has(person.seat_id) or str(layout.objects[person.seat_id].get("occupant", "")) != person.id:
				errors.append("人物座位引用失效: " + person.id)
		if person.dragging and dragged_object != person.id:
			errors.append("遗留拖动锁: " + person.id)
	for order: TavernOrder in orders.values():
		if not order.paid and not people.has(order.customer_id):
			errors.append("未完成订单丢失顾客")
		if order.paid and not order.delivered:
			errors.append("未送达订单被结算")
	if coins < 0 or business_xp < 0 or served_total < 0:
		errors.append("经济数值为负")
	for id: String in layout.objects:
		if (layout.objects[id]["position"] as Vector2).y != TavernLayout.GROUND:
			errors.append("物件离开水平基线: " + id)
	if dragged_object == "bartender" or (people["bartender"] as TavernPerson).position != layout.shop_position():
		errors.append("调酒员离开岗位或接受拖动")
	return errors
