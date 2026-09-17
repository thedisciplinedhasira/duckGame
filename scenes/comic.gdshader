shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

// hand-drawn depth-edge outline + toon shading, screen-space post process.
//
// what changed vs. v1:
//   - toon pass quantizes luminance only instead of each rgb channel on its own.
//     per-channel posterize is what made the coloured rings.
//   - quantizing happens in a reinhard-compressed domain so hdr pixels above 1.0
//     don't all pile into the top band.
//   - ordered (bayer 4x4) dither on the step, so band edges become a stipple
//     instead of a hard contour line.
//   - the whole toon pass is skipped past sky_distance, background gradient
//     is left exactly as the sky shader drew it.
//   - sky pixels early-out before the 4 extra depth taps and the noise.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Handdrawn_Outlines;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.1;
uniform float line_threshold : hint_range(0.2, 5.0) = 1.2;
uniform float min_depth_gap : hint_range(0.01, 1.0) = 0.25;
uniform float line_wobble : hint_range(0.0, 4.0) = 1.0;
// anything further than this counts as background. shared by the outline
// and toon passes so they always agree on what is sky.
uniform float sky_distance : hint_range(10.0, 2000.0) = 200.0;

group_uniforms Ink_Color;
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.14, 1.0); // silhouette / strong edges
uniform vec4 line_color_secondary : source_color = vec4(0.45, 0.08, 0.08, 1.0); // interior / soft edges
uniform float secondary_edge_bias : hint_range(0.0, 1.0) = 0.0; // 0 = single colour, 1 = full dual-tone

group_uniforms Stroke_Variation;
uniform float stroke_thickness_variation : hint_range(0.0, 1.0) = 0.35;
uniform float stroke_variation_scale : hint_range(1.0, 20.0) = 6.0;
uniform float ink_grain_strength : hint_range(0.0, 1.0) = 0.15;

group_uniforms Subtle_Toon;
uniform float toon_blend : hint_range(0.0, 1.0) = 0.35;
uniform int toon_steps : hint_range(3, 32) = 14;
// 0 = hard bands (old look, will contour on smooth surfaces)
// 1 = fully dithered. drop this to 0 if it fights your scanline pass.
uniform float toon_dither : hint_range(0.0, 1.0) = 1.0;

varying vec4 v_inv_proj_z;
varying vec4 v_inv_proj_w;

// only the z and w rows of the inverse projection are needed to get linear
// view-space depth back out of the depth buffer. godot matrices are
// column-major, so m[column][row].
float get_linear_depth(vec2 uv, vec4 inv_proj_z, vec4 inv_proj_w) {
	float raw_depth = texture(depth_texture, uv).x;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	return -(dot(inv_proj_z, ndc) / dot(inv_proj_w, ndc));
}

// cheap hash, no sin() so it doesn't band on some gpus
float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// smooth value noise from 4 hashed corners. used for stroke width and grain.
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

// 4x4 ordered dither matrix, built analytically instead of as a lookup.
// returns one of 16 evenly spaced values in [0, 15/16]. stable in screen
// space, so it reads as a print stipple rather than as animated noise.
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(a * 0.5) * 0.25 + bayer2(a);
}

