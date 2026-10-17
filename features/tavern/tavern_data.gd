extends RefCounted
class_name TavernData


static func number(value: Variant, fallback: float = 0.0, minimum: float = 0.0, maximum: float = 100000000.0) -> float:
	if value is int or value is float:
		var result: float = float(value)
		if is_finite(result):
			return clampf(result, minimum, maximum)
	return fallback


static func integer(value: Variant, fallback: int = 0, minimum: int = 0, maximum: int = 9223372036854775807) -> int:
	if value is int:
		return clampi(int(value), minimum, maximum)
	if value is float and is_finite(float(value)):
		return clampi(int(value), minimum, maximum)
	return fallback
