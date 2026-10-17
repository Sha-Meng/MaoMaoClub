extends Control
class_name TavernWorldView

signal object_clicked(object_id: String)
signal selection_changed(object_id: String)

const WOOD: Color = Color("754b34")
const EDGE: Color = Color("463428")

var simulation: TavernSimulation
var art: TavernArt
var edit_mode: bool = false
var selected_id: String = ""
var hovered_id: String = ""
var font: Font
var _candidate: String = ""
var _pressed_at: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_attempted: bool = false
var _reward_labels: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = TavernLayout.SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var system_font: SystemFont = SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	font = system_font
	art = TavernArt.new()


func _process(delta: float) -> void:
	if simulation == null:
		return
	if not _candidate.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_pointer()
	if get_window().mode == Window.MODE_MINIMIZED:
		return
	hovered_id = hit_test(get_local_mouse_position())
	mouse_default_cursor_shape = Control.CURSOR_MOVE if _dragging or (edit_mode and simulation.can_drag(hovered_id)) else (Control.CURSOR_POINTING_HAND if not hovered_id.is_empty() else Control.CURSOR_ARROW)
	for index: int in range(_reward_labels.size() - 1, -1, -1):
		_reward_labels[index]["time"] = float(_reward_labels[index]["time"]) - delta
		if float(_reward_labels[index]["time"]) <= 0.0:
			_reward_labels.remove_at(index)
	queue_redraw()


func show_reward(amount: int, xp: int, point: Vector2) -> void:
	_reward_labels.append({"text": "+%d 金币  +%d 经营" % [amount, xp], "position": point + Vector2(-32.0, -72.0), "time": 1.7})


func object_position(id: String) -> Vector2:
	var person: TavernPerson = simulation.people.get(id) as TavernPerson
	if person != null:
		return person.position
	if simulation.layout.objects.has(id):
		return simulation.layout.objects[id]["position"] as Vector2
	return Vector2.ZERO


func object_bounds(id: String) -> Rect2:
	var person: TavernPerson = simulation.people.get(id) as TavernPerson
	if person != null:
		var bounds: Rect2 = art.body_bounds(person)
		return Rect2(person.position + bounds.position, bounds.size).grow(3.0)
	if not simulation.layout.objects.has(id):
		return Rect2()
	var item: Dictionary = simulation.layout.objects[id]
	var point: Vector2 = item["position"] as Vector2
	match str(item["kind"]):
		"shop": return Rect2(point - Vector2(TavernLayout.SHOP_SIZE.x * 0.5, TavernLayout.SHOP_SIZE.y), TavernLayout.SHOP_SIZE)
		"chair": return Rect2(point - Vector2(17.0, 39.0), Vector2(34.0, 41.0))
		"table": return Rect2(point - Vector2(27.0, 38.0), Vector2(54.0, 40.0))
	return Rect2()


func interaction_bounds() -> Rect2:
	var result: Rect2 = Rect2()
	for id: String in simulation.layout.objects:
		result = result.merge(object_bounds(id)) if result.has_area() else object_bounds(id)
	for id: String in simulation.people:
		result = result.merge(object_bounds(id))
	return result.grow(10.0)


func hit_test(point: Vector2) -> String:
	if simulation == null or art == null:
		return ""
	# In arrangement mode, chair legs and table rims remain selectable under a guest.
	if edit_mode:
		for id: String in simulation.layout.objects:
			if id != "shop" and object_bounds(id).has_point(point):
				return id
	var candidates: Array = simulation.people.values()
	# Reverse the fixed drawing order, with the bartender behind the counter.
	candidates.reverse()
	for person: TavernPerson in candidates:
		if person.id == "bartender":
			continue
		if object_bounds(person.id).has_point(point):
			return person.id
	if object_bounds("bartender").intersection(Rect2(0.0, 0.0, size.x, TavernLayout.GROUND - 55.0)).has_point(point):
		return "bartender"
	for id: String in simulation.layout.objects:
		if id != "shop" and object_bounds(id).has_point(point):
			return id
	return "shop" if object_bounds("shop").has_point(point) else ""


func _gui_input(event: InputEvent) -> void:
	if simulation == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drag_attempted = false
			_candidate = hit_test(button.position)
			if _candidate.is_empty():
				return
			_pressed_at = button.position
			_offset = button.position - object_position(_candidate)
			selected_id = _candidate
			selection_changed.emit(selected_id)
			accept_event()
		else:
			_release_pointer()
			accept_event()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and not _candidate.is_empty() and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _drag_attempted and motion.position.distance_to(_pressed_at) >= 5.0:
			_drag_attempted = true
			_dragging = simulation.begin_drag(_candidate)
		if _dragging:
			simulation.drag_to(motion.position - _offset)
		accept_event()


