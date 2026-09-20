shader_type canvas_item;

uniform float progress_current : hint_range(0.0, 1.0) = 0.4;
uniform float progress_decay : hint_range(0.0, 1.0) = 0.6;

uniform float outer_radius : hint_range(0.0, 0.5) = 0.4;
uniform float inner_radius : hint_range(0.0, 0.5) = 0.25;

uniform vec4 track_color : source_color = vec4(0.2, 0.15, 0.3, 1.0);
uniform vec4 fill_color : source_color = vec4(0.6, 0.8, 0.1, 1.0);
uniform vec4 decay_color : source_color = vec4(0.9, 0.2, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.95, 1.0);

uniform float wobble_strength : hint_range(0.0, 0.1) = 0.015;
uniform float wobble_speed : hint_range(0.0, 20.0) = 12.0;

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // Normalize angle (0.0 at top, clockwise)
    float progress_angle = angle + PI / 2.0;
    if (progress_angle < 0.0) {
        progress_angle += PI * 2.0;
    }
    float norm_angle = progress_angle / (PI * 2.0);

    // Organic edge wobble and top notch
    float wobble = sin(angle * wobble_speed) * cos(angle * 7.0) * wobble_strength;
    float notch = exp(-pow(norm_angle * 60.0, 2.0)) * 0.03 + exp(-pow((1.0 - norm_angle) * 60.0, 2.0)) * 0.03;
    float current_dist = dist + wobble - notch;

    // Base ring alpha
    float ring_alpha = smoothstep(inner_radius - 0.01, inner_radius, current_dist) - 
                       smoothstep(outer_radius, outer_radius + 0.01, current_dist);

    vec4 final_color = track_color;

    // Assign tracks based on the two progress values
    if (norm_angle <= progress_current) {
        final_color = fill_color;
    } else if (norm_angle <= progress_decay) {
        final_color = decay_color;
    }

    // Calculate glow points at the exact leading edges
    float radius_center = (inner_radius + outer_radius) / 2.0;
    
    // Decay tip glow
    float decay_rad = (progress_decay * PI * 2.0) - PI / 2.0;
    vec2 decay_pos = vec2(cos(decay_rad), sin(decay_rad)) * radius_center;
    float dist_to_decay = length(uv - decay_pos);
    float decay_glow = smoothstep(0.12, 0.0, dist_to_decay);
    
    // Current tip glow
    float current_rad = (progress_current * PI * 2.0) - PI / 2.0;
    vec2 current_pos = vec2(cos(current_rad), sin(current_rad)) * radius_center;
    float dist_to_current = length(uv - current_pos);
    float current_glow = smoothstep(0.12, 0.0, dist_to_current);

    // Combine glows and ensure they don't wrap around to the empty start of the track
    float combined_glow = max(decay_glow, current_glow);
    if (norm_angle < 0.02 && progress_current < 0.98) { 
        combined_glow = 0.0; 
    }

    // Add the glow to the color and allow it to bleed into the alpha channel
    vec3 output_color = mix(final_color.rgb, glow_color.rgb, combined_glow);
    float final_alpha = clamp(ring_alpha + (combined_glow * 0.85), 0.0, 1.0);

    // Fade out completely if stamina is exactly 0 to hide residual glow
    if (progress_decay <= 0.001) {
        final_alpha = ring_alpha;
    }

    COLOR = vec4(output_color, final_alpha);
}