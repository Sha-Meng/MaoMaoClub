extends RefCounted
class_name TavernWalkPose

# Bind landmarks on the unchanged complete portraits: near/far hip, knee, ankle.
const JOINTS: Dictionary = {
	"customer_squirrel": [[Vector2(-7,-24),Vector2(-8,-13),Vector2(-7,-4)], [Vector2(7,-24),Vector2(6,-13),Vector2(7,-4)]],
	"customer_dog": [[Vector2(-5,-39),Vector2(-6,-22),Vector2(-5,-5)], [Vector2(17,-39),Vector2(17,-22),Vector2(17,-5)]],
	"customer_capybara": [[Vector2(-12,-25),Vector2(-13,-15),Vector2(-12,-5)], [Vector2(13,-25),Vector2(12,-15),Vector2(13,-5)]],
	"customer_fox": [[Vector2(-6,-38),Vector2(-7,-22),Vector2(-6,-5)], [Vector2(14,-38),Vector2(13,-22),Vector2(14,-5)]],
	"customer_rabbit": [[Vector2(-3,-23),Vector2(-4,-14),Vector2(-3,-5)], [Vector2(18,-23),Vector2(17,-14),Vector2(18,-5)]],
	"customer_raccoon": [[Vector2(-5,-26),Vector2(-6,-16),Vector2(-5,-5)], [Vector2(13,-26),Vector2(12,-16),Vector2(13,-5)]],
	"manager": [[Vector2(-8,-25),Vector2(-9,-15),Vector2(-8,-5)], [Vector2(17,-25),Vector2(16,-15),Vector2(17,-5)]],
	"bartender": [[Vector2(-8,-32),Vector2(-9,-19),Vector2(-8,-5)], [Vector2(15,-32),Vector2(14,-19),Vector2(15,-5)]],
	"server": [[Vector2(-7,-24),Vector2(-8,-14),Vector2(-7,-4)], [Vector2(13,-24),Vector2(12,-14),Vector2(13,-4)]]}
const STRIDES: Dictionary = {"customer_squirrel":28.0,"customer_dog":44.0,"customer_capybara":28.0,"customer_fox":42.0,"customer_rabbit":26.0,"customer_raccoon":30.0,"manager":28.0,"bartender":38.0,"server":28.0}
const SPEEDS: Dictionary = {"customer_squirrel":25.0,"customer_dog":40.0,"customer_capybara":24.0,"customer_fox":40.0,"customer_rabbit":24.0,"customer_raccoon":26.0,"manager":24.0,"bartender":35.0,"server":26.0}
const STANCE: float = 0.6

static func phase_for(person: TavernPerson, side: int) -> float:
	return fposmod(person.walk_phase + 0.3 + side*0.5,1.0)

static func alignment_for(person: TavernPerson, side: int) -> float:
	# The neutral three-quarter portrait has widely separated planted feet.
	# Bring each foot onto its walking track during that foot's FIRST swing only.
	# Never change its track center during support or reset it when stopping.
	return smoothstep(0.3,0.7,person.walk_cycles) if side==0 else smoothstep(0.0,0.2,person.walk_cycles)

static func track_shift(person: TavernPerson, side: int) -> float:
	var binds: Array = JOINTS[person.profile_id]
	var center: float = ((binds[0][0] as Vector2).x+(binds[1][0] as Vector2).x)*0.5
	var target: float = center+(-1.5 if side==0 else 1.5)
	return (target-(binds[side][2] as Vector2).x)*alignment_for(person,side)

static func foot_offset(person: TavernPerson, side: int) -> Vector2:
	var phase: float = phase_for(person,side)
	var stride: float = float(STRIDES[person.profile_id])
	var track: float = track_shift(person,side)
	var ground: float = 0.0 if side == 0 else (1.5 if person.profile_id == "server" and person.carrying else float(TavernGroundedGait.SOLE_DROP[person.profile_id]))
	if phase < STANCE:
		return Vector2(track+stride*(0.3-phase),ground)
	var u: float = (phase-STANCE)/(1.0-STANCE)
	var lift: float = 3.5 if person.profile_id in ["customer_dog","customer_fox","bartender"] else 2.5
	var x: float = stride*(-0.3-0.4*u+3.0*u*u-2.0*u*u*u)
	return Vector2(track+x,ground-lift*pow(sin(PI*u),2.0)*person.gait_lift)

static func foot_angle(person: TavernPerson, side: int) -> float:
	var phase: float = phase_for(person,side)
	if phase < STANCE:
		return 0.0
	var u: float = (phase-STANCE)/(1.0-STANCE)
	var angle: float = 0.28*sin(TAU*u)*pow(sin(PI*u),2.0)*person.gait_lift
	var data: Array = TavernGroundedGait.ANATOMY[person.profile_id]
	var ankle_x: float = (JOINTS[person.profile_id][side][2] as Vector2).x
	var edge: float = float(data[2] if side==0 else data[4]) if angle>=0.0 else float(data[3] if side==0 else data[2])
	var radius: float = maxf(5.0,absf(edge-ankle_x))
	var lift: float = 3.5 if person.profile_id in ["customer_dog","customer_fox","bartender"] else 2.5
	var clearance: float = lift*pow(sin(PI*u),2.0)*person.gait_lift
	# Large stylized paws need clearance too: toe/heel roll cannot drive their
	# lowest edge through the floor while the ankle is nominally lifted.
	var limit: float = atan(clearance*0.55/radius)
	return clampf(angle,-limit,limit)

