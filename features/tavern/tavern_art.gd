extends RefCounted
class_name TavernArt

const SHEETS: Array[Texture2D] = [preload("res://assets/tavern/customers_first.png"), preload("res://assets/tavern/customers_extra.png"), preload("res://assets/tavern/cat_team.png")]
const SHOP: Texture2D = preload("res://assets/tavern/shop.png")
const SUPPORTED_ACTIONS: Array[String] = ["idle", "idle_work", "idle_stand", "idle_sit", "walk", "sit_down", "drink", "chat", "listen", "stand_up", "drag_hold", "land", "pay", "mix_drink", "pour_drink", "place_drink", "take_tray", "carry_tray", "hold_tray", "serve_drink", "collect_glass", "react_click", "story", "loosen_tie", "slow_nod", "quip", "sketch", "phone", "greet", "align_glass", "apron", "order", "receive_drink", "wipe_glass", "wipe_counter", "pickup_bottle", "toast", "adjust_chain", "laugh", "show_sketch", "wipe_table"]

var frames: Dictionary = {}
var source_heights: Dictionary = {}
var polygons: Dictionary = {}
var texture_uvs: Dictionary = {}
var pivots: Dictionary = {}
var walk_animation: TavernWalkArt = TavernWalkArt.new()
var drinks: TavernDrinkArt


func _init() -> void:
	for profile_id: String in CastCatalog.all_ids():
		var profile: Dictionary = CastCatalog.profile(profile_id)
		var sheet_index: int = int(profile["sheet"])
		var row: int = int(profile["row"])
		var texture: Texture2D = SHEETS[sheet_index]
		var source_image: Image = texture.get_image()
		var image_size: Vector2i = source_image.get_size()
		# These row divisions follow the supplied art, avoiding clipping the manager's feet.
		var row_fractions: PackedFloat32Array = PackedFloat32Array([0.0, 0.335, 0.692, 1.0] if sheet_index == 0 else ([0.0, 0.345, 0.687, 1.0] if sheet_index == 1 else [0.0, 0.344, 0.688, 1.0]))
		var regions: Array[Rect2] = []
		var row_polygons: Array[PackedVector2Array] = []
		var row_uvs: Array[PackedVector2Array] = []
		var row_pivots: Array[Vector2] = []
		var bitmap: BitMap = BitMap.new()
		bitmap.create_from_image_alpha(source_image, 0.12)
		for column: int in range(6):
			var x0: int = roundi(float(column) * image_size.x / 6.0)
			var x1: int = roundi(float(column + 1) * image_size.x / 6.0)
			var y0: int = roundi(row_fractions[row] * image_size.y)
			var y1: int = roundi(row_fractions[row + 1] * image_size.y)
			var cell: Rect2i = Rect2i(x0, y0, x1 - x0, y1 - y0)
			var contours: Array[PackedVector2Array] = bitmap.opaque_to_polygons(cell, 1.0)
			var largest: PackedVector2Array = PackedVector2Array()
			var largest_area: float = 0.0
			for contour: PackedVector2Array in contours:
				var area: float = _polygon_area(contour)
				if area > largest_area:
					largest_area = area
					largest = contour
			var source_polygon: PackedVector2Array = PackedVector2Array()
			var uvs: PackedVector2Array = PackedVector2Array()
			var bounds: Rect2 = Rect2(Vector2(cell.position), Vector2.ZERO)
			for point: Vector2 in largest:
				var source_point: Vector2 = point + Vector2(cell.position)
				if source_polygon.is_empty():
					bounds.position = source_point
				else:
					bounds = bounds.expand(source_point)
				source_polygon.append(source_point)
				uvs.append(source_point / Vector2(image_size))
			var foot_min: float = INF
			var foot_max: float = -INF
			for point: Vector2 in source_polygon:
				if point.y >= bounds.end.y - bounds.size.y * 0.045:
					foot_min = minf(foot_min, point.x)
					foot_max = maxf(foot_max, point.x)
			row_pivots.append(Vector2((foot_min + foot_max) * 0.5, bounds.end.y))
			row_polygons.append(source_polygon)
			row_uvs.append(uvs)
			regions.append(bounds)
		frames[profile_id] = regions
		polygons[profile_id] = row_polygons
		texture_uvs[profile_id] = row_uvs
		pivots[profile_id] = row_pivots
		source_heights[profile_id] = maxf(1.0, regions[0].size.y)
	var seated_heights: Dictionary = {}
	for id: String in CastCatalog.CUSTOMER_IDS:
		seated_heights[id] = (frames[id][3] as Rect2).size.y * float(CastCatalog.profile(id)["height"]) / float(source_heights[id])
	drinks = TavernDrinkArt.new(seated_heights)


