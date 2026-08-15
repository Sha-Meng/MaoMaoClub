extends Resource
class_name FluidCatalog

@export var fluids: Array[FluidConfig] = []


func get_fluid(fluid_id: int) -> FluidConfig:
	for fluid: FluidConfig in fluids:
		if fluid != null and fluid.fluid_id == fluid_id:
			return fluid
	return null


func get_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for fluid: FluidConfig in fluids:
		if fluid != null:
			ids.append(fluid.fluid_id)
	return ids


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if fluids.is_empty():
		errors.append("fluids must not be empty")
	var seen_ids: Dictionary = {}
	for index: int in range(fluids.size()):
		var fluid := fluids[index]
		if fluid == null:
			errors.append("fluids[%d] must not be null" % index)
			continue
		for error: String in fluid.validate():
			errors.append("fluids[%d]: %s" % [index, error])
		if seen_ids.has(fluid.fluid_id):
			errors.append("fluid_id %d is duplicated" % fluid.fluid_id)
		seen_ids[fluid.fluid_id] = true
	return errors
