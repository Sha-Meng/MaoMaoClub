extends SceneTree

const DEFAULT_CONFIG := preload("res://features/cocktail_shaker_lab/configs/default_shaker_test.tres")
const FLUID_CATALOG := preload("res://features/cocktail_shaker_lab/configs/fluid_catalog.tres")
const SIMULATION_TABLE := preload("res://features/cocktail_shaker_lab/configs/particle_simulation_table.tres")
const SHAKER_SCENE := preload("res://features/cocktail_shaker_lab/cocktail_shaker_lab.tscn")

var _passed: int = 0
var _failed: int = 0
var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_case("FluidConfig 业务配表和真实水参考", _test_business_fluid_config)
	_run_case("FluidId 关联完整粒子模拟配表", _test_particle_simulation_table)
	_run_case("默认测试配置和鼠标 Shake 参数", _test_default_test_config)
	_run_case("封盖切换产生四边/三边容器", _test_container_boundaries)
	await _run_scene_workflow_case()
	print("Cocktail shaker tests: %d passed, %d failed" % [_passed, _failed])
	for failure: String in _failures:
		print("  - %s" % failure)
	quit(0 if _failed == 0 else 1)


func _run_case(test_name: String, callable: Callable) -> void:
	var failure_count_before := _failures.size()
	callable.call()
	if _failures.size() == failure_count_before:
		_passed += 1
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		print("FAIL: %s" % test_name)


