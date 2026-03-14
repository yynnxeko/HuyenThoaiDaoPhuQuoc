shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Ocean shader for 3D water surface

uniform vec4 shallow_color : source_color = vec4(0.1, 0.6, 0.7, 0.85);
uniform vec4 deep_color : source_color = vec4(0.02, 0.15, 0.35, 0.95);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.6);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.0;
uniform float wave_height : hint_range(0.0, 3.0) = 0.5;
uniform float wave_frequency : hint_range(0.5, 10.0) = 2.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.3;
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	float t = TIME * wave_speed * time_scale;
	// Multi-octave waves
	float wave1 = sin(world_pos.x * wave_frequency * 0.3 + t * 1.1) * wave_height * 0.6;
	float wave2 = sin(world_pos.z * wave_frequency * 0.5 + t * 0.8 + 1.5) * wave_height * 0.4;
	float wave3 = sin((world_pos.x + world_pos.z) * wave_frequency * 0.7 + t * 1.4) * wave_height * 0.2;
	float wave4 = cos(world_pos.x * wave_frequency * 1.2 + t * 2.0) * wave_height * 0.1;
	
	VERTEX.y += wave1 + wave2 + wave3 + wave4;
	
	// Recalculate normal for lighting
	float dx = cos(world_pos.x * wave_frequency * 0.3 + t * 1.1) * wave_height * 0.6 * wave_frequency * 0.3;
	float dz = cos(world_pos.z * wave_frequency * 0.5 + t * 0.8 + 1.5) * wave_height * 0.4 * wave_frequency * 0.5;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float t = TIME * time_scale;
	
	// Depth-based color (based on distance from camera)
	float depth_factor = clamp(world_pos.z * 0.02 + 0.3, 0.0, 1.0);
	vec4 water_col = mix(shallow_color, deep_color, depth_factor);
	
	// Animated caustic/ripple pattern
	float ripple1 = sin(world_pos.x * 3.0 + t * 2.0) * sin(world_pos.z * 2.5 + t * 1.5);
	float ripple2 = sin(world_pos.x * 5.0 - t * 1.8 + 2.0) * sin(world_pos.z * 4.0 + t * 1.2);
	float ripple = (ripple1 + ripple2) * 0.05;
	
	water_col.rgb += ripple;
	
	// Foam on wave crests
	float wave_crest = sin(world_pos.x * wave_frequency * 0.3 + t * wave_speed * 1.1);
	float foam = smoothstep(1.0 - foam_amount, 1.0, wave_crest);
	water_col = mix(water_col, foam_color, foam * 0.5);
	
	// Fresnel effect (edge reflection)
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	water_col.rgb += fresnel * 0.15;
	
	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	METALLIC = 0.1;
	ROUGHNESS = 0.15 + ripple * 0.2;
	SPECULAR = 0.8;
}
