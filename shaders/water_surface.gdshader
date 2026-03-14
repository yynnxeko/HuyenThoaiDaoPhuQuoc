shader_type canvas_item;

// Animated water surface shader with multi-layer waves and light shimmer

uniform vec4 water_color : source_color = vec4(0.05, 0.4, 0.55, 0.8);
uniform vec4 foam_color : source_color = vec4(0.8, 0.9, 0.95, 0.6);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_amplitude : hint_range(0.001, 0.05) = 0.015;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.75;
uniform float time_scale : hint_range(0.1, 2.0) = 1.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_scale;
    
    // Multi-layer wave distortion
    float wave1 = sin(uv.x * wave_frequency + t * wave_speed) * wave_amplitude;
    float wave2 = sin(uv.x * wave_frequency * 1.7 + t * wave_speed * 0.8 + 1.5) * wave_amplitude * 0.6;
    float wave3 = sin(uv.x * wave_frequency * 3.1 + t * wave_speed * 1.3 + 3.0) * wave_amplitude * 0.3;
    float total_wave = wave1 + wave2 + wave3;
    
    // Distort UV
    vec2 distorted_uv = uv + vec2(0.0, total_wave);
    
    // Base water color with depth gradient
    vec4 base_color = water_color;
    base_color.rgb *= mix(1.2, 0.4, uv.y);
    
    // Shimmer / light caustics
    float shimmer = sin(uv.x * 25.0 + t * 2.0) * sin(uv.y * 15.0 - t * 1.5);
    shimmer = pow(max(shimmer, 0.0), 3.0) * shimmer_intensity;
    
    // Foam on wave crests
    float foam = smoothstep(foam_threshold, 1.0, sin(uv.x * wave_frequency * 0.5 + t * wave_speed * 0.6) * 0.5 + 0.5);
    foam *= smoothstep(0.05, 0.0, uv.y);  // Only near the top
    
    // Combine
    vec4 final_color = base_color;
    final_color.rgb += shimmer * vec3(0.8, 0.9, 1.0);
    final_color = mix(final_color, foam_color, foam * 0.5);
    final_color.a = transparency;
    
    COLOR = final_color;
}
