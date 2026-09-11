extends SceneTree

const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cat_bar := CAT_BAR_SCENE.instantiate() as CatBarController
	root.add_child(cat_bar)
	await process_frame
	var ambience := cat_bar.get_node("PatronAmbience") as PatronAmbienceController
	ambience.config.spawn_interval_seconds = 0.1
	ambience.config.stay_seconds = 0.25
	for _frame: int in range(108000):
		ambience.advance(1.0 / 60.0)
	var wechat := cat_bar.get_wechat_service()
	for event_index: int in range(1000):
		wechat.consume_event(StringName("soak_%d" % event_index), &"new_day")
	cat_bar.open_phone()
	cat_bar.get_phone_shell().open_wechat()
	cat_bar.get_phone_shell().get_wechat_view().select_tab(WechatView.Tab.MOMENTS)
	await process_frame
	var failures := PackedStringArray()
	if ambience.active_count() + ambience.pooled_count() > ambience.config.max_active:
		failures.append("顾客对象池超过活跃上限")
	if wechat.state.messages.size() > wechat.catalog.message_history_limit or wechat.state.moments.size() > wechat.catalog.moment_history_limit:
		failures.append("微信历史超过容量上限")
	if cat_bar.get_phone_shell().get_wechat_view().visible_entry_count() > wechat.catalog.moment_history_limit * 2:
		failures.append("朋友圈 UI 节点未随历史淘汰")
	print("STABILITY simulated_minutes=30 patron_instances=%d messages=%d moments=%d ui_entries=%d failures=%d" % [
		ambience.active_count() + ambience.pooled_count(), wechat.state.messages.size(), wechat.state.moments.size(),
		cat_bar.get_phone_shell().get_wechat_view().visible_entry_count(), failures.size(),
	])
	for failure: String in failures:
		push_error(failure)
	cat_bar.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
