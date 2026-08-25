shader_type canvas_item;

uniform int segment_count = 8; // Controlled by script
uniform int selected_index = -1; // Controlled by script

uniform float radius_outer : hint_range(0.1, 0.5) = 0.40; // Size of the wheel
uniform float radius_inner : hint_range(0.1, 0.5) = 0.20; // Size of the center hole
uniform float gap_width : hint_range(0.0, 0.05) = 0.01; // Spacing between segments

// Colors extracted from the reference image
uniform vec4 bg_color : source_color = vec4(0.12, 0.11, 0.10, 0.85); // Dark brown/grey
uniform vec4 highlight_bg : source_color = vec4(0.0, 0.65, 0.9, 0.95); // Bright cyan
uniform vec4 border_color : source_color = vec4(0.95, 0.85, 0.3, 1.0); // Glowing gold

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // Calculate angle. Top dead center is 0, sweeping clockwise.
    float angle = atan(uv.y, uv.x) + (PI / 2.0); 
    if (angle < 0.0) angle += TAU;

    float segment_arc = TAU / float(segment_count);
    int current_segment = int(floor(angle / segment_arc));
    float local_angle = mod(angle, segment_arc);

    // SDF: Calculate distance to the closest edge for the current segment
    float dist_to_inner = dist - radius_inner;
    float dist_to_outer = radius_outer - dist;
    float dist_to_start = local_angle * dist;
    float dist_to_end = (segment_arc - local_angle) * dist;

    // Find the absolute closest edge
    float edge_dist = min(min(dist_to_inner, dist_to_outer), min(dist_to_start, dist_to_end));

    // Mask to cut out the gaps and outer bounds (adds anti-aliasing)
    float mask = smoothstep(0.0, 0.003, edge_dist - gap_width);

    if (mask <= 0.0) {
        COLOR = vec4(0.0); // Transparent void
    } else {
        if (current_segment == selected_index) {
            // Selected: Draw the gold border and cyan interior
            float border = smoothstep(0.005, 0.012, edge_dist - gap_width);
            vec4 color = mix(border_color, highlight_bg, border);
            
            // Subtle radial glow from the center of the segment
            color.rgb += vec3(0.15) * (1.0 - ((dist - radius_inner) / (radius_outer - radius_inner)));
            
            COLOR = vec4(color.rgb, mask * color.a);
        } else {
            // Unselected: Dark translucent background
            COLOR = vec4(bg_color.rgb, mask * bg_color.a);
        }
    }
}