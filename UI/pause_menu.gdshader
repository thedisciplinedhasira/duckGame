shader_type canvas_item;

// Reads the screen behind the UI, enabling mipmaps for a smooth blur
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform float mix_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color_over : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// Sample the screen texture at a higher LOD to create the blur
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount);
	// Mix the blurred background with the dark overlay color
	COLOR = mix(blurred, color_over, mix_amount);
}