static func solve_knee(hip: Vector2, ankle: Vector2, upper: float, lower: float) -> Vector2:
	var line: Vector2 = ankle-hip
	var length: float = clampf(line.length(),0.001,upper+lower-0.001)
	var direction: Vector2 = line.normalized()
	var along: float = (upper*upper-lower*lower+length*length)/(2.0*length)
	var bend: float = sqrt(maxf(0.0,upper*upper-along*along))
	# Knee bends toward travel (+X in portrait space), never backward.
	return hip+direction*along+Vector2(direction.y,-direction.x)*bend

static func evaluate(person: TavernPerson) -> Dictionary:
	var bindings: Array = JOINTS[person.profile_id]
	var alignment: float = (alignment_for(person,0)+alignment_for(person,1))*0.5
	var center: float = ((bindings[0][0] as Vector2).x+(bindings[1][0] as Vector2).x)*0.5
	var hip_shifts: Array[Vector2] = []
	for side: int in range(2):
		var hip: Vector2 = bindings[side][0]
		hip_shifts.append(Vector2((center+(-2.0 if side==0 else 2.0)-hip.x)*alignment,0.0))
	var down: float = 3.1 if person.profile_id=="customer_dog" else 2.6
	# Weight is accepted just AFTER contact; passing/up is the high point.
	var body: Vector2 = Vector2(0.0,((down+1.0)*0.5+(down-1.0)*0.5*cos((person.walk_phase-0.30)*TAU*2.0))*person.gait_lift)
	# Lower the pelvis enough to keep both feet reachable without stretching.
	for side: int in range(2):
		var bind: Array = bindings[side]
		var hip: Vector2 = (bind[0] as Vector2)+hip_shifts[side]
		var ankle: Vector2 = (bind[2] as Vector2)+foot_offset(person,side)
		var reach: float = (bind[0] as Vector2).distance_to(bind[1])+(bind[1] as Vector2).distance_to(bind[2])-0.15
		var horizontal: float = ankle.x-hip.x
		var available_y: float = sqrt(maxf(0.1,reach*reach-horizontal*horizontal))
		var needed: float = ankle.y-hip.y-available_y
		var difference: float = body.y-needed
		# A smooth upper envelope keeps the feet reachable without velocity
		# corners when responsibility transfers between the supporting legs.
		body.y = 0.5*(body.y+needed+sqrt(difference*difference+0.16))
	var legs: Array[Dictionary] = []
	for side: int in range(2):
		var bind: Array = bindings[side]
		var hip: Vector2 = (bind[0] as Vector2)+body+hip_shifts[side]
		var ankle: Vector2 = (bind[2] as Vector2)+foot_offset(person,side)
		var knee: Vector2 = solve_knee(hip,ankle,(bind[0] as Vector2).distance_to(bind[1]),(bind[1] as Vector2).distance_to(bind[2]))
		legs.append({"bind":bind,"hip":hip,"knee":knee,"ankle":ankle,
			"foot_top":float(TavernGroundedGait.ANATOMY[person.profile_id][1]),
			"upper_angle":((bind[1] as Vector2)-(bind[0] as Vector2)).angle_to(knee-hip),
			"lower_angle":((bind[2] as Vector2)-(bind[1] as Vector2)).angle_to(ankle-knee),
			"foot_angle":foot_angle(person,side)})
	return {"body":body,"legs":legs}

static func row_transform(y: float, leg: Dictionary, body: Vector2) -> Transform2D:
	var bind: Array = leg.bind
	var joint: Vector2
	var target: Vector2
	var angle: float
	if y < (bind[0] as Vector2).y+3.0:
		joint = bind[0]
		var blend: float = smoothstep(joint.y-5.0,joint.y+3.0,y)
		target = joint+body+((leg.hip as Vector2)-joint-body)*blend
		angle = float(leg.upper_angle)*blend
	elif y < (bind[1] as Vector2).y+3.0:
		joint = bind[1]
		target = leg.knee
		angle = lerp_angle(float(leg.upper_angle),float(leg.lower_angle),smoothstep(joint.y-3.0,joint.y+3.0,y))
	else:
		joint = bind[2]
		target = leg.ankle
		var start: float = maxf((bind[1] as Vector2).y+3.0,float(leg.foot_top)-5.0)
		angle = lerp_angle(float(leg.lower_angle),float(leg.foot_angle),smoothstep(start,float(leg.foot_top),y))
	var transform: Transform2D = Transform2D(angle,Vector2.ZERO)
	transform.origin = target-transform.basis_xform(joint)
	if y < (bind[0] as Vector2).y-5.0:
		return Transform2D(0.0,body)
	return transform
