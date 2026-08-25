shader_type particles;

uniform vec2 mouse_position = vec2(0.0);

float rand(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

void start() {
    float seed = float(INDEX) + TIME;
    
    // Spawn strictly inside screen boundaries (0 to 1920 X, 0 to 1080 Y)
    TRANSFORM[3].xy = vec2(
        rand(seed) * 800.0,
        rand(seed + 1.0) * 1000.0
    );
    
    VELOCITY = vec3(0.0, -10.0, 0.0);
}

void process() {
    // Gentle upward float
    VELOCITY.y = mix(VELOCITY.y, -15.0, DELTA);

    // Repel dust away from mouse
    vec2 diff = TRANSFORM[3].xy - mouse_position;
    float dist = length(diff);
    float repel_radius = 80.0;
    float repel_force = 250.0;

    if (dist < repel_radius && dist > 0.0) {
        vec2 push = normalize(diff) * (1.0 - (dist / repel_radius)) * repel_force * DELTA;
        VELOCITY.xy += push;
    }

    // Move particles
    TRANSFORM[3].xy += VELOCITY.xy * DELTA;

    // --- SCREEN BOUNDARY WRAPPING ---
    // Wrap horizontal edges
    if (TRANSFORM[3].x < 0.0) TRANSFORM[3].x += 1920.0;
    if (TRANSFORM[3].x > 1920.0) TRANSFORM[3].x -= 1920.0;

    // Wrap vertical edges (floats off top -> reappears at bottom)
    if (TRANSFORM[3].y < 0.0) TRANSFORM[3].y += 1080.0;
    if (TRANSFORM[3].y > 1080.0) TRANSFORM[3].y -= 1080.0;
}