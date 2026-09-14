shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

// Graphite pencil / concept-art sketch look, screen-space post process.
// Desaturates the scene but lets strongly saturated pixels (glows, magic, whatever)
// punch back through, maps the rest onto a paper/ink duotone, shades it with
// procedural crosshatching instead of flat toon bands, and outlines depth edges
// with a clean pass plus a looser "construction line" retrace pass for that
// sketched-twice look. Paper grain and a soft vignette on top.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Sketch_Lines;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.0;
uniform float line_threshold : hint_range(0.2, 5.0) = 1.0;
uniform float min_depth_gap : hint_range(0.01, 1.0) = 0.2;
uniform float line_wobble : hint_range(0.0, 4.0) = 1.2;
uniform float retrace_strength : hint_range(0.0, 1.0) = 0.5; // opacity of the second, looser pencil pass
uniform float retrace_offset_scale : hint_range(1.0, 3.0) = 1.6; // how far the retrace sits from the clean line

group_uniforms Crosshatch_Shading;
uniform float hatch_spacing : hint_range(2.0, 20.0) = 6.0; // pixels between hatch lines
uniform float hatch_thickness : hint_range(0.5, 3.0) = 1.0; // pixels
uniform float hatch_angle_1 : hint_range(-3.14, 3.14) = 0.785;
uniform float hatch_angle_2 : hint_range(-3.14, 3.14) = -0.785;
uniform float hatch_wobble : hint_range(0.0, 10.0) = 3.0; // pixels of hand-drawn waver
uniform float shadow_threshold_1 : hint_range(0.0, 1.0) = 0.75; // hatching starts below this brightness
uniform float shadow_threshold_2 : hint_range(0.0, 1.0) = 0.5; // crosshatch (2nd angle) starts here
uniform float shadow_threshold_3 : hint_range(0.0, 1.0) = 0.25; // dense fine crosshatch for deep shadow
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.8;

