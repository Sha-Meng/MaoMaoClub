extends RefCounted
class_name TavernWalkArt

const SHEETS: Dictionary = {
	"customer_squirrel": preload("res://assets/tavern/walk_complete/customer_squirrel.png"),
	"customer_dog": preload("res://assets/tavern/walk_complete/customer_dog.png"),
	"customer_capybara": preload("res://assets/tavern/walk_complete/customer_capybara.png"),
	"customer_fox": preload("res://assets/tavern/walk_complete/customer_fox.png"),
	"customer_rabbit": preload("res://assets/tavern/walk_complete/customer_rabbit.png"),
	"customer_raccoon": preload("res://assets/tavern/walk_complete/customer_raccoon.png"),
	"manager": preload("res://assets/tavern/walk_complete/manager.png"),
	"bartender": preload("res://assets/tavern/walk_complete/bartender.png"),
	"server": preload("res://assets/tavern/walk_complete/server.png"),
	"server_carry": preload("res://assets/tavern/walk_complete/server_carry.png")}
const WALK_FRAMES: int = 8
const IDLE_FRAME: int = 8
const GREET_FRAME: int = 9
# Historical bake-tool parameters; runtime walking uses the grounded portrait.
const SMOOTH_FRAMES: int = 32
const SMOOTH_CELL: Vector2 = Vector2(320.0, 240.0)
const SMOOTH_ORIGIN: Vector2 = Vector2(160.0, 224.0)
const SMOOTH_SCALE: float = 2.0
const SMOOTH_FOLDER: String = "res://assets/tavern/walk_smooth/"

static var _catalog: Dictionary = {}
static var _base_textures: Dictionary = {}
var frames: Dictionary = {}
var gait: TavernGroundedGait = TavernGroundedGait.new()


func _init() -> void:
	if _catalog.is_empty():
		for key: String in SHEETS:
			_catalog[key] = _register_sheet(key)
	frames = _catalog
	if _base_textures.is_empty():
		for key: String in SHEETS:
			var path: String = "res://assets/tavern/grounded/" + key + ".png"
			if ResourceLoader.exists(path):
				_base_textures[key] = load(path) as Texture2D


func _register_sheet(key: String) -> Array[Dictionary]:
	var texture: Texture2D = SHEETS[key] as Texture2D
	var image: Image = texture.get_image()
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, 0.15)
	# Find complete connected figures before assigning cells. Several painted tails
	# and hands extend into a nominal gutter; cutting at that grid would amputate them.
	var candidates: Array[Dictionary] = []
	for polygon: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.0):
		var area: float = _area(polygon)
		if area < image.get_width() * image.get_height() * 0.004:
			continue
		var bounds: Rect2 = Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon:
			bounds = bounds.expand(point)
		candidates.append({"points": polygon, "bounds": bounds, "used": false})
	var poses: Array[Dictionary] = []
	for index: int in range(10):
		var column: int = index % 5
		var row: int = index / 5
		var x0: int = roundi(float(column) * image.get_width() / 5.0)
		var x1: int = roundi(float(column + 1) * image.get_width() / 5.0)
		var y0: int = roundi(float(row) * image.get_height() / 2.0)
		var y1: int = roundi(float(row + 1) * image.get_height() / 2.0)
		var cell: Rect2i = Rect2i(x0, y0, x1 - x0, y1 - y0)
		var selected: Dictionary = {}
		var nearest: float = INF
		for candidate: Dictionary in candidates:
			if bool(candidate["used"]):
				continue
			var distance: float = (candidate["bounds"] as Rect2).get_center().distance_squared_to(Rect2(cell).get_center())
			if distance < nearest:
				nearest = distance
				selected = candidate
		if selected.is_empty():
			push_error("走路图集缺少完整人物: %s/%d" % [key,index])
			return []
		selected["used"] = true
		var contour: PackedVector2Array = selected["points"] as PackedVector2Array
		var bounds: Rect2 = selected["bounds"] as Rect2
		var origin: Vector2 = Vector2(_head_center(image, bounds), bounds.end.y)
		poses.append({"source_points": contour, "source_bounds": bounds, "image_bounds": Rect2(Vector2.ZERO, image.get_size()), "origin": origin, "sheet_components": candidates.size()})
	var id: String = "server" if key == "server_carry" else key
	var factor: float = float(CastCatalog.profile(id)["height"]) / maxf(1.0, (poses[IDLE_FRAME]["source_bounds"] as Rect2).size.y)
	for pose: Dictionary in poses:
		var bounds: Rect2 = pose["source_bounds"] as Rect2
		# Normalize whole-figure height, never individual arms/legs. Original sheets
		# vary in painting scale between rows; otherwise the head jumps at 4 -> 5.
		var pose_factor: float = float(CastCatalog.profile(id)["height"]) / bounds.size.y
		var origin: Vector2 = pose["origin"] as Vector2
		var points: PackedVector2Array = PackedVector2Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in pose["source_points"]:
			points.append((point - origin) * pose_factor)
			uvs.append(point / texture.get_size())
		pose["points"] = points
		pose["uvs"] = uvs
		pose["bounds"] = Rect2((bounds.position - origin) * pose_factor, bounds.size * pose_factor)
		pose["factor"] = pose_factor
		pose["original_factor"] = factor
	return poses


