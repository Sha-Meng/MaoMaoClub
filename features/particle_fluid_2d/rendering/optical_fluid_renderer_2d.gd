extends Node2D
class_name OpticalFluidRenderer2D

const MIN_FIELD_SIZE: int = 2
const MIN_BOUNDS_SIZE_PIXELS: float = 1.0

@export var field_resolution: Vector2i = Vector2i(160, 256)
@export var particle_diameter_pixels: float = 16.0
@export var bounds_padding_pixels: float = 20.0
@export var thickness_per_particle: float = 0.32
@export var clear_liquid_extinction: float = 0.18
@export var ambient_scatter_strength: float = 0.62
@export var opacity_scale: float = 2.4
@export var optical_path_scale: float = 0.9
@export var refraction_pixels: float = 2.0
@export var normal_strength: float = 5.0
@export var color_steps: float = 24.0
@export_range(0.0, 12.0, 0.25) var hole_closing_radius_texels: float = 10.0
@export_range(0.0, 1.0, 0.05) var hole_closing_strength: float = 1.0

var _field_viewport: SubViewport
var _field_particles: MultiMeshInstance2D
var _composite: Sprite2D
var _splat_mesh: QuadMesh
var _accumulation_material: ShaderMaterial
var _composite_material: ShaderMaterial
var _render_bounds_world_pixels: Rect2 = Rect2()
var _instance_capacity: int = 0

func _ready() -> void:
	_ensure_resources()

func update_snapshot(
	snapshot: ParticleFluidSnapshot2D,
	pixels_per_meter: float,
	world_bounds_pixels: Rect2 = Rect2(),
	container_snapshot: ContainerSnapshot2D = null
) -> void:
	_ensure_resources()
	if snapshot == null or snapshot.count() == 0:
		_field_particles.multimesh.visible_instance_count = 0
		_composite.visible = false
		_field_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var bounds := world_bounds_pixels
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = _calculate_snapshot_bounds(snapshot, pixels_per_meter)
	else:
		bounds = bounds.grow(bounds_padding_pixels)
	_apply_render_bounds(_sanitize_bounds(bounds))
	_update_container_clip(container_snapshot, pixels_per_meter)
	_ensure_instance_capacity(snapshot.count())
	_field_particles.multimesh.visible_instance_count = snapshot.count()
	var field_size := Vector2(field_resolution)
	var particle_scale := Vector2(
		particle_diameter_pixels / _render_bounds_world_pixels.size.x * field_size.x,
		particle_diameter_pixels / _render_bounds_world_pixels.size.y * field_size.y
	)
	var refraction_sum := 0.0
	var specular_sum := 0.0
	for index: int in range(snapshot.count()):
		var world_position_pixels := snapshot.positions_meters[index] * pixels_per_meter
		var normalized_position := (
			world_position_pixels - _render_bounds_world_pixels.position
		) / _render_bounds_world_pixels.size
		var field_position := normalized_position * field_size
		var transform := Transform2D(
			Vector2(particle_scale.x, 0.0),
			Vector2(0.0, particle_scale.y),
			field_position
		)
		_field_particles.multimesh.set_instance_transform_2d(index, transform)
		var optical := snapshot.optical_densities[index]
		var turbidity := snapshot.turbidities[index]
		_field_particles.multimesh.set_instance_custom_data(index, Color(
			maxf(optical.x, 0.0),
			maxf(optical.y, 0.0),
			maxf(optical.z, 0.0),
			maxf(turbidity, 0.0)
		))
		if index < snapshot.refractive_strengths.size():
			refraction_sum += snapshot.refractive_strengths[index]
		if index < snapshot.specular_strengths.size():
			specular_sum += snapshot.specular_strengths[index]
	var inverse_count := 1.0 / float(snapshot.count())
	_composite_material.set_shader_parameter(&"refraction_strength", refraction_sum * inverse_count)
	_composite_material.set_shader_parameter(&"specular_strength", specular_sum * inverse_count)
	_composite.visible = true
	_field_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func get_active_instance_count() -> int:
	if _field_particles == null or _field_particles.multimesh == null:
		return 0
	return maxi(_field_particles.multimesh.visible_instance_count, 0)

