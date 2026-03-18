shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D roughness_tex : hint_default_black;

// Texture tiling
uniform float uv_scale = 18.0;

// Dunes (vertex displacement)
// Beach dunes look best when they form long ridges roughly parallel to the shoreline.
uniform float dune_amplitude = 0.9;     // overall height
uniform float dune_frequency = 0.055;   // ridge spacing (lower = larger)
uniform float dune_speed = 0.06;
uniform float ridge_noise = 0.55;       // 0..1 how broken the ridges are
uniform float beach_flat_width = 5.0;   // meters-ish: flatten dunes near shoreline

// Shoreline (procedural): wet sand + foam band near water line.
// With your current layout, shoreline is around z ≈ -80 (sand ends, ocean begins).
uniform float shoreline_z = -80.0;
uniform float shore_width = 6.0;       // wet zone width (on sand side)
uniform float foam_width = 1.2;        // foam band width at the edge
uniform float foam_intensity = 0.85;
uniform float foam_speed = 0.25;
uniform float wet_darkening = 0.18;
uniform float wet_roughness_drop = 0.35;
uniform float wet_specular_boost = 0.35; // adds "wet shine" near shore

// Beach slope: inland rises slightly relative to shoreline (makes beach feel real)
uniform float beach_slope = 0.006; // meters per meter (keep subtle; large values lift the whole plane)

// Wave run-up: make shoreline wiggle/move so foam/wet isn't a straight line
uniform float runup_amplitude = 0.9;
uniform float runup_frequency = 0.05;
uniform float runup_speed = 0.35;
uniform float runup_noise_amplitude = 0.4;

// Subtle color breakup so sand isn't too uniform
uniform float color_variation = 0.06;
uniform float variation_frequency = 0.12;

uniform float roughness_strength = 1.0;
uniform float normal_strength = 1.2;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Long ridges parallel to shoreline: vary along X, fade near shoreline.
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * dune_speed;

	// Animated shoreline for more natural dunes fade near water
	float shore_line = shoreline_z
		+ sin(wpos.x * runup_frequency + TIME * runup_speed) * runup_amplitude
		+ (fbm(wpos.xz * 0.07 + vec2(TIME * 0.12, -TIME * 0.08)) - 0.5) * 2.0 * runup_noise_amplitude;

	// dist inland on sand side (0 at shoreline, + inland)
	float dist_inland = max(0.0, wpos.z - shore_line);
	float flat_fade = smoothstep(0.0, beach_flat_width, dist_inland);

	// Ridge base (mostly sinus) + low-frequency breakup
	float ridge = sin((wpos.x * dune_frequency) + t);
	float breakup = fbm(wpos.xz * (dune_frequency * 0.6) + vec2(t * 0.35, -t * 0.2));
	ridge = mix(ridge, ridge * (breakup * 2.0 - 1.0), ridge_noise);

	// Secondary subtle cross variation so it doesn't look like perfect stripes
	float cross = (fbm(vec2(wpos.z, wpos.x) * (dune_frequency * 0.45) + vec2(-t * 0.15, t * 0.25)) - 0.5) * 2.0;

	float height = (ridge * 0.75 + cross * 0.25) * dune_amplitude * flat_fade;
	// Add gentle beach slope upward inland
	VERTEX.y += height + dist_inland * beach_slope;

	// Godot 4: pass final displaced world position to fragment.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 wpos = world_pos;

	vec3 albedo = texture(albedo_tex, uv).rgb;
	// glTF metallic-roughness maps often pack roughness into G.
	float r = texture(roughness_tex, uv).g;

	// Same animated shoreline in fragment
	float shore_line = shoreline_z
		+ sin(wpos.x * runup_frequency + TIME * runup_speed) * runup_amplitude
		+ (fbm(wpos.xz * 0.07 + vec2(TIME * 0.12, -TIME * 0.08)) - 0.5) * 2.0 * runup_noise_amplitude;

	// Shore distance on sand side (0 at shoreline, + inland)
	float dist_inland = max(0.0, wpos.z - shore_line);
	float wet = 1.0 - smoothstep(0.0, shore_width, dist_inland);

	// Foam band breakup (animated)
	float foam_band = 1.0 - smoothstep(0.0, foam_width, dist_inland);
	float foam_noise = fbm(wpos.xz * 0.18 + vec2(TIME * foam_speed, -TIME * foam_speed * 0.6));
	float foam = foam_band * smoothstep(0.68, 0.92, foam_noise);

	// Subtle albedo variation (big blobs)
	float var_n = fbm(wpos.xz * variation_frequency);
	albedo *= 1.0 + (var_n - 0.5) * 2.0 * color_variation;

	// Wet sand look: darker + smoother
	albedo = mix(albedo, albedo * (1.0 - wet_darkening), wet);
	r = clamp(r * roughness_strength - wet * wet_roughness_drop, 0.02, 1.0);

	// Foam overlay
	albedo = mix(albedo, vec3(0.92), foam * foam_intensity);

	ALBEDO = albedo;
	SPECULAR = clamp(0.5 + wet * wet_specular_boost, 0.0, 1.0);

	vec3 n = texture(normal_tex, uv).rgb;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_strength;

	ROUGHNESS = r;
}
