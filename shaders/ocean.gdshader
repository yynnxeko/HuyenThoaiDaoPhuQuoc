shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.1, 0.4, 0.5, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.1, 0.2, 1.0);
uniform float wave_height = 0.5;
uniform float wave_length = 20.0;
uniform float wave_speed = 2.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float time_offset = 0.0;

varying float v_height;
varying vec3 v_world_pos;

struct GerstnerWave {
	float xz_steepness;
	float amplitude;
	vec2 direction;
	float freq;
	float speed;
};

vec3 calculate_gerstner(vec3 pos, float time, GerstnerWave w, inout vec3 tangent, inout vec3 binormal) {
	float proj = dot(pos.xz, w.direction);
	float phase = w.freq * (proj - w.speed * time);
	
	float s = sin(phase);
	float c = cos(phase);
	
	tangent += vec3(
		-w.direction.x * w.direction.x * (w.xz_steepness * s),
		w.direction.x * c,
		-w.direction.x * w.direction.y * (w.xz_steepness * s)
	);
	
	binormal += vec3(
		-w.direction.x * w.direction.y * (w.xz_steepness * s),
		w.direction.y * c,
		-w.direction.y * w.direction.y * (w.xz_steepness * s)
	);
	
	return vec3(
		w.direction.x * (w.amplitude * w.xz_steepness * c),
		w.amplitude * s,
		w.direction.y * (w.amplitude * w.xz_steepness * c)
	);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME + time_offset;
	
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 displacement = vec3(0.0);
	
	// Wave 1 (Main)
	GerstnerWave w1;
	w1.direction = normalize(wind_direction);
	w1.amplitude = wave_height;
	w1.freq = 2.0 * PI / wave_length;
	w1.speed = wave_speed;
	w1.xz_steepness = 0.5;
	displacement += calculate_gerstner(v_world_pos, t, w1, tangent, binormal);
	
	// Wave 2 (Secondary)
	GerstnerWave w2;
	w2.direction = normalize(wind_direction + vec2(0.4, 0.3));
	w2.amplitude = wave_height * 0.6;
	w2.freq = 2.0 * PI / (wave_length * 0.5);
	w2.speed = wave_speed * 1.2;
	w2.xz_steepness = 0.4;
	displacement += calculate_gerstner(v_world_pos, t, w2, tangent, binormal);
	
	// Wave 3 (Detail)
	GerstnerWave w3;
	w3.direction = normalize(wind_direction + vec2(-0.2, 0.5));
	w3.amplitude = wave_height * 0.3;
	w3.freq = 2.0 * PI / (wave_length * 0.2);
	w3.speed = wave_speed * 1.5;
	w3.xz_steepness = 0.3;
	displacement += calculate_gerstner(v_world_pos, t, w3, tangent, binormal);
	
	VERTEX += displacement;
	v_height = displacement.y;
	NORMAL = normalize(cross(binormal, tangent));
}

void fragment() {
	// Opaque teal ocean (less game-y), with fresnel highlight.
	// Palette (from reference):
	// - shallow/highlight: #4DCCBF
	// - mid water:         #008C8C
	// - deep water:        #003340
	// - deep shadow:       #001A26
	vec3 shallow = vec3(0.3, 0.8, 0.75);
	vec3 mid = vec3(0.0, 0.55, 0.55);
	vec3 deep = vec3(0.0, 0.2, 0.25);
	vec3 shadow = vec3(0.0, 0.1, 0.15);
	
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.0);
	
	// Base gradient: slightly push toward shadow to reduce overall brightness.
	vec3 water_color = mix(shadow, deep, 0.6);
	water_color = mix(water_color, mid, 0.55);
	water_color = mix(water_color, shallow, fresnel * 0.7);
	
	ALBEDO = water_color;
	METALLIC = 0.0;
	// Reduce gloss vs previous look.
	ROUGHNESS = 0.14;
	SPECULAR = 0.35;
	ALPHA = 1.0;
}