func _run_scene_workflow_case() -> void:
	var failure_count_before := _failures.size()
	var lab := SHAKER_SCENE.instantiate() as CocktailShakerLab
	root.add_child(lab)
	await physics_frame
	await physics_frame
	_expect_equal(lab.get_available_fluid_count(), 2, "下拉框应来自两项业务配表")
	_expect_equal(lab.get_particle_count(), 0, "场景初始不得有液体")
	_expect_equal(lab.get_ice_count(), 0, "场景初始不得有冰块")
	_expect_true(not lab.is_lid_enabled(), "场景初始不得封盖")
	_expect_equal(lab.get_container_segment_count(), 3, "初始杯子应为三边开口杯")
	_expect_true(not lab.start_shake(), "未封盖时不得开始 Shake")
	_expect_true(lab.select_fluid_by_id(FluidConfig.FluidId.WATER), "应能按 FluidId 选择水")
	_expect_true(lab.add_selected_fluid(), "增加水应成功")
	_expect_equal(lab.get_particle_count(), 18, "单次水配置应生成 18 个粒子")
	var poured_snapshot := lab.get_fluid_snapshot()
	var water_simulation := lab.get_runtime_config().particle_simulation_table.get_config(FluidConfig.FluidId.WATER)
	var home_meters := lab.get_runtime_config().vessel.home_position_pixels / water_simulation.particle_config.pixels_per_meter
	for index: int in range(poured_snapshot.count()):
		var local_position := poured_snapshot.positions_meters[index] - home_meters
		_expect_true(local_position.y < lab.get_runtime_config().vessel.height_meters * 0.35, "新液体必须从杯口上部生成")
		_expect_near(poured_snapshot.velocities_meters_per_second[index].y, water_simulation.pour_initial_downward_speed_meters_per_second, 0.001, "新液体必须具有向下初速度")
	for _index: int in range(45):
		await physics_frame
	_expect_true(lab.select_fluid_by_id(FluidConfig.FluidId.AMBER_SPIRIT), "应能按 FluidId 选择琥珀酒液")
	_expect_true(lab.add_selected_fluid(), "增加琥珀酒液应成功")
	_expect_equal(lab.get_particle_count(), 35, "两次加液后应有 35 个粒子")
	for _index: int in range(45):
		await physics_frame
	_expect_true(lab.add_ice(), "第一次增加冰块应成功")
	_expect_true(lab.add_ice(), "第二次增加冰块应成功")
	_expect_true(lab.add_ice(), "第三次增加冰块应成功")
	_expect_equal(lab.get_ice_count(), 3, "应逐块创建冰块")
	_expect_true(lab.ice_collision_configuration_is_valid(), "冰块必须同时碰撞杯壁层和冰块层")
	lab.set_lid_enabled(true)
	_expect_equal(lab.get_container_segment_count(), 4, "封盖后应形成四边闭合容器")
	var sealed_particle_count := lab.get_particle_count()
	_expect_true(not lab.add_selected_fluid(), "封盖后必须拒绝继续加液")
	_expect_true(not lab.add_ice(), "封盖后必须拒绝继续加冰")
	_expect_equal(lab.get_particle_count(), sealed_particle_count, "拒绝操作不得改变粒子数量")
	_expect_true(lab.start_shake(), "封盖后应进入鼠标 Shake 模式")
	lab.apply_mouse_drag_delta_for_test(Vector2(1000.0, -1000.0))
	var motion := lab.get_runtime_config().motion
	_expect_vector_near(lab.get_shake_target_offset(), Vector2(motion.maximum_offset_pixels.x, -motion.maximum_offset_pixels.y), 0.001, "鼠标 Shake 必须按灵敏度和最大幅度钳制")
	await physics_frame
	_expect_true(not lab.is_shaker_at_home(), "拖动后杯子应离开初始位置")
	var maximum_ice_speed_during_shake := 0.0
	for index: int in range(120):
		var direction := -1.0 if index % 2 == 0 else 1.0
		lab.apply_mouse_drag_delta_for_test(Vector2(10000.0 * direction, -10000.0 * direction))
		await physics_frame
		maximum_ice_speed_during_shake = maxf(
			maximum_ice_speed_during_shake,
			lab.get_maximum_ice_speed_pixels_per_second()
		)
	await process_frame
	_expect_true(maximum_ice_speed_during_shake >= 180.0, "Shake 必须向冰块传递明显运动量")
	_expect_true(lab.get_ice_collision_event_count() > 0, "Shake 期间必须检测到冰块刚体碰撞")
	_expect_true(lab.get_ice_to_ice_collision_event_count() > 0, "冰块之间必须保有刚体碰撞")
	_expect_true(lab.is_shaker_within_motion_bounds(), "极端鼠标输入不得把杯子摇出最大幅度")
	var fluid_contained := lab.are_fluid_particles_contained()
	if not fluid_contained:
		print("DIAGNOSTIC fluid_local_bounds=%s vessel=%s" % [lab.get_fluid_local_bounds(), Vector2(lab.get_runtime_config().vessel.width_meters, lab.get_runtime_config().vessel.height_meters)])
	_expect_true(fluid_contained, "极端 Shake 后液体不得离开封闭杯体")
	_expect_true(lab.are_ice_bodies_contained(0.01), "极端 Shake 后冰块不得离开封闭杯体")
	var fluid_speed_before_settling := lab.get_average_fluid_speed_meters_per_second()
	lab.toggle_shake()
	_expect_true(not lab.is_shaking(), "再次点击 Shake 应退出模式")
	for _reset_frame: int in range(4):
		await physics_frame
	await process_frame
	if not lab.is_shaker_at_home():
		print("DIAGNOSTIC reset_offset=%s reset_rotation=%.8f" % [lab.get_shaker_offset(), lab.get_shaker_rotation_radians()])
	_expect_true(lab.is_shaker_at_home(), "再次点击 Shake 应复位位置和转角")
	_expect_true(lab.is_post_shake_settling(), "结束 Shake 后必须进入快速静稳阶段")
	var settling_frames := ceili(lab.get_runtime_config().motion.settling_duration_seconds * 60.0) + 45
	for _index: int in range(settling_frames):
		await physics_frame
	var settled_fluid_speed := lab.get_average_fluid_speed_meters_per_second()
	print("DIAGNOSTIC shake_ice_max=%.2f collisions=%d ice_collisions=%d fluid_before=%.4f fluid_after=%.4f ice_after=%.2f quiescent=%s" % [
		maximum_ice_speed_during_shake,
		lab.get_ice_collision_event_count(),
		lab.get_ice_to_ice_collision_event_count(),
		fluid_speed_before_settling,
		settled_fluid_speed,
		lab.get_maximum_ice_speed_pixels_per_second(),
		lab.is_fluid_quiescent_damping_active(),
	])
	_expect_true(not lab.is_post_shake_settling(), "配置的静稳窗口必须按时结束")
	_expect_true(settled_fluid_speed < fluid_speed_before_settling, "Shake 后液体平均速度必须持续下降")
	_expect_true(settled_fluid_speed <= 0.30, "Shake 后液体必须在短时间内收敛到低速状态")
	_expect_true(lab.is_fluid_quiescent_damping_active(), "专用静稳结束后常规静置阻尼必须接管")
	lab.reset_test()
	_expect_equal(lab.get_particle_count(), 0, "清空后不得保留液体")
	_expect_equal(lab.get_ice_count(), 0, "清空后不得保留冰块")
	_expect_true(not lab.is_lid_enabled(), "清空后杯盖应打开")
	lab.queue_free()
	await process_frame
	if _failures.size() == failure_count_before:
		_passed += 1
		print("PASS: 空杯、按钮构造、封盖和鼠标 Shake 场景流程")
	else:
		_failed += 1
		print("FAIL: 空杯、按钮构造、封盖和鼠标 Shake 场景流程")


func _test_business_fluid_config() -> void:
	var catalog := FLUID_CATALOG as FluidCatalog
	_expect_equal(catalog.validate().size(), 0, "业务液体目录必须有效")
	_expect_equal(catalog.fluids.size(), 2, "业务目录应包含水和琥珀酒液")
	var water := catalog.get_fluid(FluidConfig.FluidId.WATER)
	_expect_true(water != null, "应能按 FluidId.WATER 查询业务配置")
	_expect_equal(water.fluid_name, "水（20°C）", "水业务名称")
	_expect_near(water.reference_density_kg_per_cubic_meter, 998.2, 0.01, "水参考密度")
	_expect_near(water.reference_dynamic_viscosity_pascal_seconds, 0.001002, 0.000001, "水参考动力黏度")
	_expect_near(water.reference_speed_of_sound_meters_per_second, 1482.0, 0.1, "水参考声速")
	_expect_near(water.reference_refractive_index, 1.333, 0.001, "水参考折射率")


