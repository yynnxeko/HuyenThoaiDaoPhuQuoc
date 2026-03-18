shader_type canvas_item;

uniform float rain_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * 2.0;
	
	// Distortion from drops
	vec2 drop_uv = uv * vec2(10.0, 1.0);
	float id = floor(drop_uv.x);
	drop_uv.y += t * (hash(vec2(id)) * 0.5 + 0.5);
	
	float drop_id = floor(drop_uv.y);
	vec2 drop_f = fract(drop_uv);
	
	float h = hash(vec2(id, drop_id));
	vec2 offset = vec2(0.0);
	
	if (h < rain_amount * 0.1) {
		float circle = length(drop_f - 0.5);
		float m = smoothstep(0.3, 0.0, circle);
		offset = (drop_f - 0.5) * m * 0.05;
	}
	
	// Vertical streaks
	float streak = sin(uv.x * 200.0 + h * 100.0) * 0.5 + 0.5;
	streak *= step(0.98, fract(uv.y * 5.0 - t * 2.0 + h));
	offset.y += streak * rain_amount * 0.02;
	
	COLOR = texture(screen_texture, uv + offset);
	// Slight darkening
	COLOR.rgb *= mix(1.0, 0.9, rain_amount);
}
