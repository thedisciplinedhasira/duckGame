shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled;

uniform sampler2D image_texture : source_color, filter_linear_mipmap;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.04;
uniform float aspect_ratio = 1.0;

void fragment() {
    vec4 tex = texture(image_texture, UV);
    
    // Shift UVs to center (-0.5 to 0.5)
    vec2 centered_uv = UV - vec2(0.5);
    
    // Scale X by aspect ratio so our corners form perfect circles, not ovals
    centered_uv.x *= aspect_ratio;
    
    // Calculate the bounds of the "paper"
    vec2 extents = vec2(0.5 * aspect_ratio, 0.5);
    
    // Signed Distance Field (SDF) math for a rounded rectangle
    vec2 d = abs(centered_uv) - extents + vec2(corner_radius);
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - corner_radius;
    
    // Clip the pixels outside the rounded corners
    if (dist > 0.0) {
        discard;
    }
    
    ALBEDO = tex.rgb;
    // Optional: Add a very subtle darkening near the edges for a "paper thickness" illusion
    ALBEDO *= smoothstep(0.0, 0.02, abs(dist)); 
}