shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_thickness : hint_range(0.001, 0.05) = 0.015;
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.14, 1.0);

void vertex() {
	// Push vertices outward along normals to build a black ink shell
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a;
}