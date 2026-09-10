shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 10.0) = 3.0;
uniform float scanline_count : hint_range(0.0, 1000.0) = 450.0;
uniform float vignette_strength : hint_range(0.0, 10.0) = 3.0;

// New parameters
uniform float zoom : hint_range(1.0, 1.5) = 1.03; 
uniform float border_smoothing : hint_range(0.0, 0.1) = 0.01; 

void fragment() {
    // 1. Fisheye Distortion & Zoom
    vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
    
    // Scale the UVs to push the black edges off-screen
    centered_uv /= zoom; 
    
    vec2 offset = centered_uv.yx / curvature;
    vec2 distorted_uv = centered_uv + centered_uv * offset * offset;
    distorted_uv = distorted_uv * 0.5 + 0.5;

    // 2. Anti-Aliased Edges
    // Replaces the pixelated 'if' statement with a smooth gradient fade at the extreme edges
    float edge_x = smoothstep(0.0, border_smoothing, distorted_uv.x) * (1.0 - smoothstep(1.0 - border_smoothing, 1.0, distorted_uv.x));
    float edge_y = smoothstep(0.0, border_smoothing, distorted_uv.y) * (1.0 - smoothstep(1.0 - border_smoothing, 1.0, distorted_uv.y));
    float border_mask = edge_x * edge_y;

    vec4 tex_color = texture(screen_texture, distorted_uv);

    // 3. Scanlines
    float scanline = sin(distorted_uv.y * scanline_count * PI * 2.0);
    scanline = (scanline * 0.5 + 0.5) * 0.15 + 0.85; 
    tex_color.rgb *= scanline;

    // 4. Vignette
    // Calculated using the original screen coordinates so the shadow doesn't warp
    float vignette = length(SCREEN_UV * 2.0 - 1.0); 
    tex_color.rgb *= 1.0 - (vignette * vignette * vignette_strength * 0.1);

    // Multiply the final color by the mask to cleanly slice off the jagged pixels
    COLOR = tex_color * border_mask;
}