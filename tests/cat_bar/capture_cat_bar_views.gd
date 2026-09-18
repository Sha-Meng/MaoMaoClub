extends SceneTree

const CAT_BAR_SCENE: PackedScene = preload("res://features/cat_bar/cat_bar.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var cat_bar := CAT_BAR_SCENE.instantiate() as CatBarController
	root.add_child(cat_bar)
	await process_frame
	await process_frame
	var patrons := cat_bar.get_node("%PatronAmbience") as PatronAmbienceController
	patrons.spawn_now()
	patrons.spawn_now()
	await process_frame
	_capture("res://.work/cat_bar_overview.png")
	cat_bar.enter_mixing(true)
	await process_frame
	_capture("res://.work/cat_bar_mixing.png")
	var station := cat_bar.get_bartending_station()
	station.begin_drag_for_test(&"moon_gin")
	await process_frame
	_capture("res://.work/cat_bar_drag_spirit.png")
	station.cancel_drag_for_test()
	station.simulate_drop_for_test(&"moon_gin", &"jigger")
	station.begin_drag_for_test(&"jigger")
	await process_frame
	_capture("res://.work/cat_bar_drag_jigger.png")
	station.cancel_drag_for_test()
	station.simulate_drop_for_test(&"jigger", &"shaker")
	station.simulate_drop_for_test(&"clear_ice", &"shaker")
	station.begin_drag_for_test(&"shaker_lid")
	await process_frame
	_capture("res://.work/cat_bar_drag_lid.png")
	station.cancel_drag_for_test()
	station.simulate_drop_for_test(&"shaker_lid", &"shaker")
	station.begin_shake()
	var adapter := station.get_node("MixingVesselAdapter") as MixingVesselAdapter
	for index: int in range(6):
		var direction := -1.0 if index % 2 == 0 else 1.0
		adapter.apply_shake_delta(Vector2(95.0 * direction, -42.0 * direction), 0.12)
		await physics_frame
	await process_frame
	_capture("res://.work/cat_bar_shake.png")
	adapter.apply_shake_delta(Vector2(-180.0, 75.0), 0.18)
	await physics_frame
	await physics_frame
	_capture("res://.work/cat_bar_shake_reverse.png")
	station.reset_session()
	_complete_recipe(station)
	station.pour_to_glass(false)
	await create_timer(0.46).timeout
	_capture("res://.work/cat_bar_finished_glass.png")
	await create_timer(0.56).timeout
	_capture("res://.work/cat_bar_service_handoff.png")
	await create_timer(0.62).timeout
	_capture("res://.work/cat_bar_worker_delivery.png")
	await create_timer(0.7).timeout
	cat_bar.get_wechat_service().consume_event(&"capture_day", &"new_day")
	cat_bar.open_phone()
	await process_frame
	_capture("res://.work/cat_bar_phone_home.png")
	cat_bar.get_phone_shell().open_wechat()
	cat_bar.get_phone_shell().get_wechat_view().select_tab(WechatView.Tab.MOMENTS)
	await process_frame
	await process_frame
	_capture("res://.work/cat_bar_phone.png")
	var wechat_view := cat_bar.get_phone_shell().get_wechat_view()
	wechat_view.select_tab(WechatView.Tab.CONTACTS)
	await process_frame
	_capture("res://.work/cat_bar_phone_contacts.png")
	wechat_view.activate_contact_double_click_for_test(&"manager_cat")
	wechat_view.submit_chat_text("你好，今晚的经典鸡尾酒怎么练？")
	await process_frame
	await process_frame
	_capture("res://.work/cat_bar_phone_chat.png")
	cat_bar.queue_free()
	await process_frame
	quit()


func _complete_recipe(station: BartendingStation) -> void:
	station.simulate_drop_for_test(&"moon_gin", &"jigger")
	station.simulate_drop_for_test(&"jigger", &"shaker")
	station.simulate_drop_for_test(&"dusk_liqueur", &"jigger")
	station.simulate_drop_for_test(&"jigger", &"shaker")
	station.simulate_drop_for_test(&"clear_ice", &"shaker")
	station.simulate_drop_for_test(&"clear_ice", &"shaker")
	station.simulate_drop_for_test(&"catnip_spice", &"shaker")
	station.submit_stir_gesture(120.0, 2.0)
	station.toggle_seal()
	station.complete_shake_for_test({&"duration": 4.0, &"distance": 320.0, &"reversals": 8.0, &"peak_speed": 420.0})


func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE %s %s %dx%d" % [path, error_string(error), image.get_width(), image.get_height()])