group_uniforms Graphite_Tone;
uniform vec4 paper_color : source_color = vec4(0.93, 0.92, 0.88, 1.0);
uniform vec4 ink_color : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform float desaturation_amount : hint_range(0.0, 1.0) = 0.9;
uniform float color_pop_threshold : hint_range(0.0, 1.0) = 0.35; // saturation needed before color survives
uniform float color_pop_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms Paper_Texture;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
uniform float grain_scale : hint_range(0.1, 4.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

varying vec4 v_inv_proj_z;
varying vec4 v_inv_proj_w;

float get_linear_depth(vec2 uv, vec4 inv_proj_z, vec4 inv_proj_w) {
	float raw_depth = texture(depth_texture, uv).x;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	float view_z = dot(inv_proj_z, ndc);
	float view_w = dot(inv_proj_w, ndc);
	return -(view_z / view_w);
}

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

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

// one hatch layer: a family of parallel lines at "angle", spaced "spacing" px apart,
// with a slow noise wobble along their length so they read as drawn, not ruled.
float hatch_pass(vec2 pixel_coord, float angle, float spacing, float thickness, float wobble_amount, float seed) {
	float s = sin(angle);
	float c = cos(angle);
	float coord = pixel_coord.x * c - pixel_coord.y * s;
	float along = pixel_coord.x * s + pixel_coord.y * c;
	coord += (value_noise(vec2(along * 0.02, seed)) - 0.5) * wobble_amount;
	float line_pos = mod(coord, spacing);
	float dist_to_line = min(line_pos, spacing - line_pos);
	return 1.0 - smoothstep(thickness - 1.0, thickness + 1.0, dist_to_line);
}

// depth-edge test at a given center depth + sample offset, reused for both the
// clean line pass and the looser retrace pass so the center depth isn't resampled twice.
float compute_edge(vec2 uv, float d_c, vec2 offset) {
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

	float valid_depth = step(min_depth_gap, max_delta) * step(d_c, 200.0);
	return edge * valid_depth;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);

	// INV_PROJECTION_MATRIX is constant for the whole draw call, so build the two
	// rows we need here (3 vertices) instead of in fragment() (every pixel on screen).
	v_inv_proj_z = vec4(INV_PROJECTION_MATRIX[0].z, INV_PROJECTION_MATRIX[1].z, INV_PROJECTION_MATRIX[2].z, INV_PROJECTION_MATRIX[3].z);
	v_inv_proj_w = vec4(INV_PROJECTION_MATRIX[0].w, INV_PROJECTION_MATRIX[1].w, INV_PROJECTION_MATRIX[2].w, INV_PROJECTION_MATRIX[3].w);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base_color = texture(screen_texture, uv).rgb;
	float depth = get_linear_depth(uv, v_inv_proj_z, v_inv_proj_w);

	// pull most of the color out, but let strongly saturated pixels (glows etc) survive
	vec3 gray = vec3(dot(base_color, vec3(0.299, 0.587, 0.114)));
	vec3 desat_color = mix(base_color, gray, desaturation_amount);
	float sat = max(max(base_color.r, base_color.g), base_color.b) - min(min(base_color.r, base_color.g), base_color.b);
	float pop = smoothstep(color_pop_threshold, color_pop_threshold + 0.2, sat) * color_pop_strength;
	vec3 toned_color = mix(desat_color, base_color, pop);

	// map the grayscale part onto a paper/ink duotone, leave the popped color alone
	float lum = dot(toned_color, vec3(0.299, 0.587, 0.114));
	vec3 duotone = mix(ink_color.rgb, paper_color.rgb, lum);
	vec3 shaded_color = mix(duotone, toned_color, pop);

	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec2 pixel_coord = uv * VIEWPORT_SIZE;

	// three-pass crosshatch: gets denser and starts crossing as it gets darker
	float hatch1 = hatch_pass(pixel_coord, hatch_angle_1, hatch_spacing, hatch_thickness, hatch_wobble, 0.0) * step(lum, shadow_threshold_1);
	float hatch2 = hatch_pass(pixel_coord, hatch_angle_2, hatch_spacing, hatch_thickness, hatch_wobble, 17.0) * step(lum, shadow_threshold_2);
	float hatch3 = hatch_pass(pixel_coord, hatch_angle_1, hatch_spacing * 0.5, hatch_thickness, hatch_wobble, 41.0) * step(lum, shadow_threshold_3);
	float hatch_mask = clamp(hatch1 + hatch2 + hatch3, 0.0, 1.0);
	shaded_color = mix(shaded_color, ink_color.rgb, hatch_mask * hatch_strength);

	// paper tooth
	float grain = hash(uv * VIEWPORT_SIZE * grain_scale * 0.5);
	shaded_color = mix(shaded_color, shaded_color * (0.7 + 0.6 * grain), grain_strength);

	// soft dark corners
	float dist_from_center = distance(uv, vec2(0.5));
	float vignette = 1.0 - smoothstep(0.3, 0.75, dist_from_center) * vignette_strength;
	shaded_color *= vignette;

	// clean pencil line, plus a fainter, looser retrace for the sketched-over-itself look
	vec2 hash_seed = uv * 120.0;
	vec2 jitter1 = (vec2(hash(hash_seed), hash(hash_seed + vec2(15.0, 27.0))) - 0.5) * texel * line_wobble;
	vec2 jitter2 = (vec2(hash(hash_seed + vec2(41.0, 7.0)), hash(hash_seed + vec2(63.0, 19.0))) - 0.5) * texel * line_wobble;

	vec2 base_offset = line_thickness * texel;
	float edge_main = compute_edge(uv, depth, base_offset + jitter1);
	float edge_retrace = compute_edge(uv, depth, base_offset * retrace_offset_scale + jitter2);
	float is_edge_main = smoothstep(line_threshold, line_threshold + 0.2, edge_main);
	float is_edge_retrace = smoothstep(line_threshold * 1.3, line_threshold * 1.3 + 0.2, edge_retrace) * retrace_strength;
	float is_edge = clamp(is_edge_main + is_edge_retrace, 0.0, 1.0);

	ALBEDO = mix(shaded_color, ink_color.rgb, is_edge * ink_color.a);
}