func _release_pointer() -> void:
	if _candidate.is_empty():
		return
	if _dragging:
		simulation.end_drag()
	elif not _drag_attempted:
		object_clicked.emit(_candidate)
	_candidate = ""
	_dragging = false
	_drag_attempted = false


func cancel_pointer() -> void:
	if _dragging:
		simulation.end_drag()
	_candidate = ""
	_dragging = false
	_drag_attempted = false


func _draw() -> void:
	if simulation == null or art == null:
		return
	var shop_rect: Rect2 = object_bounds("shop")
	draw_texture_rect(TavernArt.SHOP, shop_rect, false)
	for id: String in simulation.layout.objects:
		var item: Dictionary = simulation.layout.objects[id]
		if item["kind"] == "chair":
			_draw_chair(item["position"] as Vector2)
	var bartender: TavernPerson = simulation.people["bartender"] as TavernPerson
	var behind_bar: bool = not bartender.dragging and absf(bartender.position.x - simulation.layout.shop_position().x) < 70.0 and absf(bartender.position.y - simulation.layout.shop_position().y) < 20.0
	if behind_bar:
		_draw_person(bartender, simulation.layout.shop_position().y - 55.0)
		var front_rect: Rect2 = Rect2(shop_rect.position + Vector2(0.0, shop_rect.size.y * 0.59), Vector2(shop_rect.size.x, shop_rect.size.y * 0.41))
		var source_size: Vector2 = TavernArt.SHOP.get_size()
		draw_texture_rect_region(TavernArt.SHOP, front_rect, Rect2(0.0, source_size.y * 0.59, source_size.x, source_size.y * 0.41))
	var actors: Array = simulation.people.values()
	for person: TavernPerson in actors:
		if not (behind_bar and person.id == "bartender") and not person.dragging:
			_draw_person(person)
	for id: String in simulation.layout.objects:
		var item: Dictionary = simulation.layout.objects[id]
		if item["kind"] == "table":
			_draw_table(item["position"] as Vector2)
	for chair_id: String in simulation.layout.chair_ids():
		var item: Dictionary = simulation.layout.objects[chair_id]
		var cup: String = str(item.get("cup", "none"))
		if cup != "none":
			var occupant: TavernPerson = simulation.people.get(str(item.get("occupant", ""))) as TavernPerson
			if occupant == null or occupant.action != "drink":
				_draw_glass(simulation.layout.cup_position(chair_id), cup == "full", 1.0)
	var ready_count: int = 0
	for order: TavernOrder in simulation.orders.values():
		if order.phase in ["ready", "pickup"]:
			_draw_glass(simulation.layout.shop_position() + Vector2(28.0 + 12.0 * ready_count, -58.0), true, 0.85)
			ready_count += 1
	for person: TavernPerson in actors:
		if person.dragging:
			_draw_person(person)
		if not person.speech.is_empty():
			_draw_bubble(person)
	if edit_mode or not hovered_id.is_empty():
		var id: String = selected_id if edit_mode and not selected_id.is_empty() else hovered_id
		if simulation.people.has(id) or simulation.layout.objects.has(id):
			draw_rect(object_bounds(id), Color(0.97, 0.79, 0.36, 0.7), false, 1.0)
	for entry: Dictionary in _reward_labels:
		var age: float = 1.7 - float(entry["time"])
		var point: Vector2 = (entry["position"] as Vector2) - Vector2(0.0, age * 18.0)
		_draw_text(str(entry["text"]), point, Color(1.0, 0.87, 0.44, minf(1.0, float(entry["time"]))), 12)


func _draw_chair(point: Vector2) -> void:
	draw_line(point + Vector2(-11.0, 0.0), point + Vector2(-9.0, -25.0), EDGE, 3.0, true)
	draw_line(point + Vector2(12.0, 0.0), point + Vector2(8.0, -25.0), EDGE, 3.0, true)
	draw_line(point + Vector2(10.0, -24.0), point + Vector2(14.0, -39.0), WOOD, 3.0, true)
	draw_line(point + Vector2(-10.0, -32.0), point + Vector2(13.0, -35.0), WOOD, 4.0, true)
	draw_style_box(_wood_style(), Rect2(point + Vector2(-14.0, -27.0), Vector2(27.0, 5.0)))


