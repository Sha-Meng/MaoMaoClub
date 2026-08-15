extends Resource
class_name FluidConfig

enum FluidId {
	WATER = 0,
	AMBER_SPIRIT = 1,
}

@export_category("Identity")
@export_enum("Water:0", "Amber Spirit:1") var fluid_id: int = FluidId.WATER
@export var fluid_name: String = "未命名液体"
@export_multiline var description: String = ""

@export_category("Business")
@export_range(0.0, 100.0, 0.1) var alcohol_by_volume_percent: float = 0.0
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Real World Reference")
@export var reference_temperature_celsius: float = 20.0
@export var reference_density_kg_per_cubic_meter: float = 1000.0
@export var reference_dynamic_viscosity_pascal_seconds: float = 0.001
@export var reference_speed_of_sound_meters_per_second: float = 1480.0
@export var reference_refractive_index: float = 1.333


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not FluidId.values().has(fluid_id):
		errors.append("fluid_id must be a declared FluidId")
	if fluid_name.strip_edges().is_empty():
		errors.append("fluid_name must not be empty")
	if not is_finite(alcohol_by_volume_percent) or alcohol_by_volume_percent < 0.0 or alcohol_by_volume_percent > 100.0:
		errors.append("alcohol_by_volume_percent must be in [0, 100]")
	_require_positive(errors, "reference_density_kg_per_cubic_meter", reference_density_kg_per_cubic_meter)
	_require_positive(errors, "reference_dynamic_viscosity_pascal_seconds", reference_dynamic_viscosity_pascal_seconds)
	_require_positive(errors, "reference_speed_of_sound_meters_per_second", reference_speed_of_sound_meters_per_second)
	_require_positive(errors, "reference_refractive_index", reference_refractive_index)
	return errors


static func id_name(fluid_id_value: int) -> String:
	match fluid_id_value:
		FluidId.WATER:
			return "WATER"
		FluidId.AMBER_SPIRIT:
			return "AMBER_SPIRIT"
		_:
			return "UNKNOWN_%d" % fluid_id_value


func _require_positive(errors: PackedStringArray, field_name: String, value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		errors.append("%s must be finite and positive" % field_name)
