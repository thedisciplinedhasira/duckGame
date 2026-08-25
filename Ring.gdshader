shader_type canvas_item;

uniform int segment_count = 1; 
uniform int selected_index = -1; 

uniform float outer_radius : hint_range(0.1, 0.5) = 0.45;
uniform float thickness : hint_range(0.05, 0.5) = 0.18; 
uniform float gap_width : hint_range(0.0, 0.05) = 0.008; 

// Up to 12 ability colors!
uniform vec4 segment_colors[12];
uniform vec4 selected_border_color : source_color = vec4(1.0, 0.85, 0.2, 1.0); 

uniform float unselected_alpha : hint_range(0.0, 1.0) = 0.4;
uniform float selected_alpha : hint_range(0.0, 1.0) = 0.95;

uniform float aspect_ratio = 1.0; 

void fragment() {
    vec2 uv = UV - vec2(0.5);
    uv.x *= aspect_ratio; 
    
    float dist = length(uv);
    float segment_arc = TAU / float(segment_count);
    
    // MATHEMATICAL FIX: Shift the angle so the exact center of segment 0 is perfectly at the top
    float base_angle = atan(uv.y, uv.x);
    float shifted_angle = base_angle + (PI / 2.0) + (segment_arc / 2.0);
    
    // Normalize angle to keep it safely within 0 to TAU
    shifted_angle = mod(shifted_angle, TAU);
    if (shifted_angle < 0.0) shifted_angle += TAU;
    
    int current_segment = int(floor(shifted_angle / segment_arc));
    float local_angle = mod(shifted_angle, segment_arc);
    
    float inner_radius = outer_radius - thickness;
    float dist_to_inner = dist - inner_radius;
    float dist_to_outer = outer_radius - dist;
    float dist_to_start = local_angle * dist;
    float dist_to_end = (segment_arc - local_angle) * dist;
    
    float edge_dist = min(min(dist_to_inner, dist_to_outer), min(dist_to_start, dist_to_end));
    float mask = smoothstep(0.0, 0.003, edge_dist - gap_width);
    
    if (mask <= 0.0) {
        COLOR = vec4(0.0); // Clean cutouts between segments
    } else {
        vec4 base_color = segment_colors[current_segment];
        
        if (current_segment == selected_index) {
            float border_mask = smoothstep(0.004, 0.012, edge_dist - gap_width);
            vec3 final_rgb = mix(selected_border_color.rgb, base_color.rgb, border_mask);
            
            float glow = 1.0 - ((dist - inner_radius) / thickness);
            final_rgb += vec3(0.2) * glow;
            
            COLOR = vec4(final_rgb, selected_alpha * mask);
        } else {
            COLOR = vec4(base_color.rgb, unselected_alpha * mask);
        }
    }
}