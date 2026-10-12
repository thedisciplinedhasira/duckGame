shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// the script hands the sprite texture in, material_override replaces the sprite's own material
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

// the quad grows by this much so the outline and halo have room outside the art
// the art itself stays the same size
uniform float pad = 1.3;
// script drives this, above 1.0 blooms
uniform float glow = 1.0;

group_uniforms ink;
uniform vec4 ink_color : source_color = vec4(0.04, 0.02, 0.06, 1.0);
uniform float ink_width : hint_range(0.0, 0.05) = 0.012;
// shadow direction in uv space, +x right, +y down
uniform vec2 shadow_offset = vec2(0.018, 0.024);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.85;

group_uniforms fill;
uniform vec4 color_light : source_color = vec4(1.0, 0.86, 0.38, 1.0);
uniform vec4 color_dark : source_color = vec4(0.88, 0.45, 0.08, 1.0);
// how many flat steps the gold has, 1 is a single flat color
uniform int bands : hint_range(1, 6) = 3;
// 0 recolors everything with the gold ramp, 1 keeps the art's own colors
uniform float keep_art_color : hint_range(0.0, 1.0) = 0.0;

group_uniforms halo;
uniform vec4 halo_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform float halo_radius : hint_range(0.01, 0.2) = 0.06;
uniform float halo_gain = 5.0;
uniform float halo_strength : hint_range(0.0, 1.0) = 0.8;
uniform float dot_count = 45.0;

group_uniforms shine;
uniform float shine_period = 3.5;
uniform float shine_width = 0.07;
uniform float shine_strength = 0.8;

group_uniforms;

const float TAU_12 = 0.5235988;

// biggest alpha found in a ring around this pixel, grows the shape outward
float spread(vec2 uv, float r) {
	float m = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * TAU_12;
		m = max(m, texture(tex, uv + vec2(cos(ang), sin(ang)) * r).a);
	}
	return m;
}

// average alpha over two rings, a cheap blur used to size the halftone dots
float soft(vec2 uv, float r) {
	float s = 0.0;
	for (int i = 0; i < 12; i++) {
		vec2 dir = vec2(cos(float(i) * TAU_12), sin(float(i) * TAU_12));
		s += texture(tex, uv + dir * r).a;
		s += texture(tex, uv + dir * r * 2.0).a;
	}
	return s / 24.0;
}

// puts one layer over what we have so far
void layer(inout vec3 col, inout float alpha, vec3 lc, float la) {
	float out_a = la + alpha * (1.0 - la);
	col = (lc * la + col * alpha * (1.0 - la)) / max(out_a, 0.0001);
	alpha = out_a;
}

void vertex() {
	VERTEX.xy *= pad;
	UV = (UV - 0.5) * pad + 0.5;
}

void fragment() {
	vec4 t = texture(tex, UV);
	float a = t.a;

	// gold ramp, light at the top, posterized into flat bands
	float g = 1.0 - clamp(UV.y, 0.0, 1.0);
	float q = min(floor(g * float(bands)), float(bands - 1)) / float(max(bands - 1, 1));
	vec3 fill = mix(color_dark.rgb, color_light.rgb, q);
	fill = mix(fill, t.rgb, keep_art_color);

	// glint sweeping across the art
	float diag = UV.x * 0.8 + UV.y * 0.6;
	float pos = (mod(TIME, shine_period) / shine_period) * 2.0 - 0.3;
	float shine = smoothstep(shine_width, 0.0, abs(diag - pos));
	fill += vec3(shine * shine_strength);
	fill *= glow;

	// halftone dots, bigger where there is more art nearby and brighter when glow is up
	float h = clamp(soft(UV, halo_radius) * halo_gain * glow, 0.0, 1.0);
	vec2 p = UV * dot_count;
	p = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	float dots = step(length(fract(p) - 0.5), h * 0.6);

	float ink_a = spread(UV, ink_width);
	float shadow = spread(UV - shadow_offset, ink_width) * shadow_strength;

	// bottom to top: halo, shadow, ink, fill
	vec3 col = halo_color.rgb * glow;
	float alpha = dots * halo_strength;
	layer(col, alpha, ink_color.rgb, shadow);
	layer(col, alpha, ink_color.rgb, ink_a);
	layer(col, alpha, fill, a);

	ALBEDO = col;
	ALPHA = alpha;
}