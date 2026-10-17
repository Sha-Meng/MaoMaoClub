extends SceneTree

func _initialize() -> void:
	var report: Dictionary = {}
	for id: String in CastCatalog.all_ids():
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = id
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		var minimum: float = INF
		var maximum: float = -INF
		var knees: Array[float] = []
		for frame: int in range(64):
			person.walk_phase = float(frame)/64.0
			var pose: Dictionary = TavernWalkPose.evaluate(person)
			minimum = minf(minimum,pose.body.y)
			maximum = maxf(maximum,pose.body.y)
			if frame in [0,32]:
				var leg: Dictionary = pose.legs[0]
				knees.append(rad_to_deg(absf((leg.knee-leg.hip).angle_to(leg.ankle-leg.knee))))
		var critical: Array[float] = []
		for phase: float in [0.7,0.8,0.05]:
			person.walk_phase = phase
			critical.append(TavernWalkPose.evaluate(person).body.y)
		report[id] = {"body_min":minimum,"body_max":maximum,"contact_down_up":critical,"support_and_swing_knee_degrees":knees,"cycles_per_second":person.walk_speed()/person.stride_length()}
	DirAccess.make_dir_recursive_absolute("res://production/qa/articulated_walk")
	var output: FileAccess = FileAccess.open("res://production/qa/articulated_walk/motion.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()
