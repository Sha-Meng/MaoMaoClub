extends SceneTree

const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")
const FRAME_BUDGET_MSEC := 1000.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cat_bar := CAT_BAR_SCENE.instantiate() as CatBarController
	root.add_child(cat_bar)
	await process_frame
	var samples: Dictionary[String, float] = {}
	samples["overview"] = await _measure_frames(120)
	cat_bar.enter_mixing(true)
	samples["mixing"] = await _measure_frames(120)
	var station := cat_bar.get_bartending_station()
	station.click_content(&"moon_gin")
	station.toggle_seal()
	station.begin_shake()
	samples["shake"] = await _measure_frames(120)
	station.reset_session()
	cat_bar.exit_mixing(true)
	for index: int in range(40):
		cat_bar.get_wechat_service().consume_event(StringName("perf_event_%d" % index), &"new_day")
	cat_bar.open_phone()
	cat_bar.get_phone_shell().open_wechat()
	cat_bar.get_phone_shell().get_wechat_view().select_tab(WechatView.Tab.MOMENTS)
	samples["phone_moments"] = await _measure_frames(120)
	cat_bar.close_phone()
	var ambience := cat_bar.get_node("PatronAmbience") as PatronAmbienceController
	var started := Time.get_ticks_usec()
	for _frame: int in range(3600):
		ambience.advance(1.0 / 60.0)
	samples["ambience_simulated"] = float(Time.get_ticks_usec() - started) / 1000.0 / 3600.0
	var failed := false
	for label: String in samples:
		var average: float = samples[label]
		print("PERF %s avg_ms=%.4f budget_ms=%.4f nodes=%d" % [label, average, FRAME_BUDGET_MSEC, _count_nodes(root)])
		failed = failed or average > FRAME_BUDGET_MSEC
	cat_bar.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _measure_frames(count: int) -> float:
	var started := Time.get_ticks_usec()
	for _index: int in range(count):
		await process_frame
	return float(Time.get_ticks_usec() - started) / 1000.0 / float(count)


func _count_nodes(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total
