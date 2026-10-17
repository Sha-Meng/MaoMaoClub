extends RefCounted

func run(test: SceneTree) -> void:
	for method: Callable in [_test_support_lock, _test_sole_rigidity, _test_cycle_continuity, _test_stop, _test_same_portrait, _test_real_cadence, _test_articulated_joints, _test_weight_and_arms, _test_balanced_steps]:
		var before: int = test.failures.size()
		method.call(test)
		test.case_done(str(method.get_method()), before)

func _test_support_lock(test: SceneTree) -> void:
	var gait: TavernGroundedGait = TavernGroundedGait.new()
	for id: String in CastCatalog.all_ids():
		for direction: float in [-1.0,1.0]:
			for fps: float in [15.0,30.0,60.0]:
				var person: TavernPerson = TavernPerson.new()
				person.profile_id = id
				person.position = Vector2(400,TavernLayout.GROUND)
				person.facing = direction
				var previous: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO]
				var supports: Array[bool] = [false,false]
				var maximum: float = 0.0
				for frame: int in range(int(fps)*4):
					person.walk_to(Vector2(400+direction*1000,TavernLayout.GROUND),1.0/fps,0.65 if frame > int(fps)*2 else 1.0)
					for side: int in range(2):
						var sole: Vector2 = Vector2((TavernWalkPose.JOINTS[id][side][2] as Vector2).x,0)
						var deformed: Vector2 = sole+gait.displacement(sole,person)
						var world: Vector2 = person.position+Vector2(deformed.x*direction,deformed.y)
						var supporting: bool = TavernGroundedGait.is_supporting(person,side)
						if supporting and supports[side]:
							maximum = maxf(maximum,world.distance_to(previous[side]))
						previous[side] = world
						supports[side] = supporting
				test.check(maximum<0.001,"左右/变速/帧率下支撑脚世界漂移<0.001px: %s/%s/%s (%s)" % [id,direction,fps,maximum])

func _test_sole_rigidity(test: SceneTree) -> void:
	var gait: TavernGroundedGait = TavernGroundedGait.new()
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		for step: int in range(64):
			person.walk_phase = float(step)/64
			for side: int in range(2):
				var center: float = (TavernWalkPose.JOINTS[id][side][2] as Vector2).x
				var a: Vector2 = Vector2(center-2,-1)
				var b: Vector2 = Vector2(center+2,-1)
				var c: Vector2 = Vector2(center,-3)
				var aa: Vector2 = a+gait.displacement(a,person)
				var bb: Vector2 = b+gait.displacement(b,person)
				var cc: Vector2 = c+gait.displacement(c,person)
				test.check(absf(aa.distance_to(bb)-a.distance_to(b))<0.001 and absf(aa.distance_to(cc)-a.distance_to(c))<0.001,"脚掌刚性旋转不压细: %s/%d/%d" % [id,step,side])

