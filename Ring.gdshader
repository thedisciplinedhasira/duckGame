shader_type canvas_item;

uniform int segment_count = 3;
uniform int selected_index = 0;

// Dimensions
uniform float outer_radius : hint_range(0.1, 0.5) = 0.38;
uniform float thickness : hint_range(0.05, 0.5) = 0.16;
uniform float gap_width : hint_range(0.0, 0.08) = 0.015;

// Colors & Styling
uniform vec4 segment_colors[12];
uniform vec4 ink_outline_color : source_color = vec4(0.1, 0.12, 0.15, 1.0); // Thick comic border
uniform vec4 active_yellow_stroke : source_color = vec4(1.0, 0.9, 0.25, 1.0); // Selected inner border
uniform vec4 popup_line_color : source_color = vec4(0.95, 0.2, 0.2, 1.0); // 3 Red comic lines

// Selection & Opacity
uniform float unselected_brightness : hint_range(0.1, 1.0) = 0.55;
uniform float ink_border_width : hint_range(0.005, 0.05) = 0.022;
uniform float active_stroke_width : hint_range(0.002, 0.03) = 0.012;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float aspect_ratio = SCREEN_PIXEL_SIZE.x > 0.0 ? (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y) : 1.0;
    
    // Normalize aspect ratio
    uv.x *= aspect_ratio;

    float dist = length(uv);
    float segment_arc = TAU / float(max(segment_count, 1));

    // Shift angle so segment 0 centers at the top
    float base_angle = atan(uv.y, uv.x);
    float shifted_angle = mod(base_angle + (PI / 2.0) + (segment_arc / 2.0), TAU);
    if (shifted_angle < 0.0) shifted_angle += TAU;

    int current_segment = int(floor(shifted_angle / segment_arc));
    float local_angle = mod(shifted_angle, segment_arc);

    float inner_radius = outer_radius - thickness;

    // Distances to wedge boundaries
    float dist_to_inner = dist - inner_radius;
    float dist_to_outer = outer_radius - dist;
    float dist_to_start = local_angle * dist;
    float dist_to_end = (segment_arc - local_angle) * dist;

    float edge_dist = min(min(dist_to_inner, dist_to_outer), min(dist_to_start, dist_to_end));

    bool drawn_popup = false;

    // -------------------------------------------------------------------
    // 1. COMIC ACCENT POPUP LINES (Rendered outside the outer ring)
    // -------------------------------------------------------------------
    if (dist > outer_radius + 0.005 && dist < outer_radius + 0.09) {
        if (current_segment == selected_index && selected_index != -1) {
            float line_dist_from_ring = dist - (outer_radius + 0.02);
            float norm_angle = (local_angle / segment_arc) - 0.5; // -0.5 to 0.5 across wedge
            
            // 3 line radial positions (-0.28, 0.0, 0.28)
            float l1 = abs(norm_angle - (-0.28));
            float l2 = abs(norm_angle - 0.0);
            float l3 = abs(norm_angle - 0.28);
            float min_line_angle = min(min(l1, l2), l3);

            // Shape line dashes
            float line_thick = smoothstep(0.04, 0.0, min_line_angle);
            float line_length = smoothstep(0.0, 0.008, line_dist_from_ring) * smoothstep(0.05, 0.035, line_dist_from_ring);
            
            float popup_alpha = line_thick * line_length;
            if (popup_alpha > 0.1) {
                COLOR = vec4(popup_line_color.rgb, popup_line_color.a * popup_alpha);
                drawn_popup = true;
            }
        }
    }

    // -------------------------------------------------------------------
    // 2. MAIN WEDGE MASK & BORDERS
    // -------------------------------------------------------------------
    if (!drawn_popup) {
        float main_mask = smoothstep(0.0, 0.004, edge_dist - gap_width);

        if (main_mask <= 0.0) {
            COLOR = vec4(0.0);
        } else {
            vec4 base_color = segment_colors[current_segment];
            bool is_selected = (current_segment == selected_index);

            // Apply dark comic ink outline around wedge edge
            float ink_mask = smoothstep(ink_border_width, 0.0, edge_dist - gap_width);

            // Calculate wedge RGB base
            vec3 col = is_selected ? base_color.rgb : base_color.rgb * unselected_brightness;

            // Apply active inner yellow highlight border if selected
            if (is_selected) {
                float active_stroke_mask = smoothstep(ink_border_width + active_stroke_width, ink_border_width, edge_dist - gap_width);
                col = mix(col, active_yellow_stroke.rgb, active_stroke_mask);
            }

            // Overlay main outer dark ink outline
            col = mix(col, ink_outline_color.rgb, ink_mask);

            COLOR = vec4(col, base_color.a * main_mask);
        }
    }
}