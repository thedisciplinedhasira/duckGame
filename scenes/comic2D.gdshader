shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// 2D UI doesn't have 3D camera data by default, so we define the planes here.
// IMPORTANT: Make sure these match your Camera3D's "Near" and "Far" properties!
uniform float camera_near = 0.05;
uniform float camera_far = 4000.0;

group_uniforms Handdrawn_Outlines;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.1;
uniform float line_threshold : hint_range(0.2, 3.0) = 0.85;
uniform float line_wobble : hint_range(0.0, 4.0) = 1.0;
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.14, 1.0);

group_uniforms Subtle_Toon;
uniform float toon_blend : hint_range(0.0, 1.0) = 0.35;
uniform int toon_steps : hint_range(6, 32) = 14;

// Manually linearizes depth without relying on INV_PROJECTION_MATRIX
float get_linear_depth(vec2 uv) {
    float depth = texture(depth_texture, uv).x;
    float ndc = depth * 2.0 - 1.0;
    return (2.0 * camera_near * camera_far) / (camera_far + camera_near - ndc * (camera_far - camera_near));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 base_color = texture(screen_texture, uv).rgb;
    float depth = get_linear_depth(uv);

    // 1. Soft Toon Quantization (Clamped so semi-transparent smoke doesn't turn black)
    float steps = float(toon_steps);
    vec3 toon_color = floor(base_color * steps + 0.5) / steps;
    toon_color = max(toon_color, base_color * 0.45); // Safety floor for dark particles
    vec3 shaded_color = mix(base_color, toon_color, toon_blend);

    // 2. Hand-Drawn Wobbly Outline Sampling
    vec2 texel = vec2(1.0) / vec2(textureSize(screen_texture, 0));
    vec2 stroke_jitter = vec2(
        hash(uv * 120.0) - 0.5,
        hash(uv * 120.0 + vec2(15.0, 27.0)) - 0.5
    ) * texel * line_wobble;

    vec2 offset = (line_thickness * texel) + stroke_jitter;

    float d_c = depth;
    float d_u = get_linear_depth(uv + vec2(0.0, -offset.y));
    float d_d = get_linear_depth(uv + vec2(0.0, offset.y));
    float d_l = get_linear_depth(uv + vec2(-offset.x, 0.0));
    float d_r = get_linear_depth(uv + vec2(offset.x, 0.0));

    float laplacian_x = abs((d_r - d_c) - (d_c - d_l));
    float laplacian_y = abs((d_d - d_c) - (d_c - d_u));
    
    float edge = (laplacian_x + laplacian_y) / (d_c * 0.03 + 0.001);
    
    // Ignore outlines on distant sky
    if (depth > 200.0) {
        edge = 0.0;
    }

    float is_edge = smoothstep(line_threshold, line_threshold + 0.2, edge);

    // COLOR replaces ALBEDO in canvas_item shaders
    COLOR.rgb = mix(shaded_color, line_color.rgb, is_edge * line_color.a);
    COLOR.a = 1.0;
}