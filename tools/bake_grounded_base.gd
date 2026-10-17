extends SceneTree
class Portrait:
	extends Node2D
	var art: TavernWalkArt
	var key: String
	func _draw() -> void:
		draw_set_transform(Vector2(160,224),0.0,Vector2.ONE*2.0)
		var pose: Dictionary = art.frames[key][8]
		draw_polygon(pose.points,PackedColorArray([Color.WHITE]),pose.uvs,TavernWalkArt.SHEETS[key])
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute("res://assets/tavern/grounded")
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(320,240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var portrait: Portrait = Portrait.new()
	portrait.art = TavernWalkArt.new()
	viewport.add_child(portrait)
	for key: String in TavernWalkArt.SHEETS:
		portrait.key = key
		portrait.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/tavern/grounded/"+key+".png")
	quit()
