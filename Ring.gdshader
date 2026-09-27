shader_type canvas_item;

uniform int segment_count = 1;
uniform int selected_index = -1;

uniform float outer_radius : hint_range(0.1, 0.5) = 0.45;
uniform float thickness : hint_range(0.05, 0.5) = 0.18;
uniform float gap_width : hint_range(0.0, 0.05) = 0.008;

// Up to 12 ability colors!
uniform vec4 segment_colors[12];
uniform vec4 selected_border_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);

// bumped from 0.4 -> 0.65, the old value was nearly invisible against
// anything but a plain bright background
uniform float unselected_alpha : hint_range(0.0, 1.0) = 0.65;
uniform float selected_alpha : hint_range(0.0, 1.0) = 0.95;

uniform float aspect_ratio = 1.0;

// --- NEW: contrast outline -------------------------------------------------
// A dark core stroke plus a thin light hairline, traced along every exposed
// edge (outer rim, inner rim, wedge gaps). One of the two always reads
// against whatever is behind the wheel, dark cave or bright sky alike.
uniform vec4 outline_dark_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform vec4 outline_light_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float outline_width : hint_range(0.0, 0.02) = 0.006;
// -----------------------------------------------------------------------

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
    // slightly wider AA band than before (0.003 -> 0.005) so the ring edge
    // itself doesn't look jagged once the outline sits right on top of it
    float mask = smoothstep(0.0, 0.005, edge_dist - gap_width);

    if (mask <= 0.0) {
        COLOR = vec4(0.0); // Clean cutouts between segments
    } else {
        vec4 base_color = segment_colors[current_segment];
        vec3 final_rgb;
        float final_alpha;

        if (current_segment == selected_index) {
            float border_mask = smoothstep(0.004, 0.012, edge_dist - gap_width);
            final_rgb = mix(selected_border_color.rgb, base_color.rgb, border_mask);

            float glow = 1.0 - ((dist - inner_radius) / thickness);
            final_rgb += vec3(0.2) * glow;

            final_alpha = selected_alpha * mask;
        } else {
            final_rgb = base_color.rgb;
            final_alpha = unselected_alpha * mask;
        }

        // Lay the two-tone stroke over the top: dark band right at the edge,
        // a lighter hairline just inside it.
        float dark_band = 1.0 - smoothstep(0.0, outline_width, edge_dist - gap_width);
        float light_band = 1.0 - smoothstep(outline_width * 0.4, outline_width, edge_dist - gap_width);
        light_band *= (1.0 - dark_band);

        final_rgb = mix(final_rgb, outline_dark_color.rgb, dark_band * outline_dark_color.a);
        final_rgb = mix(final_rgb, outline_light_color.rgb, light_band * outline_light_color.a);
        final_alpha = max(final_alpha, dark_band * mask);

        COLOR = vec4(final_rgb, final_alpha);
    }
}
