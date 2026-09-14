shader_type spatial;

uniform sampler2D floor_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D roughness_texture : hint_default_white;

uniform float tile_scale = 4.0;
uniform float normal_strength = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 random_uv(vec2 uv) {
	// Which repeated section we're in
	vec2 cell = floor(uv * tile_scale);

	// Local UV inside that section
	vec2 local_uv = fract(uv * tile_scale);

	// Random number for this section
	float r = hash21(cell);

	// Random 90-degree rotation
	if (r < 0.25) {
		local_uv = vec2(local_uv.y, 1.0 - local_uv.x);
	}
	else if (r < 0.5) {
		local_uv = vec2(1.0 - local_uv.x, 1.0 - local_uv.y);
	}
	else if (r < 0.75) {
		local_uv = vec2(1.0 - local_uv.y, local_uv.x);
	}

	// Random mirroring
	if (hash21(cell + 17.3) > 0.5) {
		local_uv.x = 1.0 - local_uv.x;
	}

	if (hash21(cell + 39.7) > 0.5) {
		local_uv.y = 1.0 - local_uv.y;
	}

	return local_uv;
}

void fragment() {
	vec2 uv = random_uv(UV);

	vec4 albedo = texture(floor_texture, uv);

	ALBEDO = albedo.rgb;

	float roughness = texture(roughness_texture, uv).r;
	ROUGHNESS = roughness;

	vec3 normal_map = texture(normal_texture, uv).rgb;
	normal_map = normal_map * 2.0 - 1.0;

	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = normal_strength;
}