func _head_center(image: Image, bounds: Rect2) -> float:
	# Register by the head, not the changing span between the two feet.
	# This prevents horizontal body jitter when a foot passes or extends.
	var y: int = clampi(roundi(bounds.position.y + bounds.size.y * 0.24), 0, image.get_height() - 1)
	var start: int = -1
	var widest: int = 0
	var center: float = bounds.get_center().x
	for x: int in range(maxi(0, int(bounds.position.x)), mini(image.get_width(), ceili(bounds.end.x) + 1)):
		if image.get_pixel(x, y).a > 0.4:
			if start < 0:
				start = x
		elif start >= 0:
			if x - start > widest:
				widest = x - start
				center = (start + x) * 0.5
			start = -1
	if start >= 0 and ceili(bounds.end.x) - start > widest:
		center = (start + bounds.end.x) * 0.5
	return center - bounds.size.y * 0.035


func _area(points: PackedVector2Array) -> float:
	var value: float = 0.0
	for index: int in range(points.size()):
		value += points[index].cross(points[(index + 1) % points.size()])
	return absf(value) * 0.5


func supports(person: TavernPerson) -> bool:
	if person.profile_id == "manager":
		return true
	if person.dragging:
		return true
	if person.action in ["walk", "carry_tray", "hold_tray", "idle_stand", "drag_hold", "land"]:
		return true
	if CastCatalog.is_customer(person.profile_id):
		return person.state in ["entering", "leaving", "reseating"]
	return person.profile_id == "server" and person.action in ["idle", "apron"]


func key_for(person: TavernPerson) -> String:
	return "server_carry" if person.profile_id == "server" and person.carrying else person.profile_id


func frame_for(person: TavernPerson) -> int:
	# Standing and walking share the same portrait, including the squirrel.
	return IDLE_FRAME


func pose_for(person: TavernPerson) -> Dictionary:
	return frames[key_for(person)][frame_for(person)]


func draw_on(canvas: CanvasItem, person: TavernPerson) -> void:
	var key: String = key_for(person)
	if _base_textures.has(key):
		gait.draw_on(canvas, person, _base_textures[key] as Texture2D, frames[key][IDLE_FRAME].bounds)
		return
	var pose: Dictionary = pose_for(person)
	# One complete character, sampled without limb scaling, mesh folds or stitched caps.
	canvas.draw_polygon(pose["points"] as PackedVector2Array, PackedColorArray([Color.WHITE]), pose["uvs"] as PackedVector2Array, SHEETS[key_for(person)] as Texture2D)


func smooth_frame_for(person: TavernPerson) -> int:
	return floori(fposmod(person.walk_phase, 1.0) * SMOOTH_FRAMES)


func bounds_for(person: TavernPerson) -> Rect2:
	var bounds: Rect2 = pose_for(person)["bounds"] as Rect2
	bounds.position.x -= person.stride_length() * 0.3
	bounds.size.x += person.stride_length() * 0.6
	if person.facing < 0.0:
		bounds.position.x = -bounds.end.x
	return bounds
