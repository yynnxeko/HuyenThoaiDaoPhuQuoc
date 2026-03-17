shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D noise_tex;
uniform float noise_scale = 0.001;
uniform float time_scale = 1.0;
uniform vec3 spawn_pos = vec3(0.0);

// Lighting uniforms
uniform vec4 sun_color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float sun_factor : hint_range(0.0, 1.0) = 0.5;

// Colors
uniform vec4 shallow_color : source_color = vec4(0.1, 0.6, 0.7, 0.85);
uniform vec4 deep_color : source_color = vec4(0.02, 0.1, 0.2, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

// Wave parameters (Shallow/Shore) - Tuned
uniform float s_amplitude : hint_range(0.0, 2.0) = 0.25;
uniform float s_wavelength : hint_range(1.0, 200.0) = 40.0;
uniform float s_speed : hint_range(0.0, 10.0) = 1.3;
uniform float s_steepness : hint_range(0.0, 1.0) = 0.4;

// Wave parameters (Deep Ocean) - Dramatic Swells
uniform float d_amplitude : hint_range(0.0, 5.0) = 2.5;
uniform float d_wavelength : hint_range(1.0, 500.0) = 200.0;
uniform float d_speed : hint_range(0.0, 10.0) = 0.8;
uniform float d_steepness : hint_range(0.0, 1.0) = 0.6;

varying float v_noise;
varying vec3 v_world_pos;

// Depth texture for submergence effect
uniform sampler2D depth_texture : hint_depth_texture;

struct Wave {
	float a; // amplitude
	float l; // wavelength
	float s; // speed
	float q; // steepness
	vec2 d;  // direction
};

vec3 get_gerstner_wave(Wave w, vec3 pos, float t, inout vec3 tangent, inout vec3 binormal) {
	float k = 2.0 * PI / w.l;
	float f = k * (dot(w.d, pos.xz) - w.s * t);
	
	float cos_f = cos(f);
	float sin_f = sin(f);
	
	// Displacement
	float dx = w.d.x * w.a * w.q * cos_f;
	float dy = w.a * sin_f;
	float dz = w.d.y * w.a * w.q * cos_f;
	
	// Tangent/Binormal for normal calculation
	tangent += vec3(
		-w.d.x * w.d.x * (w.q * sin_f),
		w.d.x * cos_f,
		-w.d.x * w.d.y * (w.q * sin_f)
	);
	binormal += vec3(
		-w.d.x * w.d.y * (w.q * sin_f),
		w.d.y * cos_f,
		-w.d.y * w.d.y * (w.q * sin_f)
	);
	
	return vec3(dx, dy, dz);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * time_scale;
	
	// Sample noise for zone blending
	float original_noise = texture(noise_tex, v_world_pos.xz * noise_scale).r;
	
	// Spawn Safety Bias
	float dist_to_spawn = distance(v_world_pos.xz, spawn_pos.xz);
	float safety_bias = smoothstep(0.0, 800.0, dist_to_spawn);
	v_noise = mix(0.0, original_noise, safety_bias);
	
	// Interpolate wave parameters
	float amp = mix(s_amplitude, d_amplitude, v_noise);
	float len = mix(s_wavelength, d_wavelength, v_noise);
	float spd = mix(s_speed, d_speed, v_noise);
	float stp = mix(s_steepness, d_steepness, v_noise);
	
	vec3 total_displacement = vec3(0.0);
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	
	// Wave 1
	Wave w1;
	w1.a = amp; w1.l = len; w1.s = spd; w1.q = stp; w1.d = normalize(vec2(1.0, 0.2));
	total_displacement += get_gerstner_wave(w1, v_world_pos, t, tangent, binormal);
	
	// Wave 2
	Wave w2;
	w2.a = amp * 0.6; w2.l = len * 0.5; w2.s = spd * 1.2; w2.q = stp * 0.8; w2.d = normalize(vec2(-0.7, 0.7));
	total_displacement += get_gerstner_wave(w2, v_world_pos, t, tangent, binormal);
	
	// Wave 3
	Wave w3;
	w3.a = amp * 0.3; w3.l = len * 0.2; w3.s = spd * 1.5; w3.q = stp * 0.5; w3.d = normalize(vec2(0.2, 0.9));
	total_displacement += get_gerstner_wave(w3, v_world_pos, t, tangent, binormal);
	
	VERTEX.y += total_displacement.y;
	VERTEX.xz += total_displacement.xz;
	
	NORMAL = normalize(cross(binormal, tangent));
}

void fragment() {
	// Intersection logic using depth texture
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_pos = upos.xyz / upos.w;
	float depth_diff = length(VERTEX - pixel_pos); // Approx distance to scene geometry
	
	// Color interpolation
	vec3 base_water_color = mix(shallow_color.rgb, deep_color.rgb, v_noise);
	vec3 final_water_color = mix(base_water_color, sun_color.rgb, sun_factor);
	
	// Foam logic
	float crest = smoothstep(0.7, 1.0, VERTEX.y / (d_amplitude * 1.5 + 0.1));
	float slope = 1.0 - dot(NORMAL, vec3(0.0, 1.0, 0.0));
	float contact = 1.0 - smoothstep(0.0, 0.5, depth_diff);
	
	float combined_foam = clamp(crest + contact * 0.8, 0.0, 1.0) * slope;
	vec3 final_albedo = mix(final_water_color, foam_color.rgb, combined_foam * 0.9);
	
	// Fresnel
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	
	ALBEDO = final_albedo;
	METALLIC = 0.1;
	ROUGHNESS = 0.05 + combined_foam * 0.2;
	SPECULAR = 0.6;
	EMISSION = final_albedo * fresnel * 0.3;
	
	// Transparency for submergence
	ALPHA = mix(shallow_color.a, 1.0, v_noise);
}
