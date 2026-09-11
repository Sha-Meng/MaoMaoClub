extends RefCounted
class_name CatBarSettlementService

signal order_settled(order_id: int, rewards: Dictionary)

var _economy: EconomyState
var _progression: CatBarProgressionState
var _settled_keys: Dictionary[StringName, bool] = {}


func setup(economy: EconomyState, progression: CatBarProgressionState) -> void:
	_economy = economy
	_progression = progression


func settle_delivery(
	order: CatBarServiceOrder,
	session: BartendingSessionState,
	delivery_key: StringName,
	result: DrinkResult
) -> Dictionary:
	if _economy == null or _progression == null or order == null or session == null or result == null:
		return {"success": false, "reason": "结算依赖未初始化"}
	if not result.valid or order.settled or _settled_keys.has(delivery_key):
		return {"success": false, "reason": "订单已结算或成品无效"}
	if order.order_id != session.order_id or order.session_id != session.session_id or order.booth_id != session.booth_id:
		return {"success": false, "reason": "订单、会话或卡座不匹配"}
	if not session.mark_delivered(delivery_key):
		return {"success": false, "reason": "会话拒绝送达"}
	_settled_keys[delivery_key] = true
	order.settled = true
	var quality_factor := lerpf(0.65, 1.25, float(result.quality) / 100.0)
	var coins := maxi(1, roundi(float(order.base_coins) * quality_factor * _progression.reward_multiplier()))
	var xp := maxi(1, order.base_business_xp + (1 if result.quality >= 90 else 0))
	_economy.award_service_reward(coins, xp)
	_progression.award_delivery(result)
	var rewards := {
		"success": true,
		"coins": coins,
		"business_xp": xp,
		"material_id": &"catnip_leaf",
		"material_count": 1,
		"quality": result.quality,
		"tags": result.tags.duplicate(),
		"differences": result.differences.duplicate(),
	}
	order_settled.emit(order.order_id, rewards.duplicate(true))
	return rewards

