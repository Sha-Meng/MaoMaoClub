extends SceneTree

class Gallery:
	extends Node2D
	var person: TavernPerson
	var art: TavernWalkArt = TavernWalkArt.new()
	var font: SystemFont = SystemFont.new()
	func _draw() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei UI"])
		draw_rect(Rect2(0,0,1360,280),Color("eee9df"))
		var phases: Array[float] = [0.7,0.8,0.0,0.05]
		var labels: Array[String] = ["接触 / 双脚承重","下沉 / 承接重量","经过 / 摆动腿屈膝","抬起 / 准备下一步"]
		for column: int in range(4):
			# Each queued draw needs its own mesh identity; mutating one person's
			# mesh four times would display the final pose in every column.
			var actor: TavernPerson = TavernPerson.new()
			actor.profile_id = person.profile_id
			actor.carrying = person.carrying
			actor.walking = true
			actor.gait_lift = 1.0
			actor.walk_cycles = 2.0
			actor.walk_phase = phases[column]
			draw_string(font,Vector2(column*340+10,25),labels[column],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("463c33"))
			draw_line(Vector2(column*340,250),Vector2((column+1)*340,250),Color("aaa396"),1.0)
			draw_set_transform(Vector2(column*340+90,250),0.0,Vector2.ONE*2.0)
			art.draw_on(self,actor)
			draw_set_transform(Vector2(column*340+250,250),0.0,Vector2.ONE*2.0)
			var pose: Dictionary = TavernWalkPose.evaluate(actor)
			for side: int in [1,0]:
				var leg: Dictionary = pose.legs[side]
				var color: Color = Color("d96a3b") if side==0 else Color("6284a6")
				draw_polyline(PackedVector2Array([leg.hip,leg.knee,leg.ankle]),color,2.5,true)
				for joint: Vector2 in [leg.hip,leg.knee,leg.ankle]:
					draw_circle(joint,2.0,color)
				var ankle: Vector2 = leg.ankle
				draw_line(ankle+Vector2(-4,4).rotated(leg.foot_angle),ankle+Vector2(7,4).rotated(leg.foot_angle),color,2.0,true)
			draw_line(pose.legs[0].hip,pose.legs[1].hip,Color("5b6355"),2.0,true)
			draw_set_transform(Vector2.ZERO)
			draw_string(font,Vector2(column*340+190,272),"橙：近腿 · 蓝：远腿",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("463c33"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1360,280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery: Gallery = Gallery.new()
	viewport.add_child(gallery)
	for key: String in TavernWalkArt.SHEETS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = "server" if key=="server_carry" else key
		person.carrying = key=="server_carry"
		person.action = "walk"
		person.walking = true
		person.gait_lift = 1.0
		gallery.person = person
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://production/qa/articulated_walk/"+key+"_keys.png")
	quit()
