shader_type canvas_item;

uniform float rain_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
    // Return early if no rain to save performance
    if (rain_amount <= 0.001) {
        vec4 base_color = texture(screen_texture, SCREEN_UV);
        base_color.a = 1.0;
        COLOR = base_color;
    } else {
        vec2 uv = SCREEN_UV;
        float time = TIME * 1.5;
        
        // Scale for standard drops
        vec2 drop_uv = uv * vec2(8.0, 4.0);
        vec2 id = floor(drop_uv);
        vec2 f = fract(drop_uv) - 0.5;
        
        // Pseudo-random value for each cell
        float rand_n = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
        
        // Add time offset and stagger between cells
        time += rand_n * 6.28;
        
        // Falling motion with a slight pause behavior
        float y_pos = -sin(time + sin(time + sin(time) * 0.5)) * 0.45;
        
        // Main drop position
        vec2 p1 = vec2(0.0, y_pos);
        float d1 = length(f - p1);
        
        // Core drop size
        float drop = smoothstep(0.15, 0.0, d1);
        
        // Water trail left behind the falling drop
        float d2 = length(f - vec2(0.0, y_pos + 0.1));
        float trail = smoothstep(0.08, 0.0, d2);
        // Cut off the trail below the drop
        if (f.y < y_pos + 0.1) trail = 0.0;
        
        vec2 offset = vec2(0.0);
        
        // Only spawn the drop logic if within rain amount percent limit
        if (rand_n < rain_amount) {
            if (drop > 0.0) {
                offset = (f - p1) * drop * 0.3; // Distort through drop
            } else if (trail > 0.0) {
                offset = (f - vec2(0.0, y_pos + 0.1)) * trail * 0.15; // Distort through trail
            }
        }
        
        // Fast vertical streaks for heavy rain intensity
        float h = hash(floor(uv * vec2(100.0, 1.0)));
        float streak = sin(uv.x * 200.0 + h * 100.0) * 0.5 + 0.5;
        streak *= step(0.98, fract(uv.y * 5.0 - TIME * 3.0 + h)); // Speed of streaks
        
        if (rain_amount > 0.3) {
            offset.y += streak * (rain_amount - 0.3) * 0.1;
        }

        // Apply distortion based on amount smoothly
        offset *= smoothstep(0.0, 0.2, rain_amount);

        vec4 screen_color = texture(screen_texture, uv + offset);
        
        // Darken edge slightly for heavy weather ambiance
        screen_color.rgb *= mix(1.0, 0.85, rain_amount);
        
        // Fix transparency invisibility! 3D viewport screen_texture can have 0 alpha!
        // We MUST force the alpha to 1.0 to actually draw it over the screen.
        screen_color.a = 1.0;
        
        COLOR = screen_color;
    }
}
