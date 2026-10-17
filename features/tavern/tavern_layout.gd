extends RefCounted
class_name TavernLayout

const SIZE: Vector2 = Vector2(960.0, 280.0)
const GROUND: float = 270.0
const SHOP_SIZE: Vector2 = Vector2(206.0, 146.0)
const MAX_FURNITURE: int = 16

var objects: Dictionary = {}
var homes: Dictionary = {}
var next_id: int = 10


func _init() -> void:
	reset()


func reset() -> void:
	objects = {"shop": {"kind": "shop", "position": Vector2(520.0, GROUND)}}
	for index: int in range(4):
		objects["chair_%d" % index] = {"kind": "chair", "position": Vector2([145.0, 270.0, 755.0, 880.0][index], GROUND), "occupant": "", "dirty": false, "cup": "none"}
	objects["table_0"] = {"kind": "table", "position": Vector2(206.0, GROUND)}
	objects["table_1"] = {"kind": "table", "position": Vector2(817.0, GROUND)}
	homes = {"manager": Vector2(378.0, GROUND), "bartender": Vector2(520.0, GROUND), "server": Vector2(650.0, GROUND)}
	next_id = 10


func clamp_position(point: Vector2, kind: String = "person") -> Vector2:
	var margin: float = 52.0 if kind != "shop" else SHOP_SIZE.x * 0.5 + 4.0
	return Vector2(clampf(point.x, margin, SIZE.x - margin), GROUND)


func place_position(point: Vector2, kind: String = "person") -> Vector2:
	return clamp_position(point, kind)


func shop_position() -> Vector2:
	return objects["shop"]["position"] as Vector2


func pickup_position() -> Vector2:
	return clamp_position(shop_position() + Vector2(88.0, 0.0))


func chair_ids() -> Array[String]:
	var result: Array[String] = []
	for key: String in objects:
		if objects[key]["kind"] == "chair":
			result.append(key)
	return result


func nearest_free_chair(point: Vector2, excluded_id: String = "") -> String:
	var result: String = ""
	var distance: float = INF
	for key: String in chair_ids():
		if key == excluded_id:
			continue
		var item: Dictionary = objects[key]
		if str(item.get("occupant", "")) != "" or bool(item.get("dirty", false)):
			continue
		var current_distance: float = point.distance_squared_to(item["position"] as Vector2)
		if current_distance < distance:
			result = key
			distance = current_distance
	return result


func cup_position(chair_id: String) -> Vector2:
	if not objects.has(chair_id):
		return Vector2.ZERO
	var chair_position: Vector2 = objects[chair_id]["position"] as Vector2
	var closest: Vector2 = chair_position + Vector2(2.0, -27.0)
	var distance: float = 90.0
	for key: String in objects:
		if objects[key]["kind"] == "table":
			var point: Vector2 = objects[key]["position"] as Vector2
			var current: float = point.distance_to(chair_position)
			if current < distance:
				distance = current
				closest = point + Vector2(-12.0 if chair_position.x < point.x else 12.0, -34.0)
	return closest


func add_furniture(kind: String) -> String:
	if kind not in ["chair", "table"] or objects.size() >= MAX_FURNITURE:
		return ""
	var key: String = "%s_%d" % [kind, next_id]
	next_id += 1
	objects[key] = {"kind": kind, "position": Vector2(80.0 + float((next_id * 73) % 800), GROUND), "occupant": "", "dirty": false, "cup": "none"}
	return key


func to_data() -> Dictionary:
	return {"objects": objects.duplicate(true), "homes": homes.duplicate(true), "next_id": next_id}


func restore(data: Dictionary) -> void:
	reset()
	var source: Variant = data.get("objects")
	if source is Dictionary:
		var cleaned: Dictionary = {}
		for raw_key: Variant in source:
			if cleaned.size() >= MAX_FURNITURE:
				break
			var key: String = str(raw_key)
			var item_value: Variant = source[raw_key]
			if not item_value is Dictionary:
				continue
			var item: Dictionary = item_value as Dictionary
			var kind: String = str(item.get("kind", ""))
			if kind not in ["chair", "table", "shop"] or (kind == "shop" and key != "shop"):
				continue
			if kind != "shop" and not key.begins_with(kind + "_"):
				continue
			cleaned[key] = {"kind": kind, "position": clamp_position(TavernPerson.safe_vector(item.get("position"), Vector2(480.0, GROUND)), kind),
				"occupant": str(item.get("occupant", "")), "dirty": bool(item.get("dirty", false)), "cup": str(item.get("cup", "none")) if str(item.get("cup", "none")) in ["none", "full", "empty"] else "none", "order": TavernData.integer(item.get("order", 0))}
		if not cleaned.has("shop"):
			cleaned["shop"] = objects["shop"]
		objects = cleaned
	var saved_homes: Variant = data.get("homes")
	if saved_homes is Dictionary:
		for key: String in CastCatalog.STAFF_IDS:
			homes[key] = clamp_position(TavernPerson.safe_vector(saved_homes.get(key), homes[key] as Vector2))
	homes["bartender"] = shop_position()
	next_id = TavernData.integer(data.get("next_id", 10), 10, 10, 2000000000)
	while objects.has("chair_%d" % next_id) or objects.has("table_%d" % next_id):
		next_id += 1