func _draw_table(point: Vector2) -> void:
	draw_line(point + Vector2(0.0, -32.0), point + Vector2(0.0, -4.0), EDGE, 4.0, true)
	draw_line(point + Vector2(0.0, -8.0), point + Vector2(-17.0, 0.0), WOOD, 3.0, true)
	draw_line(point + Vector2(0.0, -8.0), point + Vector2(17.0, 0.0), WOOD, 3.0, true)
	draw_style_box(_wood_style(), Rect2(point + Vector2(-26.0, -37.0), Vector2(52.0, 7.0)))
	draw_line(point + Vector2(-20.0, -35.0), point + Vector2(20.0, -35.0), Color("bd8e5c"), 1.0, true)


func _wood_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = WOOD
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _draw_person(person: TavernPerson, clip_at_y: float = INF) -> void:
	var height: float = float(CastCatalog.profile(person.profile_id)["height"])
	var shift: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var stretch: Vector2 = Vector2.ONE
	if person.action == "mix_drink":
		rotation = sin(person.action_time * 15.0) * 0.035
	elif person.action == "drag_hold":
		rotation = sin(simulation.clock * 5.0) * 0.045
		shift.y = -3.0
	elif person.action == "land":
		stretch = Vector2(1.0 + person.landing * 0.15, 1.0 - person.landing * 0.16)
	elif person.action == "slow_nod" or person.action == "listen":
		rotation = sin(person.action_time * 2.2) * 0.018
	elif person.action in ["chat", "story", "quip", "greet"]:
		rotation = sin(person.action_time * 4.0) * (0.028 if person.profile_id == "customer_squirrel" else 0.012)
	elif person.action == "laugh":
		shift.y = -absf(sin(person.action_time * 7.0)) * 1.5
	elif person.action not in ["sit_down", "stand_up", "walk", "carry_tray"]:
		stretch.y = 1.0 + sin(person.animation_time * 2.0) * 0.004
	draw_set_transform(person.position + shift, rotation, Vector2(person.facing, 1.0) * stretch)
	var body: PackedVector2Array = art.body_polygon(person)
	if art.uses_walk_animation(person) and not is_finite(clip_at_y):
		art.walk_animation.draw_on(self, person)
	elif art.drinks.supports(person):
		art.drinks.draw_on(self, person)
	elif is_finite(clip_at_y):
		var limit: float = clip_at_y - person.position.y
		var clip: PackedVector2Array = PackedVector2Array([Vector2(-300.0, -300.0), Vector2(300.0, -300.0), Vector2(300.0, limit), Vector2(-300.0, limit)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(body, clip):
			draw_polygon(piece, PackedColorArray([Color.WHITE]), art.uvs_for_body(person, piece), art.texture_for(person.profile_id))
	else:
		draw_polygon(body, PackedColorArray([Color.WHITE]), art.texture_uvs[person.profile_id][art.pose_for(person)] as PackedVector2Array, art.texture_for(person.profile_id))
	_draw_person_props(person, height)
	draw_set_transform(Vector2.ZERO)


func _draw_person_props(person: TavernPerson, height: float) -> void:
	if art.uses_walk_animation(person):
		# Held cups and trays are already in the complete character frame.
		return
	var hand: Vector2 = Vector2(height * 0.22, -height * 0.51)
	if person.profile_id == "customer_dog":
		var bag_point: Vector2 = Vector2(-height * 0.26, -2.0 if person.state in ["waiting", "drinking", "paying", "seating", "standing"] else -height * 0.3)
		draw_rect(Rect2(bag_point + Vector2(-6.0, -8.0), Vector2(12.0, 8.0)), Color("65432e"))
		draw_rect(Rect2(bag_point + Vector2(-6.0, -8.0), Vector2(12.0, 8.0)), Color("35291e"), false, 1.0)
		draw_arc(bag_point + Vector2(0.0, -8.0), 3.0, PI, TAU, 10, Color("b68b50"), 1.0, true)
	if person.action == "drink":
		# The six drinking poses include the fingers, wrist and glass as one contact.
		return
	elif person.profile_id == "manager":
		# The bent near arm includes its glass and gripping fingers in one cutout.
		return
	elif person.action == "mix_drink":
		var shaker: Vector2 = Vector2(height * 0.22 + sin(person.action_time * 16.0) * 2.0, -height * 0.58)
		draw_style_box(_metal_style(), Rect2(shaker - Vector2(4.0, 13.0), Vector2(8.0, 15.0)))
		draw_line(shaker + Vector2(-3.0, -13.0), shaker + Vector2(3.0, -13.0), Color("c9d1cb"), 3.0)
	elif person.action == "pour_drink":
		var pour: Vector2 = Vector2(height * 0.07, -height * 0.57)
		draw_line(pour + Vector2(-6.0, -4.0), pour + Vector2(6.0, -2.0), Color("537456"), 5.0, true)
		draw_line(pour + Vector2(6.0, -2.0), pour + Vector2(9.0, 11.0), Color(0.96, 0.67, 0.25, 0.8), 1.5, true)
		_draw_glass(pour + Vector2(9.0, 15.0), true, 0.85)
	elif person.action in ["place_drink", "align_glass"]:
		_draw_glass(hand + Vector2(9.0 * minf(person.action_time, 0.8), 1.0), true, 0.9)
	elif person.carrying or person.action == "take_tray":
		var tray: Vector2 = Vector2(height * 0.39, -height * 0.46)
		draw_line(tray + Vector2(-12.0, 0.0), tray + Vector2(14.0, 0.0), EDGE, 3.0, true)
		_draw_glass(tray, true, 0.9)
	elif person.action == "collect_glass":
		_draw_glass(hand, false, 0.9)
	elif person.action == "wipe_glass":
		_draw_glass(hand, false, 0.9)
		draw_circle(hand + Vector2(sin(person.action_time * 8.0) * 3.0, -3.0), 3.0, Color("e4ce9e"))
	elif person.action == "pickup_bottle":
		draw_line(hand + Vector2(0.0, -11.0), hand, Color("69805a"), 4.0, true)
	elif person.action in ["wipe_counter", "wipe_table"]:
		var cloth: Vector2 = hand + Vector2(sin(person.action_time * 7.0) * 7.0, 0.0)
		draw_rect(Rect2(cloth, Vector2(8.0, 3.0)), Color("e4ce9e"))
	if person.action == "sketch":
		var pencil: Vector2 = Vector2(height * 0.1, -height * 0.3 + sin(person.action_time * 10.0) * 1.0)
		draw_line(pencil, pencil + Vector2(6.0, -8.0), Color("c69850"), 1.5, true)
	elif person.action == "show_sketch":
		var page: Vector2 = Vector2(height * 0.08, -height * 0.34)
		draw_rect(Rect2(page, Vector2(10.0, 9.0)), Color("f1e2b5"))
		draw_arc(page + Vector2(5.0, 4.0), 2.0, 0.0, TAU, 8, Color("8d7554"), 0.7, true)
	elif person.action == "loosen_tie":
		var tie: Vector2 = Vector2(0.0, -height * 0.56 + minf(person.action_time, 1.0) * 3.0)
		draw_line(tie, tie + Vector2(3.0, 8.0), Color("8f4146"), 3.0, true)
	elif person.action == "apron":
		draw_line(Vector2(-5.0, -height * 0.35), Vector2(5.0 + sin(person.action_time * 5.0), -height * 0.35), Color("e1b775"), 1.2, true)
	elif person.action == "adjust_chain":
		for index: int in range(4):
			draw_arc(Vector2(-8.0 + index * 5.0, -height * 0.62 + sin(person.action_time * 5.0) * 1.5), 3.0, 0.0, TAU, 8, Color("e2ad43"), 1.2, true)


func _metal_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("a9b6b0")
	style.border_color = Color("475651")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _draw_glass(point: Vector2, full: bool, factor: float) -> void:
	var rect: Rect2 = Rect2(point - Vector2(4.0, 9.0) * factor, Vector2(8.0, 10.0) * factor)
	draw_rect(rect, Color(0.91, 0.97, 0.94, 0.23), true)
	if full:
		draw_rect(Rect2(rect.position + Vector2(1.0, 4.0) * factor, Vector2(6.0, 5.0) * factor), Color(0.94, 0.57, 0.13, 0.86), true)
	draw_rect(rect, Color("ede2c9"), false, 0.9, true)
	draw_line(rect.position + Vector2(1.5, 2.0) * factor, rect.position + Vector2(1.5, 6.0) * factor, Color.WHITE, 0.8, true)


func _draw_bubble(person: TavernPerson) -> void:
	var text: String = person.speech
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var width: float = minf(180.0, text_width + 16.0)
	var height: float = art.draw_size(person).y
	var origin: Vector2 = person.position + Vector2(-width * 0.5, -height - 26.0)
	origin.x = clampf(origin.x, 4.0, size.x - width - 4.0)
	origin.y = maxf(3.0, origin.y)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.86, 0.96)
	style.border_color = Color("ad8b62")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	draw_style_box(style, Rect2(origin, Vector2(width, 22.0)))
	draw_string(font, origin + Vector2(8.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, 11, Color("4b3629"))


func _draw_text(text: String, point: Vector2, color: Color, font_size: int) -> void:
	draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, Color(0.2, 0.13, 0.08, color.a))
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
