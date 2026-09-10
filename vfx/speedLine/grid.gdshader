// URL: https://godotshaders.com/shader/world-coordinates-grid-bw-shader/
// Original author: Lordinator
// Toon version by Profesor Shader
// https://www.youtube.com/@ProfesorShader
// License: CC0

shader_type spatial;

uniform float gridSize = 1.0;
uniform vec4 colorA : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 colorB : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float levels = 4.0;
uniform float power = 3.0;

varying vec3 world_position;

void vertex() {
	world_position = VERTEX;
}

void fragment(){
	vec3 pos = world_position;
	pos /= gridSize;
	pos += gridSize * 20.0;
	//to offset a bug that appears when one of the coordinate is close to 0
	//can be tweaked if the bug is visible
	pos.y += 1.0*float(fract(float(int(pos.x*2.0))/2.0));
	pos.z += float(fract(float(int(pos.y*2.0))/2.0));
	float col = fract(float(int(pos.z*2.0))/2.0);
	ALBEDO = mix(colorA, colorB, step(0.5, col)).rgb; //  mix(colorA, colorB, col).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
    vec3 L = normalize(LIGHT);
    float NdotL = max(dot(NORMAL, L), 0.0);
	float fade = (floor(NdotL * ATTENUATION * levels) / levels);
	DIFFUSE_LIGHT += pow(fade, power) * LIGHT_COLOR;
}
