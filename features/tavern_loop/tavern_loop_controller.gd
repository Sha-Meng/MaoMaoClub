extends Control
class_name TavernLoopController

signal customer_spawned(customer_id: int)
signal service_started(customer_id: int, cat_id: int)
signal service_completed(customer_id: int, cat_id: int, coins: int, business_xp: int)

var config: TavernLoopConfig = TavernLoopConfig.new()

var _save_service: SaveService
var _window_controller: DesktopWindowController
var _economy: EconomyState
var _hud: HudView
var _actor_layer: Control
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cats: Array[CatActor] = []
var _customers: Array[CustomerActor] = []
var _active_orders: Array[ServiceOrder] = []
var _spawn_accumulator: float = 0.0
var _next_spawn_interval: float = 0.0
var _next_customer_id: int = 1
var _next_order_id: int = 1
var _is_setup: bool = false

func _ready() -> void:
	custom_minimum_size = config.tavern_size
	size = config.tavern_size
	_rng.randomize()
	_build_placeholder_world()


func _process(delta: float) -> void:
	if not _is_setup:
		return
	_spawn_accumulator += delta
	if _spawn_accumulator >= _next_spawn_interval and _customers.size() < config.max_active_customers:
		_spawn_accumulator = 0.0
		_next_spawn_interval = _roll_spawn_interval()
		spawn_customer()
	assign_waiting_customers()
	advance_orders(delta)


func setup(save_service: SaveService, window_controller: DesktopWindowController, save_data: Dictionary) -> void:
	_save_service = save_service
	_window_controller = window_controller
	_economy = EconomyState.new()
	_economy.name = "EconomyState"
	add_child(_economy)
	_economy.restore(save_data)

	_hud = HudView.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.bind_economy(_economy)

	_spawn_cats()
	_next_spawn_interval = 1.0
	_is_setup = true
	save_now()


func spawn_customer() -> CustomerActor:
	var customer: CustomerActor = CustomerActor.new()
	customer.customer_id = _next_customer_id
	_next_customer_id += 1
	customer.config = _make_customer_config(customer.customer_id)
	customer.position = Vector2(size.x + 42.0, 226.0 + float((_customers.size() % 2) * 42))
	_actor_layer.add_child(customer)
	_customers.append(customer)
	customer.service_requested.connect(_on_customer_service_requested)
	customer.left_scene.connect(_on_customer_left_scene)
	customer.enter_to(Vector2(620.0, 232.0 + float((_customers.size() % 2) * 36)))
	customer_spawned.emit(customer.customer_id)
	return customer


func assign_waiting_customers() -> void:
	for customer: CustomerActor in _customers:
		if customer.state != CustomerState.State.REQUESTING_SERVICE and customer.state != CustomerState.State.WAITING_FOR_CAT:
			continue
		var cat: CatActor = _find_available_cat()
		if cat == null:
			customer.mark_waiting()
			continue
		_start_service(customer, cat)


func advance_orders(delta: float) -> void:
	for order: ServiceOrder in _active_orders.duplicate():
		if order.advance(delta):
			complete_order(order)


func complete_order(order: ServiceOrder) -> void:
	_active_orders.erase(order)
	var cat: CatActor = _find_cat(order.cat_id)
	if cat != null:
		cat.complete_service()
	var customer: CustomerActor = _find_customer(order.customer_id)
	if customer != null:
		customer.complete_service()
		customer.leave_to(Vector2(-90.0, customer.position.y))
	_economy.award_service_reward(order.coin_reward, order.business_xp_reward)
	_hud.show_service_reward(order.coin_reward, order.business_xp_reward, customer.position if customer != null else Vector2(520.0, 160.0))
	service_completed.emit(order.customer_id, order.cat_id, order.coin_reward, order.business_xp_reward)
	save_now()


func save_now() -> void:
	if _save_service == null or _economy == null:
		return
	var save_data: Dictionary = _economy.to_save_data()
	if _window_controller != null:
		save_data.merge(_window_controller.capture_window_placement(), true)
	_save_service.save_game(save_data)


func make_save_snapshot() -> Dictionary:
	var save_data: Dictionary = _economy.to_save_data()
	if _window_controller != null:
		save_data.merge(_window_controller.capture_window_placement(), true)
	return save_data


