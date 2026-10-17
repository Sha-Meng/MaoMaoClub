extends RefCounted
class_name TavernGroundedGait

# Logical coordinates measured on the complete neutral portraits, never on
# independently scaled limbs. hip_y, foot_top, split_x, outside_left/right.
const ANATOMY: Dictionary = {
	"customer_squirrel": [-25.0, -6.0, 0.0, -12.0, 17.0],
	"customer_dog": [-41.0, -8.0, 5.0, -13.0, 30.0],
	"customer_capybara": [-26.0, -8.0, 0.0, -25.0, 28.0],
	"customer_fox": [-40.0, -8.0, 4.0, -15.0, 27.0],
	"customer_rabbit": [-22.0, -7.0, 6.5, -13.0, 29.0],
	"customer_raccoon": [-27.0, -7.0, 3.0, -15.0, 25.0],
	"manager": [-24.0, -7.0, 4.0, -18.0, 30.0],
	"bartender": [-31.0, -8.0, 4.0, -18.0, 28.0],
	"server": [-22.0, -6.0, 2.0, -17.0, 25.0]}
# The neutral portraits have a slightly raised far sole. Register that sole to
# the same ground once, in both standing and walking, without scaling the foot.
const SOLE_DROP: Dictionary = {"customer_squirrel": 1.0, "customer_dog": 0.0, "customer_capybara": 0.5, "customer_fox": 1.0, "customer_rabbit": 1.0, "customer_raccoon": 0.5, "manager": 0.5, "bartender": 0.5, "server": 0.5}
const ARMS: Dictionary = {
	"customer_squirrel": [Rect2(-12,-49,8,24), Rect2(10,-46,8,23)],
	"customer_dog": [Rect2(-14,-65,10,34), Rect2(21,-64,11,33)],
	"customer_capybara": [Rect2(-29,-51,15,31), Rect2(23,-48,12,29)],
	"customer_fox": [Rect2(-14,-65,10,35), Rect2(17,-62,9,32)],
	"customer_rabbit": [Rect2(-14,-46,13,25), Rect2(18,-43,9,23)],
	"customer_raccoon": [Rect2(-16,-47,12,28), Rect2(17,-44,9,25)],
	"manager": [Rect2(), Rect2(24,-47,9,25)],
	"bartender": [Rect2(-19,-64,12,36), Rect2(19,-63,12,35)],
	"server": [Rect2(-17,-44,12,25), Rect2(17,-42,10,24)]}
# In the reviewed three-quarter portraits, source-left (0) is the camera-near
# leg. Source-right (1) is the far leg, irrespective of gait phase or mirroring.
# Keep this explicit per portrait so future art cannot inherit screen-X order.
const NEAR_LEG: Dictionary = {
	"customer_squirrel": 0, "customer_dog": 0, "customer_capybara": 0,
	"customer_fox": 0, "customer_rabbit": 0, "customer_raccoon": 0,
	"manager": 0, "bartender": 0, "server": 0, "server_carry": 0}

var _grids: Dictionary = {}
var _meshes: Dictionary = {}
var _cache_frame: int = -1

static func stride_for(id: String) -> float:
	return float(TavernWalkPose.STRIDES[id])

static func speed_for(id: String) -> float:
	return float(TavernWalkPose.SPEEDS[id])

static func is_supporting(person: TavernPerson, side: int) -> bool:
	return TavernWalkPose.phase_for(person,side) < TavernWalkPose.STANCE

static func foot_offset(person: TavernPerson, side: int) -> Vector2:
	return TavernWalkPose.foot_offset(person,side)

func _weights(point: Vector2, person: TavernPerson) -> Vector4:
	var data: Array = ANATOMY[person.profile_id]
	var leg: float = 1.0 if point.y >= float(data[0])-6.0 else 0.0
	var outside: float = smoothstep(float(data[3])-4.0, float(data[3]), point.x) * (1.0-smoothstep(float(data[4]), float(data[4])+4.0, point.x))
	var right: float = 1.0 if point.x >= float(data[2]) else 0.0
	var arm: Vector2 = Vector2.ZERO
	if not person.carrying:
		for side: int in range(2):
			var region: Rect2 = ARMS[person.profile_id][side]
			if not region.has_area():
				continue
			var horizontal: float = smoothstep(region.position.x-3.0, region.position.x+2.0, point.x) * (1.0-smoothstep(region.end.x-2.0, region.end.x+3.0, point.x))
			var vertical: float = smoothstep(region.position.y, region.end.y-5.0, point.y) * (1.0-smoothstep(region.end.y, region.end.y+4.0, point.y))
			arm[side] = horizontal * vertical
	# A hand hanging over the hip belongs to the arm, not to the trouser/leg warp.
	leg *= 1.0-clampf(arm.x+arm.y,0.0,1.0)
	return Vector4(leg * outside * (1.0-right), leg * outside * right, arm.x, arm.y)

