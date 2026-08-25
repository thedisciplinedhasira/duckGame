shader_type canvas_item;

// These export as sliders in your Inspector so you can tweak the wind!
uniform float wind_speed = 2.5;
uniform float wind_strength = 8.0;

void vertex() {
    // Generate a swaying motion using a sine wave and time.
    // We add VERTEX.x to slightly desync the sway across the width of the sprite.
    float sway = sin(TIME * wind_speed + (VERTEX.x * 0.1)) * wind_strength;
    
    // UV.y is 0.0 at the top of the image and 1.0 at the bottom.
    // Multiplying by (1.0 - UV.y) ensures the roots stay firmly planted in the ground
    // while only the tips of the grass blow in the wind!
    VERTEX.x += sway * (1.0 - UV.y);
}