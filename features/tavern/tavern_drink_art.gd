extends RefCounted
class_name TavernDrinkArt

const SHEETS: Array[Texture2D] = [preload("res://assets/tavern/drinks_first_v2.png"), preload("res://assets/tavern/drinks_extra_v2.png")]
const DURATION: float = 1.35

var frames: Dictionary = {}


func _init(seated_heights: Dictionary) -> void:
	for id: String in CastCatalog.CUSTOMER_IDS:
		var profile: Dictionary = CastCatalog.profile(id)
		var sheet_index: int = int(profile["sheet"])
		var row: int = int(profile["row"])
		var texture: Texture2D = SHEETS[sheet_index]
		var image_size: Vector2i = texture.get_size()
		var bitmap: BitMap = BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image(), 0.15)
		var fractions: PackedFloat32Array = PackedFloat32Array([0.0, 0.335, 0.687, 1.0] if sheet_index == 0 else [0.0, 0.35, 0.69, 1.0])
		var poses: Array[Dictionary] = []
		var factor: float = 1.0
		for column: int in range(6):
			var x0: int = roundi(float(column) * image_size.x / 6.0)
			var x1: int = roundi(float(column + 1) * image_size.x / 6.0)
			var y0: int = maxi(0, roundi(fractions[row] * image_size.y) - 8)
			var y1: int = mini(image_size.y, roundi(fractions[row + 1] * image_size.y) + 8)
			var cell: Rect2i = Rect2i(x0, y0, x1 - x0, y1 - y0)
			var contour: PackedVector2Array = PackedVector2Array()
			var largest: float = 0.0
			for candidate: PackedVector2Array in bitmap.opaque_to_polygons(cell, 1.0):
				var area: float = 0.0
				for index: int in range(candidate.size()):
					area += candidate[index].cross(candidate[(index + 1) % candidate.size()])
				if absf(area) > largest:
					largest = absf(area)
					contour = candidate
			var bounds: Rect2 = Rect2()
			for index: int in range(contour.size()):
				contour[index] += Vector2(cell.position)
				bounds = Rect2(contour[index], Vector2.ZERO) if index == 0 else bounds.expand(contour[index])
			var foot_min: float = INF
			var foot_max: float = -INF
			for point: Vector2 in contour:
				if point.y >= bounds.end.y - bounds.size.y * 0.04:
					foot_min = minf(foot_min, point.x)
					foot_max = maxf(foot_max, point.x)
			var origin: Vector2 = Vector2((foot_min + foot_max) * 0.5, bounds.end.y)
			if column == 0:
				factor = float(seated_heights[id]) / maxf(1.0, bounds.size.y)
			var points: PackedVector2Array = PackedVector2Array()
			var uvs: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in contour:
				points.append((point - origin) * factor)
				uvs.append(point / Vector2(image_size))
			poses.append({"points": points, "uvs": uvs, "bounds": Rect2((bounds.position - origin) * factor, bounds.size * factor), "source_bounds": bounds})
		frames[id] = poses


func supports(person: TavernPerson) -> bool:
	return person.action == "drink" and CastCatalog.is_customer(person.profile_id)


func frame_for(person: TavernPerson) -> int:
	return clampi(int(person.action_time / DURATION * 6.0), 0, 5)


func draw_on(canvas: CanvasItem, person: TavernPerson) -> void:
	var frame: Dictionary = frames[person.profile_id][frame_for(person)]
	canvas.draw_polygon(frame["points"] as PackedVector2Array, PackedColorArray([Color.WHITE]), frame["uvs"] as PackedVector2Array, SHEETS[int(CastCatalog.profile(person.profile_id)["sheet"])])


func bounds_for(person: TavernPerson) -> Rect2:
	var bounds: Rect2 = frames[person.profile_id][frame_for(person)]["bounds"] as Rect2
	if person.facing < 0.0:
		bounds.position.x = -bounds.end.x
	return bounds