func _build_placeholder_world() -> void:
	var background: ColorRect = _make_color_rect("Background", Rect2(Vector2.ZERO, config.tavern_size), Color(0.18, 0.13, 0.11))
	add_child(background)
	var floor_band: ColorRect = _make_color_rect("FloorBand", Rect2(Vector2(0.0, 220.0), Vector2(config.tavern_size.x, 140.0)), Color(0.25, 0.18, 0.14))
	add_child(floor_band)
	var counter: ColorRect = _make_color_rect("Counter", Rect2(Vector2(94.0, 145.0), Vector2(330.0, 76.0)), Color(0.46, 0.24, 0.13))
	add_child(counter)
	var counter_top: ColorRect = _make_color_rect("CounterTop", Rect2(Vector2(82.0, 132.0), Vector2(354.0, 22.0)), Color(0.72, 0.43, 0.22))
	add_child(counter_top)
	for i: int in range(3):
		var stool: ColorRect = _make_color_rect("Seat%d" % i, Rect2(Vector2(560.0 + float(i * 82), 264.0), Vector2(44.0, 38.0)), Color(0.37, 0.22, 0.16))
		add_child(stool)
	_actor_layer = Control.new()
	_actor_layer.name = "ActorLayer"
	_actor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actor_layer.size = config.tavern_size
	add_child(_actor_layer)
	_add_world_label("猫猫 Club 桌面酒馆", Vector2(94.0, 96.0), 24)
	_add_world_label("顾客入口 ->", Vector2(760.0, 196.0), 16)


func _spawn_cats() -> void:
	var cat_positions: Array[Vector2] = [Vector2(122.0, 236.0), Vector2(236.0, 248.0), Vector2(348.0, 236.0)]
	var cat_colors: Array[Color] = [Color(1.0, 0.72, 0.34), Color(0.92, 0.88, 0.76), Color(0.58, 0.64, 0.94)]
	for index: int in range(config.cat_count):
		var cat: CatActor = CatActor.new()
		cat.cat_id = index + 1
		cat.config = CatConfig.new()
		cat.config.display_name = "猫猫%d" % cat.cat_id
		cat.config.body_color = cat_colors[index % cat_colors.size()]
		cat.position = cat_positions[index]
		cat.set_home_position(cat.position)
		_actor_layer.add_child(cat)
		_cats.append(cat)
		cat.clicked.connect(_on_cat_clicked)
		cat.drag_started.connect(_on_cat_drag_started)
		cat.drag_ended.connect(_on_cat_drag_ended)


func _start_service(customer: CustomerActor, cat: CatActor) -> void:
	var duration: float = _rng.randf_range(config.service_duration_min, config.service_duration_max)
	var coins: int = _rng.randi_range(config.coin_reward_min, config.coin_reward_max)
	var order: ServiceOrder = ServiceOrder.new(
		_next_order_id,
		customer.customer_id,
		cat.cat_id,
		duration,
		coins,
		config.business_xp_reward
	)
	_next_order_id += 1
	_active_orders.append(order)
	cat.assign_customer(customer.customer_id)
	customer.start_service(cat.cat_id)
	service_started.emit(customer.customer_id, cat.cat_id)


func _find_available_cat() -> CatActor:
	for cat: CatActor in _cats:
		if cat.is_service_available():
			return cat
	return null


func _find_cat(cat_id: int) -> CatActor:
	for cat: CatActor in _cats:
		if cat.cat_id == cat_id:
			return cat
	return null


func _find_customer(customer_id: int) -> CustomerActor:
	for customer: CustomerActor in _customers:
		if customer.customer_id == customer_id:
			return customer
	return null


func _roll_spawn_interval() -> float:
	return _rng.randf_range(config.customer_spawn_interval_min, config.customer_spawn_interval_max)


func _make_customer_config(customer_id: int) -> CustomerConfig:
	var customer_config: CustomerConfig = CustomerConfig.new()
	var palette: Array[Color] = [Color(0.48, 0.74, 1.0), Color(0.82, 0.58, 0.95), Color(0.52, 0.82, 0.58)]
	customer_config.display_name = "顾客%d" % customer_id
	customer_config.body_color = palette[customer_id % palette.size()]
	return customer_config


func _make_color_rect(node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var color_rect: ColorRect = ColorRect.new()
	color_rect.name = node_name
	color_rect.position = rect.position
	color_rect.size = rect.size
	color_rect.color = color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return color_rect


func _add_world_label(text: String, label_position: Vector2, font_size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = label_position
	label.size = Vector2(280.0, 32.0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	add_child(label)


func _on_customer_service_requested(customer_id: int) -> void:
	var customer: CustomerActor = _find_customer(customer_id)
	if customer != null:
		customer.mark_waiting()
	assign_waiting_customers()


func _on_customer_left_scene(customer_id: int) -> void:
	var customer: CustomerActor = _find_customer(customer_id)
	if customer != null:
		_customers.erase(customer)


func _on_cat_clicked(cat_id: int) -> void:
	_hud.show_service_reward(0, 0, Vector2(120.0 + float(cat_id * 54), 190.0))


func _on_cat_drag_started(cat_id: int) -> void:
	var cat: CatActor = _find_cat(cat_id)
	if cat != null:
		cat.assigned_customer_id = -1


func _on_cat_drag_ended(_cat_id: int) -> void:
	save_now()