func _test_particle_simulation_table() -> void:
	var table := SIMULATION_TABLE as FluidParticleSimulationTable2D
	_expect_equal(table.validate().size(), 0, "粒子模拟配表必须有效")
	_expect_equal(table.entries.size(), 2, "模拟配表应包含两个 FluidId Key")
	for fluid: FluidConfig in (FLUID_CATALOG as FluidCatalog).fluids:
		var simulation := table.get_config(fluid.fluid_id)
		_expect_true(simulation != null, "每个业务 FluidId 必须有模拟配置")
		_expect_equal(simulation.fluid_id, fluid.fluid_id, "业务与模拟配置 Key 必须一致")
		_expect_true(simulation.particle_config != null, "每项模拟配置必须包含完整 ParticleFluidConfig2D")
		_expect_equal(simulation.particle_config.validate().size(), 0, "完整粒子参数必须有效")
		_expect_equal(simulation.to_fluid_material().material_id, fluid.fluid_id, "底层材质 ID 必须使用 FluidId")
	var water := table.get_config(FluidConfig.FluidId.WATER)
	_expect_near(water.particle_config.speed_of_sound, 6.5, 0.001, "实时数值声速不应误用真实声速")
	_expect_near(water.particle_config.dynamic_viscosity, 4.0, 0.001, "水实时数值黏度")


func _test_default_test_config() -> void:
	var config := DEFAULT_CONFIG as ShakerTestConfig2D
	_expect_equal(config.validate().size(), 0, "默认 Shake 测试配置必须有效")
	_expect_true(not config.vessel.lid_enabled, "默认杯盖必须打开")
	_expect_near(config.particle_volume_liters(config.get_default_simulation()), 0.0121, 0.000001, "单粒子等效体积")
	_expect_equal(config.particle_count_per_add(config.get_default_simulation()), 18, "单次加水粒子量化")
	_expect_near(config.motion.mouse_sensitivity, 1.15, 0.001, "默认鼠标 Shake 灵敏度")
	_expect_vector_near(config.motion.clamp_offset(Vector2(999.0, -999.0)), Vector2(135.0, -90.0), 0.001, "最大 Shake 幅度")
	_expect_near(config.motion.rotation_for_offset(Vector2(135.0, 0.0)), 0.28, 0.001, "最大 Shake 转角")
	_expect_near(config.ice.maximum_fluid_force, 14.0, 0.001, "冰块最大流体力必须提供明显 Shake 反馈")
	_expect_true((config.ice.collision_mask & config.ice.collision_layer) != 0, "冰块碰撞掩码必须包含冰块自身层")
	_expect_true((config.ice.collision_mask & config.vessel.collision_layer) != 0, "冰块碰撞掩码必须包含杯壁层")
	_expect_true(config.motion.settling_fluid_damping_per_second >= 20.0, "Shake 后液体静稳阻尼必须足够快速")


func _test_container_boundaries() -> void:
	var vessel := (DEFAULT_CONFIG as ShakerTestConfig2D).vessel
	var shape := ContainerShape2D.new()
	shape.configure_convex_polygon(PackedVector2Array([
		Vector2(-vessel.width_meters * 0.5, 0.0), Vector2(vessel.width_meters * 0.5, 0.0),
		Vector2(vessel.width_meters * 0.5, vessel.height_meters), Vector2(-vessel.width_meters * 0.5, vessel.height_meters),
	]))
	_expect_equal(shape.segment_count(), 4, "封盖杯必须有四段边界")
	var container := ContainerSnapshot2D.new()
	container.shape = shape
	container.world_transform = Transform2D.IDENTITY
	var constrained := BoundarySolver2D.constrain_particle(
		Vector2.ZERO, Vector2(9.0, -7.0), Vector2(40.0, -35.0),
		1.0, 0.02, container, 0.0, 0.05
	)
	var corrected: Vector2 = constrained["position"]
	_expect_true(corrected.x <= vessel.width_meters * 0.5 and corrected.x >= -vessel.width_meters * 0.5, "闭合边界必须追回远距离水平穿透")
	_expect_true(corrected.y >= 0.0 and corrected.y <= vessel.height_meters, "闭合边界必须追回远距离垂直穿透")
	shape.configure_open_cup(vessel.width_meters, vessel.height_meters)
	_expect_equal(shape.segment_count(), 3, "开盖杯必须有三段边界")


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
		push_error(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		var failure := "%s (actual=%s expected=%s)" % [message, actual, expected]
		_failures.append(failure)
		push_error(failure)


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		var failure := "%s (actual=%f expected=%f tolerance=%f)" % [message, actual, expected, tolerance]
		_failures.append(failure)
		push_error(failure)


func _expect_vector_near(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) > tolerance:
		var failure := "%s (actual=%s expected=%s tolerance=%f)" % [message, actual, expected, tolerance]
		_failures.append(failure)
		push_error(failure)