func displacement(point: Vector2, person: TavernPerson) -> Vector2:
	var pose: Dictionary = TavernWalkPose.evaluate(person)
	var side: int = 0 if point.x < float(ANATOMY[person.profile_id][2]) else 1
	var transform: Transform2D = TavernWalkPose.row_transform(point.y,pose.legs[side],pose.body)
	return _map_point(point,_weights(point,person),transform,pose.body,_arm_transforms(person,pose.body))-point

func _map_point(point: Vector2, weight: Vector4, leg: Transform2D, body: Vector2, arms: Array[Transform2D]) -> Vector2:
	var result: Vector2 = (point+body).lerp(leg*point,weight.x+weight.y)
	result += (arms[0]*point-point-body)*weight.z+(arms[1]*point-point-body)*weight.w
	return result

func _arm_transforms(person: TavernPerson, body: Vector2) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for side: int in range(2):
		var region: Rect2 = ARMS[person.profile_id][side]
		var shoulder: Vector2 = Vector2(region.get_center().x,region.position.y)
		var travel: float = foot_offset(person,side).x-TavernWalkPose.track_shift(person,side)
		var angle: float = travel/person.stride_length()*0.7*person.gait_lift
		var transform: Transform2D = Transform2D(angle,Vector2.ZERO)
		transform.origin = shoulder+body-transform.basis_xform(shoulder)
		result.append(transform)
	return result

func draw_on(canvas: CanvasItem, person: TavernPerson, texture: Texture2D, bounds: Rect2) -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _cache_frame:
		_cache_frame = frame
		# Keep all meshes referenced by this frame's queued canvas commands alive,
		# including galleries which create temporary people inside _draw().
		for old: int in _meshes.keys():
			if not is_instance_id_valid(old):
				_meshes.erase(old)
	var key: String = "server_carry" if person.profile_id == "server" and person.carrying else person.profile_id
	if not _grids.has(key):
		_grids[key] = _make_grid(person, bounds)
	var grid: Dictionary = _grids[key]
	var positions: PackedVector2Array = PackedVector2Array()
	var weights: PackedVector4Array = grid.weights
	var source: PackedVector2Array = grid.points
	var pose: Dictionary = TavernWalkPose.evaluate(person)
	var arms: Array[Transform2D] = _arm_transforms(person,pose.body)
	var row_transforms: Dictionary = {}
	for index: int in range(source.size()):
		var weight: Vector4 = weights[index]
		var side: int = grid.sides[index]
		var row_key: Vector2 = Vector2(side,source[index].y)
		if not row_transforms.has(row_key):
			row_transforms[row_key] = TavernWalkPose.row_transform(source[index].y,pose.legs[side],pose.body)
		positions.append(_map_point(source[index],weight,row_transforms[row_key],pose.body,arms))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = grid.uvs
	arrays[Mesh.ARRAY_INDEX] = grid.indices
	var identity: int = person.get_instance_id()
	if not _meshes.has(identity):
		_meshes[identity] = ArrayMesh.new()
	var mesh: ArrayMesh = _meshes[identity]
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	canvas.draw_mesh(mesh, texture)

func _make_grid(person: TavernPerson, bounds: Rect2) -> Dictionary:
	var rect: Rect2 = bounds.grow(1.0)
	var rows: int = ceili(rect.size.y / 2.0)
	var points: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var weights: PackedVector4Array = PackedVector4Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var sides: PackedInt32Array = PackedInt32Array()
	var split: float = float(ANATOMY[person.profile_id][2])
	# Duplicate the center seam, sharing the exact UV. Above the hips both sides
	# remain coincident. Below, the legs can pass without inverted triangles or
	# stretching a strip of trouser texture between the two feet.
	var key: String = "server_carry" if person.profile_id == "server" and person.carrying else person.profile_id
	var near: int = int(NEAR_LEG[key])
	# Painter's order: far leg first, near leg last. Never sort by the moving
	# foot's X or lift; that would swap depth twice per step and cause popping.
	for side: int in [1-near, near]:
		var x0: float = rect.position.x if side == 0 else split
		var x1: float = split if side == 0 else rect.end.x
		var columns: int = ceili((x1-x0) / 2.0)
		var start: int = points.size()
		for row: int in range(rows+1):
			for column: int in range(columns+1):
				var point: Vector2 = Vector2(lerpf(x0,x1,float(column)/columns), rect.position.y+rect.size.y*float(row)/rows)
				points.append(point)
				sides.append(side)
				uvs.append((point * 2.0 + Vector2(160,224)) / Vector2(320,240))
				var weight: Vector4 = _weights(point, person)
				var leg: float = weight.x + weight.y
				weight.x = leg if side == 0 else 0.0
				weight.y = leg if side == 1 else 0.0
				weights.append(weight)
		for row: int in range(rows):
			for column: int in range(columns):
				var a: int = start+row*(columns+1)+column
				indices.append_array(PackedInt32Array([a,a+1,a+columns+1,a+1,a+columns+2,a+columns+1]))
	return {"points":points,"uvs":uvs,"weights":weights,"indices":indices,"sides":sides}
