shader_type canvas_item;

// Trees sway much slower and heavier than grass
uniform float wind_speed = 1.0; 
uniform float wind_strength = 12.0;
//  Higher = stiffer trunk
uniform float trunk_stiffness = 3.0; 

void vertex() {
    // Generate the swaying motion
    float sway = sin(TIME * wind_speed + (VERTEX.x * 0.02)) * wind_strength;
    
     
    //the top 30% (the leaves) catches the wind
    float bend_curve = pow(1.0 - UV.y, trunk_stiffness);
    
    VERTEX.x += sway * bend_curve;
}