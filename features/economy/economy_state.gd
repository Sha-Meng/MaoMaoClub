extends Node
class_name EconomyState

signal coins_changed(new_value: int)
signal business_xp_changed(new_value: int)
signal customer_served(total_served: int)

var coins: int = 0
var business_xp: int = 0
var served_customers_total: int = 0

func restore(save_data: Dictionary) -> void:
	coins = int(save_data.get("coins", 0))
	business_xp = int(save_data.get("business_xp", 0))
	served_customers_total = int(save_data.get("served_customers_total", 0))
	coins_changed.emit(coins)
	business_xp_changed.emit(business_xp)
	customer_served.emit(served_customers_total)


func award_service_reward(coin_amount: int, xp_amount: int) -> void:
	coins += max(0, coin_amount)
	business_xp += max(0, xp_amount)
	served_customers_total += 1
	coins_changed.emit(coins)
	business_xp_changed.emit(business_xp)
	customer_served.emit(served_customers_total)


func to_save_data() -> Dictionary:
	return {
		"coins": coins,
		"business_xp": business_xp,
		"served_customers_total": served_customers_total
	}
