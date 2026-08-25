shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D grass_texture : source_color;
uniform sampler2D flower_texture : source_color;
uniform sampler2D wind_noise;

// Automatically reads from Project Settings -> Shader Globals -> player_position
global uniform vec3 player_position;

uniform float push_radius : hint_range(0.5, 5.0) = 2.0;   // Distance around player grass bends
uniform float push_strength : hint_range(0.0, 3.0) = 1.2; // How far the grass flattens

// Passes the random flower/grass variation from vertex to fragment
varying float rand_type;

void vertex() {
    // 1. Get the world position of this specific grass blade's base origin
    vec3 instance_world_pos = MODEL_MATRIX[3].xyz;
    
    // 2. Height Mask: 1.0 at the tip of the grass blade (UV.y = 0.0), 0.0 at root (UV.y = 1.0)
    // Ensures roots remain anchored to the ground.
    float height_mask = 1.0 - UV.y;
    
    // 3. Billboarding (Forces quad to face camera)
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
   
    // Direction vector from Player -> Grass in 3D World Space
    vec3 dir_from_player = instance_world_pos - player_position;
    
    // Horizontal distance on floor (X and Z)
    float dist = length(dir_from_player.xz);
    
    // Smooth quadratic curve (1.0 directly under player feet, 0.0 at edge of radius)
    float push_factor = clamp(1.0 - (dist / push_radius), 0.0, 1.0);
    push_factor = push_factor * push_factor;
    
    // Horizontal direction to push outward
    vec2 push_dir = (dist > 0.001) ? normalize(dir_from_player.xz) : vec2(0.0, 1.0);
    
    // Construct true 3D World-Space Offset:
    // X & Z push outward away from player; Y pushes DOWNWARD to crush grass into soil.
    vec3 world_offset = vec3(
        push_dir.x * push_factor * push_strength,
        -push_factor * push_strength * 0.7, // Downward fold/crush
        push_dir.y * push_factor * push_strength
    ) * height_mask;
    
    // CRITICAL MATRIX TRANSFORM:
    // Convert World-Space offset into View-Space so it works seamlessly with camera billboarding
    vec3 view_offset = (VIEW_MATRIX * vec4(world_offset, 0.0)).xyz;
    
    // Apply displacement to vertex position
    VERTEX += view_offset;
    
    // ------------------------------------------------------------------
    // WIND DISPLACEMENT
    // ------------------------------------------------------------------
    float wind_sample = texture(wind_noise, instance_world_pos.xz * 0.1 + (TIME * 0.15)).r;
    vec3 wind_world_offset = vec3(wind_sample * 0.25 * height_mask, 0.0, 0.0);
    VERTEX += (VIEW_MATRIX * vec4(wind_world_offset, 0.0)).xyz;
    
    // ------------------------------------------------------------------
    // RANDOM VARIATION SEED (Grass vs Flower selection)
    // ------------------------------------------------------------------
    float seed = float(INSTANCE_ID) * 43.12;
    rand_type = fract(sin(seed) * 43758.5453);
}

void fragment() {
    vec4 tex;
    
    // ~20% chance to sample flower texture, ~80% chance for grass texture
    if (rand_type > 0.8) {
        tex = texture(flower_texture, UV);
    } else {
        tex = texture(grass_texture, UV);
    }
    
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    
    // Upward normals for soft, seamless Ghibli-style terrain shading
    NORMAL = vec3(0.0, 1.0, 0.0);
}