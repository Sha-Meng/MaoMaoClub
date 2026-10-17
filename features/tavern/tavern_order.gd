extends RefCounted
class_name TavernOrder

var id: int = 0
var customer_id: String = ""
var phase: String = "queued"
var elapsed: float = 0.0
var delivered: bool = false
var paid: bool = false
var coins: int = 8
var xp: int = 1


func change_phase(value: String) -> void:
	phase = value
	elapsed = 0.0


func to_data() -> Dictionary:
	return {"id": id, "customer": customer_id, "phase": phase, "elapsed": elapsed,
		"delivered": delivered, "paid": paid, "coins": coins, "xp": xp}


static func from_data(data: Dictionary) -> TavernOrder:
	var order: TavernOrder = TavernOrder.new()
	order.id = TavernData.integer(data.get("id", 0), 0, 0, 2000000000)
	order.customer_id = str(data.get("customer", ""))
	order.phase = str(data.get("phase", "queued"))
	order.elapsed = TavernData.number(data.get("elapsed", 0.0))
	order.delivered = bool(data.get("delivered", false))
	order.paid = bool(data.get("paid", false))
	order.coins = TavernData.integer(data.get("coins", 8), 8, 5, 12)
	order.xp = 1
	return order
