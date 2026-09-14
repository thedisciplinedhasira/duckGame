shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

// Hand-drawn depth-edge outline + soft toon shading, screen-space post process.
// Same core technique as before (depth Laplacian edge detection), extended with
// pressure-style stroke variation, dry-brush breakup, and an optional dual-tone ink.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Handdrawn_Outlines;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.1;
uniform float line_threshold : hint_range(0.2, 5.0) = 1.2;
uniform float min_depth_gap : hint_range(0.01, 1.0) = 0.25;
uniform float line_wobble : hint_range(0.0, 4.0) = 1.0;

group_uniforms Ink_Color;
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.14, 1.0); // silhouette / strong edges
uniform vec4 line_color_secondary : source_color = vec4(0.45, 0.08, 0.08, 1.0); // interior / soft edges
uniform float secondary_edge_bias : hint_range(0.0, 1.0) = 0.0; // 0 = single color like before, 1 = full dual-tone

group_uniforms Stroke_Variation;
uniform float stroke_thickness_variation : hint_range(0.0, 1.0) = 0.35;
uniform float stroke_variation_scale : hint_range(1.0, 20.0) = 6.0;
uniform float ink_grain_strength : hint_range(0.0, 1.0) = 0.15;

group_uniforms Subtle_Toon;
uniform float toon_blend : hint_range(0.0, 1.0) = 0.35;
uniform int toon_steps : hint_range(6, 32) = 14;

varying vec4 v_inv_proj_z;
varying vec4 v_inv_proj_w;

// Only the Z and W rows of the inverse projection matrix are needed to get
// linear view-space depth back out of the depth buffer. Godot matrices are
// column-major, so m[column][row].
float get_linear_depth(vec2 uv, vec4 inv_proj_z, vec4 inv_proj_w) {
	float raw_depth = texture(depth_texture, uv).x;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	float view_z = dot(inv_proj_z, ndc);
	float view_w = dot(inv_proj_w, ndc);
	return -(view_z / view_w);
}

// cheap hash, no sin() so it doesn't band on some GPUs
float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// smooth value noise built from 4 hashed corners. used for stroke thickness
// and the dry-brush grain below. cheap: 4 hash calls + a couple mixes.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// full-screen triangle pinned straight to clip space
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);

	// INV_PROJECTION_MATRIX doesn't change across this draw call, so build the
	// two rows we need here (runs 3 times) instead of in fragment() (runs once
	// per pixel on screen). Same math as before, just hoisted up a stage.
	v_inv_proj_z = vec4(INV_PROJECTION_MATRIX[0].z, INV_PROJECTION_MATRIX[1].z, INV_PROJECTION_MATRIX[2].z, INV_PROJECTION_MATRIX[3].z);
	v_inv_proj_w = vec4(INV_PROJECTION_MATRIX[0].w, INV_PROJECTION_MATRIX[1].w, INV_PROJECTION_MATRIX[2].w, INV_PROJECTION_MATRIX[3].w);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base_color = texture(screen_texture, uv).rgb;

	float depth = get_linear_depth(uv, v_inv_proj_z, v_inv_proj_w);

	// posterize, but keep a floor under it so shadows don't crush to pure black
	float steps = float(toon_steps);
	vec3 toon_color = floor(base_color * steps + 0.5) / steps;
	toon_color = max(toon_color, base_color * 0.45);
	vec3 shaded_color = mix(base_color, toon_color, toon_blend);

	vec2 texel = 1.0 / VIEWPORT_SIZE;

	// fast per-pixel jitter — this is what makes the stroke path itself look shaky
	vec2 hash_seed = uv * 120.0;
	vec2 stroke_jitter = vec2(hash(hash_seed) - 0.5, hash(hash_seed + vec2(15.0, 27.0)) - 0.5);
	stroke_jitter *= texel * line_wobble;

	// slow-moving noise — this is what gives the stroke a pressure-varying width
	// instead of a constant pixel thickness everywhere
	float thickness_noise = value_noise(uv * stroke_variation_scale);
	float thickness_mult = mix(1.0, mix(0.4, 1.7, thickness_noise), stroke_thickness_variation);
	float thickness = line_thickness * thickness_mult;

	vec2 offset = thickness * texel + stroke_jitter;

	float d_c = depth;
	float d_u = get_linear_depth(uv + vec2(0.0, -offset.y), v_inv_proj_z, v_inv_proj_w);
	float d_d = get_linear_depth(uv + vec2(0.0, offset.y), v_inv_proj_z, v_inv_proj_w);
	float d_l = get_linear_depth(uv + vec2(-offset.x, 0.0), v_inv_proj_z, v_inv_proj_w);
	float d_r = get_linear_depth(uv + vec2(offset.x, 0.0), v_inv_proj_z, v_inv_proj_w);

	float delta_r = abs(d_r - d_c);
	float delta_l = abs(d_c - d_l);
	float delta_d = abs(d_d - d_c);
	float delta_u = abs(d_c - d_u);
	float max_delta = max(max(delta_r, delta_l), max(delta_d, delta_u));

	float laplacian_x = abs((d_r - d_c) - (d_c - d_l));
	float laplacian_y = abs((d_d - d_c) - (d_c - d_u));
	float edge = (laplacian_x + laplacian_y) / (d_c * 0.03 + 0.001);

	float valid_depth = step(min_depth_gap, max_delta) * step(depth, 200.0);
	edge *= valid_depth;

	float is_edge = smoothstep(line_threshold, line_threshold + 0.2, edge);

	// dry-brush breakup — keeps the stroke from reading as a perfectly clean vector line
	float grain = value_noise(uv * 45.0 + 100.0);
	is_edge *= mix(1.0, 0.5 + 0.5 * grain, ink_grain_strength);

	// dual-tone ink: strong silhouette edges (duck vs. sky, tree vs. rock) stay the
	// primary color; softer interior edges (creases, thin far branches) can lean
	// toward a second color. off by default (secondary_edge_bias = 0.0).
	float edge_strength = clamp(max_delta / (min_depth_gap * 4.0), 0.0, 1.0);
	float soft_amount = (1.0 - edge_strength) * secondary_edge_bias;
	vec4 ink_color = mix(line_color, line_color_secondary, soft_amount);

	ALBEDO = mix(shaded_color, ink_color.rgb, is_edge * ink_color.a);
}