func get_render_bounds_world_pixels() -> Rect2:
	return _render_bounds_world_pixels

func _ensure_resources() -> void:
	if _field_viewport != null:
		return
	field_resolution.x = maxi(field_resolution.x, MIN_FIELD_SIZE)
	field_resolution.y = maxi(field_resolution.y, MIN_FIELD_SIZE)
	_field_viewport = SubViewport.new()
	_field_viewport.name = "OpticalFieldViewport"
	_field_viewport.size = field_resolution
	_field_viewport.disable_3d = true
	_field_viewport.transparent_bg = true
	_field_viewport.use_hdr_2d = true
	_field_viewport.world_2d = World2D.new()
	_field_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_field_viewport)
	_splat_mesh = QuadMesh.new()
	_splat_mesh.size = Vector2.ONE
	var particle_multimesh := MultiMesh.new()
	particle_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	particle_multimesh.use_custom_data = true
	particle_multimesh.mesh = _splat_mesh
	particle_multimesh.instance_count = 0
	_field_particles = MultiMeshInstance2D.new()
	_field_particles.name = "OpticalFieldParticles"
	_field_particles.multimesh = particle_multimesh
	_accumulation_material = ShaderMaterial.new()
	_accumulation_material.shader = _make_accumulation_shader()
	_accumulation_material.set_shader_parameter(&"thickness_per_particle", thickness_per_particle)
	_accumulation_material.set_shader_parameter(&"clear_liquid_extinction", clear_liquid_extinction)
	_field_particles.material = _accumulation_material
	_field_viewport.add_child(_field_particles)
	_composite = Sprite2D.new()
	_composite.name = "OpticalComposite"
	_composite.centered = false
	_composite.texture = _field_viewport.get_texture()
	_composite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_composite.visible = false
	_composite_material = ShaderMaterial.new()
	_composite_material.shader = _make_composite_shader()
	_composite_material.set_shader_parameter(&"optical_field", _field_viewport.get_texture())
	_composite_material.set_shader_parameter(&"optical_field_texel_size", Vector2.ONE / Vector2(field_resolution))
	_composite_material.set_shader_parameter(&"opacity_scale", opacity_scale)
	_composite_material.set_shader_parameter(&"optical_path_scale", optical_path_scale)
	_composite_material.set_shader_parameter(&"refraction_pixels", refraction_pixels)
	_composite_material.set_shader_parameter(&"normal_strength", normal_strength)
	_composite_material.set_shader_parameter(&"color_steps", color_steps)
	_composite_material.set_shader_parameter(&"hole_closing_radius_texels", hole_closing_radius_texels)
	_composite_material.set_shader_parameter(&"hole_closing_strength", hole_closing_strength)
	_composite.material = _composite_material
	_composite_material.set_shader_parameter(&"ambient_scatter_strength", ambient_scatter_strength)
	add_child(_composite)

func _ensure_instance_capacity(required: int) -> void:
	if required <= _instance_capacity:
		return
	var new_capacity := maxi(16, _instance_capacity)
	while new_capacity < required:
		new_capacity *= 2
	_field_particles.multimesh.instance_count = new_capacity
	_instance_capacity = new_capacity

func _calculate_snapshot_bounds(
	snapshot: ParticleFluidSnapshot2D,
	pixels_per_meter: float
) -> Rect2:
	var first_position := snapshot.positions_meters[0] * pixels_per_meter
	var bounds := Rect2(first_position, Vector2.ZERO)
	for index: int in range(1, snapshot.count()):
		bounds = bounds.expand(snapshot.positions_meters[index] * pixels_per_meter)
	return bounds.grow(bounds_padding_pixels + particle_diameter_pixels * 0.5)

