extends RefCounted
class_name ParticleFluidBenchmark

const SAMPLE_STEPS: int = 10
const WARMUP_STEPS: int = 2

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var environment := {
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"logical_processors": OS.get_processor_count(),
	}
	print("BENCHMARK_ENV: %s" % JSON.stringify(environment))
	for particle_count: int in [500, 1000, 2000]:
		results.append(_run_case(particle_count))
	for lab_particle_count: int in [60, 136]:
		results.append(_run_lab_case(lab_particle_count))
	print("BENCHMARK_JSON: %s" % JSON.stringify(results))
	return results

func _run_lab_case(particle_count: int) -> Dictionary:
	var config := ParticleFluidConfig2D.new()
	config.smoothing_radius_meters = 0.20 * 1.9
	config.effective_depth_meters = 0.1
	config.particle_mass = 1000.0 * config.effective_depth_meters * 0.20 * 0.20
	config.speed_of_sound = 12.0
	config.gas_stiffness = config.rest_density * config.speed_of_sound * config.speed_of_sound
	config.dynamic_viscosity = 50.0
	config.color_diffusion = 0.9
	config.max_substeps = 8
	config.density_error_warning_ratio = 0.75
	config.enable_step_profiling = true
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var container_shape := ContainerShape2D.new()
	container_shape.configure_open_cup(2.0, 4.0)
	var container := ContainerSnapshot2D.new()
	container.shape = container_shape
	container.world_transform = Transform2D.IDENTITY
	solver.set_container(container)
	var batch := ParticleSpawnBatch2D.new()
	var columns := 10
	for index: int in range(particle_count):
		var column := index % columns
		var row_from_bottom := index / columns
		batch.positions_meters.append(Vector2(
			-0.9 + float(column) * 0.20,
			3.9 - float(row_from_bottom) * 0.20
		))
		batch.colors_srgb.append(Color.RED if index < particle_count / 2 else Color.BLUE)
		batch.concentrations.append(1.0)
		batch.turbidities.append(0.78)
	solver.add_particles(batch)
	for _warmup: int in range(WARMUP_STEPS):
		solver.step(1.0 / 60.0)
	var total_ms := 0.0
	var phase_totals_ms := Vector4.ZERO
	var substep_total := 0
	for _sample: int in range(SAMPLE_STEPS):
		var started := Time.get_ticks_usec()
		var result := solver.step(1.0 / 60.0)
		total_ms += float(Time.get_ticks_usec() - started) / 1000.0
		substep_total += result.substeps
		phase_totals_ms += Vector4(
			float(result.profile_spatial_hash_microseconds),
			float(result.profile_density_microseconds),
			float(result.profile_forces_microseconds),
			float(result.profile_integration_microseconds)
		) / 1000.0
	var average_ms := total_ms / float(SAMPLE_STEPS)
	var average_substeps := float(substep_total) / float(SAMPLE_STEPS)
	var result := {
		"fixture": "lab_open_cup",
		"particle_count": particle_count,
		"average_ms": average_ms,
		"average_substeps": average_substeps,
		"profile_hash_ms": phase_totals_ms.x / float(SAMPLE_STEPS),
		"profile_density_ms": phase_totals_ms.y / float(SAMPLE_STEPS),
		"profile_forces_ms": phase_totals_ms.z / float(SAMPLE_STEPS),
		"profile_integration_ms": phase_totals_ms.w / float(SAMPLE_STEPS),
	}
	print("LAB_BENCHMARK particles=%d avg_ms=%.3f substeps=%.1f hash_ms=%.3f density_ms=%.3f forces_ms=%.3f integration_ms=%.3f" % [
		particle_count,
		average_ms,
		average_substeps,
		result["profile_hash_ms"],
		result["profile_density_ms"],
		result["profile_forces_ms"],
		result["profile_integration_ms"],
	])
	return result


func _run_case(particle_count: int) -> Dictionary:
	var config := ParticleFluidConfig2D.new()
	config.gravity_meters_per_second_squared = Vector2.ZERO
	config.fixed_test_substeps = 1
	config.max_substeps = 1
	config.smoothing_radius_meters = 0.06
	config.effective_depth_meters = 0.1
	config.particle_mass = 0.09
	config.gas_stiffness = 0.001
	config.dynamic_viscosity = 0.1
	config.color_diffusion = 0.0
	config.enable_step_profiling = true
	var solver := ParticleFluidSolver2D.new()
	solver.configure(config)
	var batch := ParticleSpawnBatch2D.new()
	var columns := ceili(sqrt(float(particle_count)))
	for index: int in range(particle_count):
		batch.positions_meters.append(Vector2(float(index % columns), float(index / columns)) * 0.03)
	solver.add_particles(batch)
	for _warmup: int in range(WARMUP_STEPS):
		solver.step(0.001)
	var samples := PackedFloat64Array()
	var neighbor_total := 0.0
	var phase_totals_ms := Vector4.ZERO
	for _sample: int in range(SAMPLE_STEPS):
		var started := Time.get_ticks_usec()
		var result := solver.step(0.001)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		neighbor_total += result.average_neighbor_count
		phase_totals_ms += Vector4(
			float(result.profile_spatial_hash_microseconds),
			float(result.profile_density_microseconds),
			float(result.profile_forces_microseconds),
			float(result.profile_integration_microseconds)
		) / 1000.0
	samples.sort()
	var average_ms := 0.0
	for sample: float in samples:
		average_ms += sample
	average_ms /= float(samples.size())
	var p99_index := mini(samples.size() - 1, maxi(0, ceili(float(samples.size()) * 0.99) - 1))
	var p99_ms := samples[p99_index]
	var peak_memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	var average_8ms_pass := average_ms <= 8.0
	var p99_16ms_pass := p99_ms <= 16.0
	var gate := "pass" if average_8ms_pass and p99_16ms_pass else "fail"
	var result := {
		"particle_count": particle_count,
		"average_ms": average_ms,
		"p99_ms": p99_ms,
		"average_neighbors": neighbor_total / float(SAMPLE_STEPS),
		"peak_memory_bytes": peak_memory_bytes,
		"profile_hash_ms": phase_totals_ms.x / float(SAMPLE_STEPS),
		"profile_density_ms": phase_totals_ms.y / float(SAMPLE_STEPS),
		"profile_forces_ms": phase_totals_ms.z / float(SAMPLE_STEPS),
		"profile_integration_ms": phase_totals_ms.w / float(SAMPLE_STEPS),
		"gate": gate,
		"average_8ms_pass": average_8ms_pass,
		"p99_16ms_pass": p99_16ms_pass,
	}
	print("BENCHMARK particles=%d avg_ms=%.3f p99_ms=%.3f neighbors=%.2f peak_bytes=%d avg_8ms=%s p99_16ms=%s gate=%s" % [
		particle_count,
		average_ms,
		p99_ms,
		result["average_neighbors"],
		peak_memory_bytes,
		average_8ms_pass,
		p99_16ms_pass,
		gate,
	])
	print("PROFILE particles=%d hash_ms=%.3f density_ms=%.3f forces_ms=%.3f integration_ms=%.3f" % [
		particle_count,
		result["profile_hash_ms"],
		result["profile_density_ms"],
		result["profile_forces_ms"],
		result["profile_integration_ms"],
	])
	return result
