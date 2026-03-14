shader_type canvas_item;

// Volumetric sun rays (god rays) penetrating into water

uniform float ray_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float ray_count : hint_range(2.0, 15.0) = 6.0;
uniform float ray_speed : hint_range(0.0, 2.0) = 0.3;
uniform float ray_width : hint_range(0.01, 0.2) = 0.08;
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.7, 0.3);
uniform float sun_x : hint_range(0.0, 1.0) = 0.3;
uniform float fade_start : hint_range(0.0, 1.0) = 0.0;
uniform float fade_end : hint_range(0.0, 1.0) = 0.8;

void fragment() {
    vec2 uv = UV;
    float t = TIME;
    
    // Calculate rays emanating from sun position at top
    float total_ray = 0.0;
    
    for (float i = 0.0; i < 10.0; i += 1.0) {
        if (i >= ray_count) break;
        
        float offset = i / ray_count;
        float ray_angle = (offset - 0.5) * 0.6 + sin(t * ray_speed + i * 1.7) * 0.05;
        
        // Ray line from top
        float ray_x = sun_x + ray_angle * uv.y;
        float dist = abs(uv.x - ray_x);
        
        float width = ray_width * (1.0 + uv.y * 0.5);
        float ray = smoothstep(width, 0.0, dist);
        
        // Animate intensity
        ray *= 0.5 + 0.5 * sin(t * ray_speed * 2.0 + i * 2.5);
        
        total_ray += ray;
    }
    
    total_ray = clamp(total_ray, 0.0, 1.0);
    
    // Vertical fade
    float fade = smoothstep(fade_end, fade_start, uv.y);
    total_ray *= fade;
    
    // Apply color
    vec4 final_color = ray_color;
    final_color.a *= total_ray * ray_intensity;
    
    COLOR = final_color;
}
