extends RefCounted
class_name CatBarServiceOrder

var order_id: int = 0
var session_id: StringName = &""
var booth_id: StringName = &""
var recipe_id: StringName = &""
var base_coins: int = 10
var base_business_xp: int = 2
var settled: bool = false


func _init(
	p_order_id: int = 0,
	p_session_id: StringName = &"",
	p_booth_id: StringName = &"",
	p_recipe_id: StringName = &"moonlit_meow"
) -> void:
	order_id = p_order_id
	session_id = p_session_id
	booth_id = p_booth_id
	recipe_id = p_recipe_id