func _sanitize_bounds(bounds: Rect2) -> Rect2:
	var safe_bounds := bounds
	if safe_bounds.size.x < MIN_BOUNDS_SIZE_PIXELS:
		safe_bounds.position.x -= (MIN_BOUNDS_SIZE_PIXELS - safe_bounds.size.x) * 0.5
		safe_bounds.size.x = MIN_BOUNDS_SIZE_PIXELS
	if safe_bounds.size.y < MIN_BOUNDS_SIZE_PIXELS:
		safe_bounds.position.y -= (MIN_BOUNDS_SIZE_PIXELS - safe_bounds.size.y) * 0.5
		safe_bounds.size.y = MIN_BOUNDS_SIZE_PIXELS
	return safe_bounds

func _apply_render_bounds(bounds: Rect2) -> void:
	_render_bounds_world_pixels = bounds
	_composite.position = bounds.position
	_composite.scale = bounds.size / Vector2(field_resolution)
	_composite_material.set_shader_parameter(&"render_bounds_origin_pixels", bounds.position)
	_composite_material.set_shader_parameter(&"render_bounds_size_pixels", bounds.size)


func _update_container_clip(
	container_snapshot: ContainerSnapshot2D,
	pixels_per_meter: float
) -> void:
	var clip_enabled := (
		container_snapshot != null
		and container_snapshot.shape != null
		and container_snapshot.shape.is_closed
		and container_snapshot.shape.segment_count() > 0
	)
	_composite_material.set_shader_parameter(&"clip_closed_container", clip_enabled)
	if not clip_enabled:
		return
	var shape := container_snapshot.shape
	var first := shape.segment_starts_local_meters[0] * pixels_per_meter
	var local_bounds := Rect2(first, Vector2.ZERO)
	for index: int in range(shape.segment_count()):
		local_bounds = local_bounds.expand(shape.segment_starts_local_meters[index] * pixels_per_meter)
		local_bounds = local_bounds.expand(shape.segment_ends_local_meters[index] * pixels_per_meter)
	var rotation := container_snapshot.world_transform.get_rotation()
	_composite_material.set_shader_parameter(
		&"container_origin_world_pixels",
		container_snapshot.world_transform.origin * pixels_per_meter
	)
	_composite_material.set_shader_parameter(&"container_inverse_rotation", Vector2(cos(rotation), sin(rotation)))
	_composite_material.set_shader_parameter(&"container_local_min_pixels", local_bounds.position)
	_composite_material.set_shader_parameter(&"container_local_max_pixels", local_bounds.end)

func _make_accumulation_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float thickness_per_particle = 0.32;
uniform float clear_liquid_extinction = 0.18;
varying vec4 optical_data;

