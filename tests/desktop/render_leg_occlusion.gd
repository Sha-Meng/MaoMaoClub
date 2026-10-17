extends SceneTree

const FOLDER: String = "res://production/qa/leg_occlusion"
const CELL: Vector2i = Vector2i(480, 480)

class Actor:
	extends Node2D
	var gait: TavernGroundedGait = TavernGroundedGait.new()
	var person: TavernPerson
	var texture: Texture2D
	var bounds: Rect2
	func _draw() -> void:
		draw_set_transform(Vector2(240,448),0.0,Vector2(4.0*person.facing,4.0))
		gait.draw_on(self,person,texture,bounds)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(CELL.x*3,CELL.y)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actors: Array[Actor] = []
	for panel: int in range(3):
		var actor: Actor = Actor.new()
		actor.position.x = panel*CELL.x
		viewport.add_child(actor)
		actors.append(actor)
	var art: TavernWalkArt = TavernWalkArt.new()
	var report: Dictionary = {"variants":{},"samples":0,"overlap_pixels":0,"wrong_order_pixels":0,"errors":[]}
	for key: String in TavernWalkArt.SHEETS:
		var person: TavernPerson = TavernPerson.new()
		person.profile_id = "server" if key == "server_carry" else key
		person.carrying = key == "server_carry"
		person.walking = true
		person.gait_lift = 1.0
		person.walk_cycles = 2.0
		person.action = "walk"
		var source: Image = (load("res://assets/tavern/grounded/"+key+".png") as Texture2D).get_image()
		var split: int = roundi(160.0+float(TavernGroundedGait.ANATOMY[person.profile_id][2])*2.0)
		# Source-left is camera-near in all ten reviewed three-quarter portraits.
		# Preserve actual portrait alpha; label near red / far blue for visibility.
		for panel: int in range(3):
			var marked: Image = Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
			for y: int in range(source.get_height()):
				for x: int in range(source.get_width()):
					var near: bool = x < split
					var alpha: float = source.get_pixel(x,y).a
					if (panel == 0 and not near) or (panel == 1 and near):
						alpha = 0.0
					marked.set_pixel(x,y,Color(1.0 if near else 0.0,0.0,0.0 if near else 1.0,alpha))
			actors[panel].person = person
			actors[panel].bounds = art.frames[key][TavernWalkArt.IDLE_FRAME].bounds
			actors[panel].texture = ImageTexture.create_from_image(marked)
		var overlap: int = 0
		var incorrect: int = 0
		var contact_samples: int = 0
		for facing: float in [-1.0,1.0]:
			person.facing = facing
			for step: int in range(32):
				person.walk_phase = float(step)/32.0
				for actor: Actor in actors:
					actor.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var result: Image = viewport.get_texture().get_image()
				var count: int = 0
				var hip_y: int = floori(448.0+float(TavernGroundedGait.ANATOMY[person.profile_id][0])*4.0)
				for y: int in range(hip_y,450):
					for x: int in range(80,400):
						var near: Color = result.get_pixel(x,y)
						var far: Color = result.get_pixel(x+CELL.x,y)
						# Only unambiguous marker interiors: bilinear sampling at the
						# source seam can mix red/blue even when alpha is opaque.
						if near.a > 0.98 and far.a > 0.98 and near.r > 0.98 and far.b > 0.98:
							count += 1
							var both: Color = result.get_pixel(x+CELL.x*2,y)
							if both.r < 0.95 or both.b > 0.05:
								incorrect += 1
				if count > 0:
					contact_samples += 1
					overlap += count
				if facing == 1.0 and step == 24:
					result.save_png(FOLDER+"/"+key+"_layers.png")
				report.samples += 1
		if contact_samples == 0 or incorrect > 0:
			report.errors.append("近腿遮挡错误: %s overlap=%d wrong=%d" % [key,overlap,incorrect])
		report.variants[key] = {"overlap_samples":contact_samples,"overlap_pixels":overlap,"wrong_order_pixels":incorrect}
		report.overlap_pixels += overlap
		report.wrong_order_pixels += incorrect
	report.success = report.errors.is_empty()
	var output: FileAccess = FileAccess.open(FOLDER+"/occlusion.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.success else 1)
