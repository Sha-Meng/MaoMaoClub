extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.unfocusable = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1120, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab: Node2D = load("res://features/animation_lab/manager_lab.tscn").instantiate() as Node2D
	lab.set("capture_mode", true)
	viewport.add_child(lab)
	var folder: String = "res://tmp/manager_blender/review/"
	DirAccess.make_dir_recursive_absolute(folder)
	var elapsed_us: int = 0
	var worst_us: int = 0
	for frame: int in range(330):
		var start: int = Time.get_ticks_usec()
		lab.call("advance_demo", 1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var render_us: int = Time.get_ticks_usec() - start
		elapsed_us += render_us
		worst_us = maxi(worst_us, render_us)
		var picture: Image = viewport.get_texture().get_image()
		picture.save_png(folder + "%04d.png" % frame)
		if frame == 220:
			picture.save_png("res://production/qa/manager_blender/preview.png")
	# 同一正式绘制入口检查深底与左右镜像。
	lab.set("dark", true)
	lab.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://production/qa/manager_blender/dark_preview.png")
	var report: Dictionary = {"frames": 330, "duration_seconds": 11.0, "resolution": [1120, 720], "engine": Engine.get_version_info()["string"], "mean_capture_render_ms": elapsed_us / 330000.0, "worst_capture_render_ms": worst_us / 1000.0, "texture_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED), "note": "帧耗时包含等待渲染信号，非隔离 GPU 基准；纹理内存包含字体和预览界面。"}
	var file: FileAccess = FileAccess.open("res://production/qa/manager_blender/render_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