void vertex() {
	optical_data = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 centered = UV * 2.0 - vec2(1.0);
	float radius = length(centered);
	float weight = 1.0 - smoothstep(0.58, 1.0, radius);
	float thickness = thickness_per_particle * weight;
	float effective_extinction = max(optical_data.a, clear_liquid_extinction);
	float accumulated_extinction = thickness * effective_extinction;
	// Canvas blend_add 会用源 alpha 预乘 RGBA。用平方根编码 alpha，并反向补偿
	// RGB，混合后的目标纹理才能得到线性累积的吸光度和有效厚度。
	float storage_alpha = sqrt(max(accumulated_extinction, 0.0));
	vec3 stored_optical = (
		max(optical_data.rgb, vec3(0.0)) * thickness / max(storage_alpha, 0.001)
	);
	COLOR = vec4(stored_optical, storage_alpha);
}
"""
	return shader

func _make_composite_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D optical_field : repeat_disable, filter_nearest;
uniform vec2 optical_field_texel_size = vec2(0.00625, 0.00390625);
uniform float opacity_scale = 2.4;
uniform float optical_path_scale = 0.9;
uniform float refraction_pixels = 2.0;
uniform float refraction_strength = 0.35;
uniform float normal_strength = 5.0;
uniform float specular_strength = 0.3;
uniform float color_steps = 24.0;
uniform float ambient_scatter_strength = 0.62;
uniform float hole_closing_radius_texels = 10.0;
uniform float hole_closing_strength = 1.0;
uniform bool clip_closed_container = false;
uniform vec2 render_bounds_origin_pixels = vec2(0.0);
uniform vec2 render_bounds_size_pixels = vec2(1.0);
uniform vec2 container_origin_world_pixels = vec2(0.0);
uniform vec2 container_inverse_rotation = vec2(1.0, 0.0);
uniform vec2 container_local_min_pixels = vec2(0.0);
uniform vec2 container_local_max_pixels = vec2(1.0);

vec4 bridge_pair(vec4 first, vec4 second) {
	float supported = step(0.004, first.a) * step(0.004, second.a);
	float bridge_alpha = (first.a + second.a) * 0.5 * hole_closing_strength * supported;
	return vec4((first.rgb + second.rgb) * 0.5, bridge_alpha);
}

vec4 keep_stronger(vec4 current, vec4 candidate) {
	return mix(current, candidate, step(current.a, candidate.a));
}

vec4 reconstruct_field(vec2 uv) {
	vec4 center = texture(optical_field, uv);
	vec4 reconstructed = center;
	if (hole_closing_radius_texels <= 0.0) {
		return reconstructed;
	}
	vec2 far_axis = optical_field_texel_size * hole_closing_radius_texels;
	vec2 far_diagonal = far_axis * 0.70710678;
	vec2 near_axis = far_axis * 0.5;
	vec2 near_diagonal = far_diagonal * 0.5;
	vec4 near_left = texture(optical_field, uv - vec2(near_axis.x, 0.0));
	vec4 near_right = texture(optical_field, uv + vec2(near_axis.x, 0.0));
	vec4 near_up = texture(optical_field, uv - vec2(0.0, near_axis.y));
	vec4 near_down = texture(optical_field, uv + vec2(0.0, near_axis.y));
	vec4 near_northwest = texture(optical_field, uv - near_diagonal);
	vec4 near_southeast = texture(optical_field, uv + near_diagonal);
	vec4 near_northeast = texture(optical_field, uv + vec2(near_diagonal.x, -near_diagonal.y));
	vec4 near_southwest = texture(optical_field, uv + vec2(-near_diagonal.x, near_diagonal.y));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		near_left,
		near_right
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		near_up,
		near_down
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		near_northwest,
		near_southeast
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		near_northeast,
		near_southwest
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		texture(optical_field, uv - vec2(far_axis.x, 0.0)),
		texture(optical_field, uv + vec2(far_axis.x, 0.0))
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		texture(optical_field, uv - vec2(0.0, far_axis.y)),
		texture(optical_field, uv + vec2(0.0, far_axis.y))
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		texture(optical_field, uv - far_diagonal),
		texture(optical_field, uv + far_diagonal)
	));
	reconstructed = keep_stronger(reconstructed, bridge_pair(
		texture(optical_field, uv + vec2(far_diagonal.x, -far_diagonal.y)),
		texture(optical_field, uv + vec2(-far_diagonal.x, far_diagonal.y))
	));
	float center_weight = step(0.004, center.a);
	float left_weight = step(0.004, near_left.a);
	float right_weight = step(0.004, near_right.a);
	float up_weight = step(0.004, near_up.a);
	float down_weight = step(0.004, near_down.a);
	float northwest_weight = step(0.004, near_northwest.a);
	float southeast_weight = step(0.004, near_southeast.a);
	float northeast_weight = step(0.004, near_northeast.a);
	float southwest_weight = step(0.004, near_southwest.a);
	float neighborhood_weight = center_weight + left_weight + right_weight + up_weight
		+ down_weight + northwest_weight + southeast_weight + northeast_weight + southwest_weight;
	if (reconstructed.a > 0.004 && neighborhood_weight > 0.0) {
		vec4 neighborhood = (
			center * center_weight
			+ near_left * left_weight
			+ near_right * right_weight
			+ near_up * up_weight
			+ near_down * down_weight
			+ near_northwest * northwest_weight
			+ near_southeast * southeast_weight
			+ near_northeast * northeast_weight
			+ near_southwest * southwest_weight
		) / neighborhood_weight;
		reconstructed.rgb = mix(reconstructed.rgb, neighborhood.rgb, 0.65);
		reconstructed.a = max(reconstructed.a, neighborhood.a * 0.9);
	}
	return reconstructed;
}

void fragment() {
	if (clip_closed_container) {
		vec2 world_pixels = render_bounds_origin_pixels + UV * render_bounds_size_pixels;
		vec2 offset = world_pixels - container_origin_world_pixels;
		vec2 local_pixels = vec2(
			container_inverse_rotation.x * offset.x + container_inverse_rotation.y * offset.y,
			-container_inverse_rotation.y * offset.x + container_inverse_rotation.x * offset.y
		);
		if (
			local_pixels.x < container_local_min_pixels.x
			|| local_pixels.x > container_local_max_pixels.x
			|| local_pixels.y < container_local_min_pixels.y
			|| local_pixels.y > container_local_max_pixels.y
		) {
			discard;
		}
	}
	vec4 field = reconstruct_field(UV);
	if (field.a <= 0.001) {
		discard;
	}
	float left = texture(optical_field, UV - vec2(optical_field_texel_size.x, 0.0)).a;
	float right = texture(optical_field, UV + vec2(optical_field_texel_size.x, 0.0)).a;
	float up = texture(optical_field, UV - vec2(0.0, optical_field_texel_size.y)).a;
	float down = texture(optical_field, UV + vec2(0.0, optical_field_texel_size.y)).a;
	vec2 gradient = vec2(right - left, down - up);
	vec3 normal = normalize(vec3(-gradient * normal_strength, 1.0));
	vec2 refracted_uv = SCREEN_UV + normal.xy * SCREEN_PIXEL_SIZE * refraction_pixels * refraction_strength;
	vec3 background = texture(screen_texture, refracted_uv).rgb;
	vec3 transmittance = exp(-max(field.rgb, vec3(0.0)) * optical_path_scale);
	float coverage = 1.0 - exp(-field.a * opacity_scale);
	vec3 transmitted = background * transmittance;
	float rim = pow(clamp(1.0 - normal.z, 0.0, 1.0), 2.0);
	float directional = pow(max(dot(normal.xy, normalize(vec2(-0.6, -0.8))), 0.0), 6.0);
	vec3 highlight = vec3((rim * 0.35 + directional * 0.28) * specular_strength);
	// 纯透射在暗色背景上几乎没有可染色的入射光。这里加入受覆盖率约束的
	// 单次环境散射近似，让透明有色液体在像素风暗场景中仍保持可读轮廓。
	vec3 scattered_tint = pow(clamp(transmittance, vec3(0.0), vec3(1.0)), vec3(0.72));
	float scattering = coverage * ambient_scatter_strength * (0.72 + 0.28 * clamp(field.a, 0.0, 1.0));
	vec3 scattered = scattered_tint * scattering * (vec3(1.0) - background * 0.35);
	vec3 composed = mix(background, transmitted + highlight, coverage) + scattered;
	if (color_steps > 1.0) {
		composed = floor(composed * color_steps + vec3(0.5)) / color_steps;
	}
	COLOR = vec4(clamp(composed, vec3(0.0), vec3(1.0)), 1.0);
}
"""
	return shader
