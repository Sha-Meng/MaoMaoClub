extends SceneTree
## Reproducible GPU animation resampling. Does not repaint or cut body parts.

const BLEND: Shader = preload("res://features/tavern/walk_resample.gdshader")

class PoseAtlas:
	extends Node2D
	var art: TavernWalkArt
	var key: String
	func _draw() -> void:
		for index: int in range(8):
			var pose: Dictionary = art.frames[key][index]
			draw_set_transform(Vector2(index, 0) * TavernWalkArt.SMOOTH_CELL + TavernWalkArt.SMOOTH_ORIGIN, 0.0, Vector2.ONE * TavernWalkArt.SMOOTH_SCALE)
			draw_polygon(pose.points, PackedColorArray([Color.WHITE]), pose.uvs, TavernWalkArt.SHEETS[key])
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	var sources_only: bool = "--sources-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://tmp/walk_resample")
	DirAccess.make_dir_recursive_absolute(TavernWalkArt.SMOOTH_FOLDER)
	var art: TavernWalkArt = TavernWalkArt.new()
	var source: SubViewport = SubViewport.new()
	source.size = Vector2i(2560, 240)
	source.transparent_bg = true
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(source)
	var poses: PoseAtlas = PoseAtlas.new()
	poses.art = art
	source.add_child(poses)
	var output: SubViewport = SubViewport.new()
	output.size = Vector2i(2560, 960)
	output.transparent_bg = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var rect: ColorRect = ColorRect.new()
	rect.size = output.size
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = BLEND
	shader_material.set_shader_parameter("poses", source.get_texture())
	rect.material = shader_material
	output.add_child(rect)
	for key: String in TavernWalkArt.SHEETS:
		poses.key = key
		poses.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if sources_only:
			source.get_texture().get_image().save_png("res://tmp/walk_resample/" + key + ".png")
			continue
		var path: String = "res://tmp/walk_resample/" + key + ".flow"
		if not FileAccess.file_exists(path):
			push_error("请先导出注册帧并执行 tools/analyze_walk_motion.py: " + key)
			quit(1)
			return
		var flow: Image = Image.create_from_data(2560, 240, false, Image.FORMAT_RGBAF, FileAccess.get_file_as_bytes(path))
		shader_material.set_shader_parameter("motion", ImageTexture.create_from_image(flow))
		await process_frame
		await RenderingServer.frame_post_draw
		var error: Error = output.get_texture().get_image().save_png(TavernWalkArt.SMOOTH_FOLDER + key + ".png")
		if error != OK:
			push_error("步态重采样输出失败: " + key)
			quit(1)
			return
	print("完整人物步态注册帧导出完成" if sources_only else "完整人物步态 GPU 重采样完成：10 图集，每图 32 帧")
	quit()