func _polygon_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for index: int in range(points.size()):
		var next: Vector2 = points[(index + 1) % points.size()]
		area += points[index].x * next.y - next.x * points[index].y
	return absf(area) * 0.5


func body_polygon(person: TavernPerson) -> PackedVector2Array:
	var pose: int = pose_for(person)
	var points: PackedVector2Array = polygons[person.profile_id][pose] as PackedVector2Array
	var origin: Vector2 = pivots[person.profile_id][pose] as Vector2
	var factor: float = float(CastCatalog.profile(person.profile_id)["height"]) / float(source_heights[person.profile_id])
	var result: PackedVector2Array = PackedVector2Array()
	var settling: bool = person.action in ["sit_down", "stand_up"] and CastCatalog.is_customer(person.profile_id)
	for point: Vector2 in points:
		var local: Vector2 = (point - origin) * factor
		result.append(posture_point(person, local) if settling else local)
	return result


func posture_point(person: TavernPerson, point: Vector2) -> Vector2:
	if not CastCatalog.is_customer(person.profile_id) or person.action not in ["sit_down", "stand_up"]:
		return point
	# Only the upper body settles around the seated pelvis; pelvis and feet never slide.
	var pelvis: Vector2 = Vector2(0.0, -27.0)
	var height: float = float(CastCatalog.profile(person.profile_id)["height"])
	var weight: float = smoothstep(0.0, 1.0, (pelvis.y - point.y) / (height * 0.38))
	var progress: float = smoothstep(0.0, 1.0, person.state_time / (0.55 if person.action == "sit_down" else 0.5))
	var angle: float = -0.035 * (1.0 - progress) if person.action == "sit_down" else -0.045 * progress
	return point.lerp(pelvis + (point - pelvis).rotated(angle), weight)


func body_bounds(person: TavernPerson) -> Rect2:
	if walk_animation.supports(person):
		return walk_animation.bounds_for(person)
	if drinks.supports(person):
		return drinks.bounds_for(person)
	var source: Rect2 = region_for(person)
	var origin: Vector2 = pivots[person.profile_id][pose_for(person)] as Vector2
	var factor: float = float(CastCatalog.profile(person.profile_id)["height"]) / float(source_heights[person.profile_id])
	var offset: Vector2 = (source.position - origin) * factor
	var dimensions: Vector2 = source.size * factor
	if person.facing < 0.0:
		offset.x = -offset.x - dimensions.x
	return Rect2(offset, dimensions)


func uvs_for_body(person: TavernPerson, polygon: PackedVector2Array) -> PackedVector2Array:
	var origin: Vector2 = pivots[person.profile_id][pose_for(person)] as Vector2
	var factor: float = float(CastCatalog.profile(person.profile_id)["height"]) / float(source_heights[person.profile_id])
	var source_size: Vector2 = texture_for(person.profile_id).get_size()
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		result.append((point / factor + origin) / source_size)
	return result


func pose_for(person: TavernPerson) -> int:
	var seated: bool = CastCatalog.is_customer(person.profile_id) and person.state in ["waiting", "drinking", "paying", "seating", "standing"]
	match person.action:
		"walk": return 0
		"carry_tray", "hold_tray": return 0
		"mix_drink": return 3
		"pour_drink": return 4
		"place_drink", "serve_drink", "collect_glass": return 5
		"take_tray": return 3
		"drink": return 4 if person.action_time > 0.15 and person.action_time < 1.2 else 3
		"chat", "story", "quip": return 3 if person.id == "manager" else 5
		"listen": return 4 if person.id == "manager" else 3
		"react_click", "greet", "toast": return 5 if person.id == "manager" else 0
		"idle_sit", "sit_down", "stand_up", "pay", "loosen_tie", "slow_nod", "sketch": return 3
		"phone": return 5 if person.action_time > 0.9 else 3
		"drag_hold": return 0
		"align_glass": return 5
		"apron": return 0
		"order", "receive_drink", "show_sketch": return 5
		"wipe_glass", "pickup_bottle": return 3
		"wipe_counter", "wipe_table": return 5
		"adjust_chain": return 4
		"laugh": return 3
	return 3 if seated else 0


func is_walking(person: TavernPerson) -> bool:
	return person.walking and person.action in ["walk", "carry_tray"] and not person.dragging


func uses_walk_animation(person: TavernPerson) -> bool:
	return walk_animation.supports(person)


func region_for(person: TavernPerson) -> Rect2:
	var regions: Array = frames[person.profile_id]
	return regions[pose_for(person)] as Rect2


func texture_for(profile_id: String) -> Texture2D:
	return SHEETS[int(CastCatalog.profile(profile_id)["sheet"])]


func draw_size(person: TavernPerson) -> Vector2:
	var region: Rect2 = region_for(person)
	return region.size * float(CastCatalog.profile(person.profile_id)["height"]) / float(source_heights[person.profile_id])
