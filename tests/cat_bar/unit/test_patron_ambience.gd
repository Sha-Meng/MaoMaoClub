extends RefCounted

const DEFAULT_CONFIG: PatronAmbienceConfig = preload("res://features/cat_bar/patrons/configs/default_patron_ambience.tres")


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("卡座租约唯一占用与禁用容量", _test_seat_leases.bind(suite))
	suite.run_case("氛围选择固定种子可重放", _test_deterministic_selection.bind(suite))
	suite.run_case("氛围顾客池长期复用且不修改经济", _test_pool_and_economy_isolation.bind(suite))


func _test_seat_leases(suite: CatBarTestSuite) -> void:
	var disabled := PatronSeatDefinition.new()
	disabled.seat_id = &"disabled"
	disabled.enabled = false
	var seats: Array[PatronSeatDefinition] = DEFAULT_CONFIG.seats.duplicate()
	seats.append(disabled)
	var leases := SeatLeaseService.new()
	suite.expect_equal(leases.configure(seats).size(), 0, "合法座位不应产生诊断")
	suite.expect_equal(leases.enabled_capacity(), 2, "禁用座位不得计入容量")
	var first := leases.try_lease(1)
	var second := leases.try_lease(2)
	suite.expect_true(first != second and not first.is_empty() and not second.is_empty(), "两个顾客必须获得唯一座位")
	suite.expect_true(leases.try_lease(3).is_empty(), "无空位时应延迟生成")
	suite.expect_true(leases.release(first, 1), "离场应释放自己的租约")
	suite.expect_equal(leases.try_lease(3), first, "释放后的座位应可复用")


func _test_deterministic_selection(suite: CatBarTestSuite) -> void:
	var first := _make_controller()
	var second := _make_controller()
	first._ready()
	second._ready()
	first.spawn_now()
	second.spawn_now()
	first.spawn_now()
	second.spawn_now()
	suite.expect_equal(first.active_signature(), second.active_signature(), "相同种子与事件顺序必须产生相同顾客和座位")
	first.free()
	second.free()


func _test_pool_and_economy_isolation(suite: CatBarTestSuite) -> void:
	var economy := EconomyState.new()
	var controller := _make_controller()
	controller._ready()
	controller.spawn_now()
	controller.advance(DEFAULT_CONFIG.stay_seconds + 1.0)
	suite.expect_equal(controller.active_count(), 0, "完成离场时间线后不应保留活跃顾客")
	suite.expect_equal(controller.pooled_count(), 1, "离场表现实例应进入对象池")
	controller.spawn_now()
	suite.expect_equal(controller.pooled_count(), 0, "新顾客应复用池中实例")
	suite.expect_equal(economy.served_customers_total, 0, "氛围循环不得结算经营订单")
	controller.free()
	economy.free()


func _make_controller() -> PatronAmbienceController:
	var controller := PatronAmbienceController.new()
	controller.config = DEFAULT_CONFIG.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as PatronAmbienceConfig
	controller.config.spawn_interval_seconds = 1000.0
	return controller
