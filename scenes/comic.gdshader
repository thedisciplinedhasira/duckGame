shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Handdrawn_Outlines;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.1;
uniform float line_threshold : hint_range(0.2, 5.0) = 1.2;
uniform float min_depth_gap : hint_range(0.01, 1.0) = 0.25;
uniform float line_wobble : hint_range(0.0, 4.0) = 1.0;
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.14, 1.0);

group_uniforms Subtle_Toon;
uniform float toon_blend : hint_range(0.0, 1.0) = 0.35;
uniform int toon_steps : hint_range(6, 32) = 14;


// Only the Z and W rows of INV_PROJECTION_MATRIX are needed.
// Godot matrices use column-major indexing: m[column][row].
float get_linear_depth(
	vec2 uv,
	vec4 inv_proj_z,
	vec4 inv_proj_w
) {
	float raw_depth = texture(depth_texture, uv).x;

	vec4 ndc = vec4(
		uv * 2.0 - 1.0,
		raw_depth,
		1.0
	);

	float view_z = dot(inv_proj_z, ndc);
	float view_w = dot(inv_proj_w, ndc);

	return -(view_z / view_w);
}


// Sin-free hash.
// Different sequence from the original hash, but visually equivalent.
float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}


void vertex() {
	// Pins quad directly to clip space across the full viewport.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


void fragment() {
	vec2 uv = SCREEN_UV;

	// ------------------------------------------------------------
	// 1. Base screen color
	// ------------------------------------------------------------
	vec3 base_color = texture(screen_texture, uv).rgb;


	// ------------------------------------------------------------
	// 2. Cache only the two projection-matrix rows we actually need
	// ------------------------------------------------------------
	vec4 inv_proj_z = vec4(
		INV_PROJECTION_MATRIX[0].z,
		INV_PROJECTION_MATRIX[1].z,
		INV_PROJECTION_MATRIX[2].z,
		INV_PROJECTION_MATRIX[3].z
	);

	vec4 inv_proj_w = vec4(
		INV_PROJECTION_MATRIX[0].w,
		INV_PROJECTION_MATRIX[1].w,
		INV_PROJECTION_MATRIX[2].w,
		INV_PROJECTION_MATRIX[3].w
	);


	// ------------------------------------------------------------
	// 3. Center depth
	// ------------------------------------------------------------
	float depth = get_linear_depth(
		uv,
		inv_proj_z,
		inv_proj_w
	);


	// ------------------------------------------------------------
	// 4. Soft Toon Quantization
	// ------------------------------------------------------------
	float steps = float(toon_steps);

	vec3 toon_color =
		floor(base_color * steps + 0.5) / steps;

	toon_color =
		max(toon_color, base_color * 0.45);

	vec3 shaded_color =
		mix(base_color, toon_color, toon_blend);


	// ------------------------------------------------------------
	// 5. Screen pixel size
	// ------------------------------------------------------------
	// VIEWPORT_SIZE is already supplied by Godot, so there is
	// no textureSize() query here.
	vec2 texel = 1.0 / VIEWPORT_SIZE;


	// ------------------------------------------------------------
	// 6. Wobble jitter
	// ------------------------------------------------------------
	vec2 hash_seed = uv * 120.0;

	vec2 stroke_jitter = vec2(
		hash(hash_seed) - 0.5,
		hash(hash_seed + vec2(15.0, 27.0)) - 0.5
	);

	stroke_jitter *= texel * line_wobble;


	// ------------------------------------------------------------
	// 7. Outline sampling
	// ------------------------------------------------------------
	vec2 offset =
		line_thickness * texel +
		stroke_jitter;

	float d_c = depth;

	float d_u = get_linear_depth(
		uv + vec2(0.0, -offset.y),
		inv_proj_z,
		inv_proj_w
	);

	float d_d = get_linear_depth(
		uv + vec2(0.0, offset.y),
		inv_proj_z,
		inv_proj_w
	);

	float d_l = get_linear_depth(
		uv + vec2(-offset.x, 0.0),
		inv_proj_z,
		inv_proj_w
	);

	float d_r = get_linear_depth(
		uv + vec2(offset.x, 0.0),
		inv_proj_z,
		inv_proj_w
	);


	// ------------------------------------------------------------
	// 8. Depth edge detection
	// ------------------------------------------------------------
	float delta_r = abs(d_r - d_c);
	float delta_l = abs(d_c - d_l);
	float delta_d = abs(d_d - d_c);
	float delta_u = abs(d_c - d_u);

	float max_delta = max(
		max(delta_r, delta_l),
		max(delta_d, delta_u)
	);

	float laplacian_x =
		abs((d_r - d_c) - (d_c - d_l));

	float laplacian_y =
		abs((d_d - d_c) - (d_c - d_u));

	float edge =
		(laplacian_x + laplacian_y) /
		(d_c * 0.03 + 0.001);


	// ------------------------------------------------------------
	// 9. Branchless suppression
	// ------------------------------------------------------------
	float valid_depth =
		step(min_depth_gap, max_delta) *
		step(depth, 200.0);

	edge *= valid_depth;


	// ------------------------------------------------------------
	// 10. Final outline
	// ------------------------------------------------------------
	float is_edge =
		smoothstep(
			line_threshold,
			line_threshold + 0.2,
			edge
		);

	ALBEDO =
		mix(
			shaded_color,
			line_color.rgb,
			is_edge * line_color.a
		);
}