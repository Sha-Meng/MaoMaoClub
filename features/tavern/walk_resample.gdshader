shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D poses : filter_linear, repeat_disable;
uniform sampler2D motion : filter_linear, repeat_disable;

vec2 sample_uv(float cell, vec2 p) {
	return vec2((cell + clamp(p.x, 0.0015625, 0.9984375)) / 8.0, clamp(p.y, 0.0020833, 0.9979167));
}

void fragment() {
	vec2 grid = UV * vec2(8.0, 4.0);
	float index = floor(grid.y) * 8.0 + floor(grid.x);
	vec2 local = fract(grid);
	float phase = index / 4.0;
	float first = floor(phase);
	float second = mod(first + 1.0, 8.0);
	// Constant-speed interpolation; wrap 7 -> 0 exactly like other pairs.
	float amount = fract(phase);
	// Bidirectional motion compensation keeps each moving paw in one place.
	// Plain crossfading creates two feet/hands halfway between paintings.
	vec2 from_a = local;
	vec2 from_b = local;
	// A single inverse estimate avoids folding the displacement field back over
	// itself near crossing feet, which otherwise duplicates a detached shoe.
	for (int iteration = 0; iteration < 1; iteration++) {
		from_a = local - amount * texture(motion, sample_uv(first, from_a)).rg;
		from_b = local - (1.0 - amount) * texture(motion, sample_uv(first, from_b)).ba;
	}
	vec4 a = texture(poses, sample_uv(first, from_a));
	vec4 b = texture(poses, sample_uv(second, from_b));
	// Viewport colors are premultiplied. Resolve alpha once, so the torso does
	// not pulse darker and transparent RGB cannot contaminate its outline.
	vec4 blended = mix(a, b, amount);
	COLOR = vec4(blended.rgb / max(blended.a, 0.00001), blended.a);
}
