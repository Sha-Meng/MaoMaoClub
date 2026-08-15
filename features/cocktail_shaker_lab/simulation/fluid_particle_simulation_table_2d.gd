extends Resource
class_name FluidParticleSimulationTable2D

@export_enum("Water:0", "Amber Spirit:1") var default_fluid_id: int = FluidConfig.FluidId.WATER
@export var entries: Array[FluidParticleSimulationConfig2D] = []


func get_config(fluid_id: int) -> FluidParticleSimulationConfig2D:
	for entry: FluidParticleSimulationConfig2D in entries:
		if entry != null and entry.fluid_id == fluid_id:
			return entry
	return null


func get_default_config() -> FluidParticleSimulationConfig2D:
	return get_config(default_fluid_id)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if entries.is_empty():
		errors.append("entries must not be empty")
	var seen_ids: Dictionary = {}
	for index: int in range(entries.size()):
		var entry := entries[index]
		if entry == null:
			errors.append("entries[%d] must not be null" % index)
			continue
		for error: String in entry.validate():
			errors.append("entries[%d]: %s" % [index, error])
		if seen_ids.has(entry.fluid_id):
			errors.append("fluid_id %d is duplicated" % entry.fluid_id)
		seen_ids[entry.fluid_id] = true
	if get_default_config() == null:
		errors.append("default_fluid_id must reference an entry")
	return errors
