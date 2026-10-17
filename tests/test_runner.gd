extends SceneTree

var assertions: int = 0
var failures: Array[String] = []
var cases: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suite: RefCounted = preload("res://tests/unit/test_tavern.gd").new()
	suite.run(self)
	var edges: RefCounted = preload("res://tests/unit/test_tavern_edges.gd").new()
	edges.run(self)
	var fixes: RefCounted = preload("res://tests/unit/test_horizontal_walk.gd").new()
	fixes.run(self)
	var binding: RefCounted = preload("res://tests/unit/test_actor_binding.gd").new()
	binding.run(self)
	var drinks: RefCounted = preload("res://tests/unit/test_drinks_and_legs.gd").new()
	drinks.run(self)
	var smooth: RefCounted = preload("res://tests/unit/test_walk_smooth.gd").new()
	smooth.run(self)
	var integration: RefCounted = preload("res://tests/integration/test_tavern_scene.gd").new()
	await integration.run(self)
	check(cases >= 45, "所有单元及场景测试均执行至结尾")
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "engine_hash": Engine.get_version_info()["hash"], "cases": cases, "assertions": assertions, "failures": failures, "results": results, "success": failures.is_empty()}
	var output: FileAccess = FileAccess.open("user://tavern_test_report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
	var evidence: FileAccess = FileAccess.open("res://production/qa/personality_tavern/unit_integration.json", FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error("测试失败: " + message)


func case_done(title: String, before: int) -> void:
	cases += 1
	results.append({"name": title, "success": failures.size() == before})