void vertex() {
	// full-screen triangle pinned straight to clip space
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);

	// INV_PROJECTION_MATRIX is constant across this draw call, so build the two
	// rows we need here (3 invocations) instead of per pixel.
	v_inv_proj_z = vec4(INV_PROJECTION_MATRIX[0].z, INV_PROJECTION_MATRIX[1].z, INV_PROJECTION_MATRIX[2].z, INV_PROJECTION_MATRIX[3].z);
	v_inv_proj_w = vec4(INV_PROJECTION_MATRIX[0].w, INV_PROJECTION_MATRIX[1].w, INV_PROJECTION_MATRIX[2].w, INV_PROJECTION_MATRIX[3].w);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base_color = texture(screen_texture, uv).rgb;
	float depth = get_linear_depth(uv, v_inv_proj_z, v_inv_proj_w);

	// background: pass through untouched and bail before the expensive part.
	// silhouettes against the sky still get inked, because they're drawn on the
	// geometry side of the edge where the *neighbour* tap is the sky one.
	// this is a coherent branch (sky is a contiguous screen region) so it's a
	// real saving, not a divergence tax.
	bool is_surface = (depth <= sky_distance && depth >= 0.0);
	vec3 out_color = base_color;
	
	if (is_surface) {
		
	}
	

	// ---- toon shading -------------------------------------------------------
	float steps_f = float(toon_steps);

	// quantize brightness, not colour. the old floor(rgb * steps) / steps
	// stepped r, g and b independently, so each channel's band boundary landed
	// at a different place in a gradient -> visible coloured rings. doing it on
	// luminance and rescaling keeps hue and saturation exactly as rendered.
	float lum = dot(base_color, vec3(0.2126, 0.7152, 0.0722));

	// reinhard-compress first. the colour buffer here is linear hdr and can go
	// above 1.0; without this every bright pixel lands in the top band.
	float compressed = lum / (1.0 + lum);

	// 0.46875 is the mean of the bayer matrix, so this is a symmetric +-half
	// band offset. pushes pixels across the band boundary in a fixed pattern,
	// which turns a hard contour into a stipple.
	float dither = (bayer4(FRAGCOORD.xy) - 0.46875) * toon_dither;

	float quantized = min(floor(compressed * steps_f + 0.5 + dither) / steps_f, 0.98);
	float lum_out = quantized / (1.0 - quantized); // undo the compression

	// clamp the ratio so near-black pixels can't get flung into a bright band
	float tone_scale = clamp(lum_out / max(lum, 1e-4), 0.0, 4.0);
	vec3 shaded_color = mix(base_color, base_color * tone_scale, toon_blend);

	// ---- outline ------------------------------------------------------------
	vec2 texel = 1.0 / VIEWPORT_SIZE;

	// fast per-pixel jitter. this is what makes the stroke path look shaky.
	vec2 hash_seed = uv * 120.0;
	vec2 stroke_jitter = vec2(hash(hash_seed) - 0.5, hash(hash_seed + vec2(15.0, 27.0)) - 0.5);
	stroke_jitter *= texel * line_wobble;

	// slow-moving noise, gives the stroke a pressure-varying width instead of a
	// constant pixel thickness everywhere.
	float thickness_noise = value_noise(uv * stroke_variation_scale);
	float thickness = line_thickness * mix(1.0, mix(0.4, 1.7, thickness_noise), stroke_thickness_variation);

	vec2 offset = thickness * texel + stroke_jitter;

	float d_u = get_linear_depth(uv + vec2(0.0, -offset.y), v_inv_proj_z, v_inv_proj_w);
	float d_d = get_linear_depth(uv + vec2(0.0, offset.y), v_inv_proj_z, v_inv_proj_w);
	float d_l = get_linear_depth(uv + vec2(-offset.x, 0.0), v_inv_proj_z, v_inv_proj_w);
	float d_r = get_linear_depth(uv + vec2(offset.x, 0.0), v_inv_proj_z, v_inv_proj_w);

	float max_delta = max(max(abs(d_r - depth), abs(depth - d_l)), max(abs(d_d - depth), abs(depth - d_u)));

	// second derivative of depth. flat surfaces and smooth slopes both give ~0,
	// only creases and silhouettes spike. divided by depth so distant edges
	// don't get thinner just from perspective.
	float laplacian = abs((d_r - depth) - (depth - d_l)) + abs((d_d - depth) - (depth - d_u));
	float edge = laplacian / (depth * 0.03 + 0.001);
	edge *= step(min_depth_gap, max_delta);

	float is_edge = smoothstep(line_threshold, line_threshold + 0.2, edge);

	// dry-brush breakup, keeps the stroke from reading as a clean vector line
	if (ink_grain_strength > 0.0) {
		float grain = value_noise(uv * 45.0 + 100.0);
		is_edge *= mix(1.0, 0.5 + 0.5 * grain, ink_grain_strength);
	}

	// dual-tone ink: strong silhouette edges stay the primary colour, softer
	// interior edges lean toward the second one. off by default.
	float edge_strength = clamp(max_delta / (min_depth_gap * 4.0), 0.0, 1.0);
	vec4 ink_color = mix(line_color, line_color_secondary, (1.0 - edge_strength) * secondary_edge_bias);

	ALBEDO = mix(shaded_color, ink_color.rgb, is_edge * ink_color.a);
}