func _test_cycle_continuity(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		for boundary: float in [0.0,0.2,0.3,0.7,0.8,1.0]:
			for side: int in range(2):
				person.walk_phase = boundary-0.000001
				var before: Vector2 = TavernGroundedGait.foot_offset(person,side)
				person.walk_phase = boundary+0.000001
				test.check(before.distance_to(TavernGroundedGait.foot_offset(person,side))<0.001,"触地/离地/首尾连续: %s/%s/%s" % [id,boundary,side])

func _test_stop(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.position = Vector2(400,TavernLayout.GROUND)
		person.walk_to(Vector2(800,TavernLayout.GROUND),0.37)
		var phase: float = person.walk_phase
		var x: float = TavernGroundedGait.foot_offset(person,0).x
		person.walk_to(person.position,1.0)
		person.settle_gait(0.2)
		test.check(person.walk_phase==phase and TavernGroundedGait.foot_offset(person,0).x==x and person.gait_lift==0.0,"停步不横向归位滑动，仅放下抬脚: "+id)

func _test_same_portrait(test: SceneTree) -> void:
	var art: TavernWalkArt = TavernWalkArt.new()
	var gait: TavernGroundedGait = TavernGroundedGait.new()
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.state = "entering"
		for action: String in ["walk","idle_stand","land","drag_hold"]:
			person.action = action
			test.check(art.supports(person) and art.frame_for(person)==8,"站走/放下/拖动同一来源，松鼠不闪换: "+id+"/"+action)
		for step: int in range(32):
			person.walk_phase = float(step)/32
			person.gait_lift = 1.0
			test.check(gait.displacement(Vector2(0,-float(CastCatalog.profile(id).height)*0.7),person).is_equal_approx(TavernWalkPose.evaluate(person).body),"头部随重心平移、形状不跳变: "+id)

func _test_real_cadence(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		var cadence: float = person.walk_speed()/person.stride_length()
		var bind: Array = TavernWalkPose.JOINTS[id][0]
		var leg_length: float = (bind[0] as Vector2).distance_to(bind[1])+(bind[1] as Vector2).distance_to(bind[2])
		test.check(cadence>=0.75 and cadence<=1.05 and person.stride_length()*0.6<leg_length*0.9,"步幅适配腿长，速度保持舒缓步频: "+id)

func _test_articulated_joints(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		for frame: int in range(64):
			person.walk_phase = float(frame)/64.0
			var pose: Dictionary = TavernWalkPose.evaluate(person)
			test.check(TavernGroundedGait.is_supporting(person,0) or TavernGroundedGait.is_supporting(person,1),"完整周期至少一脚支撑: "+id)
			for side: int in range(2):
				var leg: Dictionary = pose.legs[side]
				var bind: Array = leg.bind
				test.check(absf((leg.hip as Vector2).distance_to(leg.knee)-(bind[0] as Vector2).distance_to(bind[1]))<0.001 and absf((leg.knee as Vector2).distance_to(leg.ankle)-(bind[1] as Vector2).distance_to(bind[2]))<0.001,"髋膝踝两段骨长守恒: %s/%d/%d" % [id,frame,side])
		for side: int in range(2):
			person.walk_phase = side*0.5
			var support: Dictionary = TavernWalkPose.evaluate(person).legs[side]
			person.walk_phase += 0.5
			var swing: Dictionary = TavernWalkPose.evaluate(person).legs[side]
			var support_bend: float = absf((support.knee-support.hip).angle_to(support.ankle-support.knee))
			var swing_bend: float = absf((swing.knee-swing.hip).angle_to(swing.ankle-swing.knee))
			test.check(swing_bend>support_bend+deg_to_rad(15.0),"经过姿态明显屈膝，非整腿平移: %s/%d" % [id,side])

func _test_weight_and_arms(test: SceneTree) -> void:
	var gait: TavernGroundedGait = TavernGroundedGait.new()
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		var low: float = INF
		var high: float = -INF
		for frame: int in range(32):
			person.walk_phase = float(frame)/32.0
			var body: Vector2 = TavernWalkPose.evaluate(person).body
			low = minf(low,body.y)
			high = maxf(high,body.y)
			for side: int in range(2):
				var arm: Rect2 = TavernGroundedGait.ARMS[id][side]
				if not arm.has_area():
					continue
				var hand: Vector2 = Vector2(arm.get_center().x,arm.end.y-7.0)
				var hand_x: float = (gait.displacement(hand,person)-body).x
				var foot_x: float = TavernGroundedGait.foot_offset(person,side).x-TavernWalkPose.track_shift(person,side)
				test.check(hand_x*foot_x<=0.01,"空手与同侧腿反向摆动: %s/%d" % [id,side])
		test.check(high-low>0.5 and high-low<5.0,"重心起伏可见且克制: "+id)

func _test_balanced_steps(test: SceneTree) -> void:
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		var centers: Array[float] = []
		for side: int in range(2):
			person.walk_phase = side*0.5
			centers.append(TavernWalkPose.evaluate(person).legs[side].ankle.x)
		test.check(absf(centers[1]-centers[0])<=3.001,"行走落脚轴只有近远投影差，不沿宽站姿各自摆脚: "+id)
		person.walk_phase = 0.7
		var contact: float = TavernWalkPose.evaluate(person).body.y
		person.walk_phase = 0.8
		var down: float = TavernWalkPose.evaluate(person).body.y
		person.walk_phase = 0.05
		var up: float = TavernWalkPose.evaluate(person).body.y
		test.check(down>contact+0.2 and up<contact-0.5,"触地后承重下沉，经过时回升: "+id)
		person.walk_cycles = 0.0
		for frame: int in range(101):
			person.walk_cycles = float(frame)/100.0
			person.walk_phase = fposmod(person.walk_cycles,1.0)
			for side: int in range(2):
				var before: float = TavernWalkPose.alignment_for(person,side)
				if TavernGroundedGait.is_supporting(person,side):
					test.check(is_zero_approx(before) or is_equal_approx(before,1.0),"首次步态只在摆动期调整落脚轴: %s/%d/%d" % [id,side,frame])
