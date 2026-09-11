extends RefCounted
class_name CatBarTestSuite

var passed: int = 0
var failed: int = 0
var failures: PackedStringArray = PackedStringArray()


func run_case(test_name: String, test_callable: Callable) -> void:
	var before := failures.size()
	test_callable.call()
	if failures.size() == before:
		passed += 1
		print("PASS: %s" % test_name)
	else:
		failed += 1
		print("FAIL: %s" % test_name)


func expect_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		var failure := "%s (actual=%s expected=%s)" % [message, actual, expected]
		failures.append(failure)
		push_error(failure)


func expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		var failure := "%s (actual=%f expected=%f tolerance=%f)" % [message, actual, expected, tolerance]
		failures.append(failure)
		push_error(failure)


func expect_contains_text(values: PackedStringArray, needle: String, message: String) -> void:
	for value: String in values:
		if value.contains(needle):
			return
	var failure := "%s (needle=%s values=%s)" % [message, needle, values]
	failures.append(failure)
	push_error(failure)

