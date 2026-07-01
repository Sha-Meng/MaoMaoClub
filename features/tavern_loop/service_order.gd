extends RefCounted
class_name ServiceOrder

var order_id: int
var customer_id: int
var cat_id: int
var elapsed_seconds: float
var duration_seconds: float
var coin_reward: int
var business_xp_reward: int

func _init(
		p_order_id: int = 0,
		p_customer_id: int = 0,
		p_cat_id: int = 0,
		p_duration_seconds: float = 4.0,
		p_coin_reward: int = 5,
		p_business_xp_reward: int = 1
) -> void:
	order_id = p_order_id
	customer_id = p_customer_id
	cat_id = p_cat_id
	duration_seconds = p_duration_seconds
	coin_reward = p_coin_reward
	business_xp_reward = p_business_xp_reward
	elapsed_seconds = 0.0


func advance(delta: float) -> bool:
	elapsed_seconds += delta
	return elapsed_seconds >= duration_seconds
