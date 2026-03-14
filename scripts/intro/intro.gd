extends Node2D

## Cinematic intro sequence — sunrise over Phú Quốc with title reveal

signal intro_finished

var phase: int = 0  # 0=fade_in, 1=sunrise, 2=title, 3=prompt, 4=done
var phase_timer: float = 0.0
var title_alpha: float = 0.0
var prompt_alpha: float = 0.0
var prompt_blink_timer: float = 0.0
var fade_alpha: float = 1.0
var sun_y: float = 600.0
var can_skip: bool = false
var cloud_offset: float = 0.0
var wave_time: float = 0.0
var boat_x: float = 0.0
var boat_y: float = 0.0

# Colors
var sky_top: Color = Color(0.05, 0.02, 0.12)
var sky_bottom: Color = Color(0.05, 0.02, 0.12)
var target_sky_top: Color = Color(0.35, 0.15, 0.35)
var target_sky_bottom: Color = Color(0.95, 0.45, 0.15)


func _ready() -> void:
	phase = 0
	phase_timer = 0.0
	fade_alpha = 1.0
	boat_x = 960.0
	boat_y = 560.0


func _process(delta: float) -> void:
	phase_timer += delta
	cloud_offset += delta * 15.0
	wave_time += delta
	
	match phase:
		0:  # Fade from black
			fade_alpha = max(0.0, 1.0 - phase_timer / 2.0)
			if phase_timer >= 2.0:
				phase = 1
				phase_timer = 0.0
		
		1:  # Sunrise animation
			var t = clampf(phase_timer / 4.0, 0.0, 1.0)
			sky_top = Color(0.05, 0.02, 0.12).lerp(target_sky_top, t)
			sky_bottom = Color(0.05, 0.02, 0.12).lerp(target_sky_bottom, t)
			sun_y = lerp(620.0, 380.0, t)
			if phase_timer >= 4.0:
				phase = 2
				phase_timer = 0.0
		
		2:  # Title reveal
			title_alpha = clampf(phase_timer / 2.0, 0.0, 1.0)
			if phase_timer >= 3.0:
				phase = 3
				phase_timer = 0.0
				can_skip = true
		
		3:  # "Click to start" prompt
			prompt_blink_timer += delta
			prompt_alpha = 0.5 + 0.5 * sin(prompt_blink_timer * 3.0)
	
	# Boat bob
	boat_y = 560.0 + sin(wave_time * 1.5) * 8.0
	
	queue_redraw()


func _input(event: InputEvent) -> void:
	if can_skip:
		if event is InputEventKey and event.pressed:
			_finish_intro()
		elif event is InputEventMouseButton and event.pressed:
			_finish_intro()


func _finish_intro() -> void:
	intro_finished.emit()


func _draw() -> void:
	var screen_w = 1920.0
	var screen_h = 1080.0
	var water_line = 540.0
	
	# === SKY GRADIENT ===
	for i in range(int(water_line)):
		var t = float(i) / water_line
		var col = sky_top.lerp(sky_bottom, t)
		draw_line(Vector2(0, i), Vector2(screen_w, i), col)
	
	# === SUN ===
	var sun_pos = Vector2(400.0, sun_y)
	# Glow
	for r in range(80, 0, -2):
		var glow_alpha = 0.02 * (1.0 - float(r) / 80.0)
		draw_circle(sun_pos, float(r), Color(1.0, 0.9, 0.5, glow_alpha))
	# Sun disk
	draw_circle(sun_pos, 35.0, Color(1.0, 0.95, 0.7, 0.95))
	draw_circle(sun_pos, 28.0, Color(1.0, 1.0, 0.9, 1.0))
	
	# === CLOUDS ===
	_draw_cloud(Vector2(200.0 + cloud_offset * 0.3, 150.0), 0.7)
	_draw_cloud(Vector2(700.0 + cloud_offset * 0.2, 100.0), 1.0)
	_draw_cloud(Vector2(1300.0 + cloud_offset * 0.15, 180.0), 0.5)
	_draw_cloud(Vector2(1600.0 + cloud_offset * 0.25, 120.0), 0.8)
	
	# === DISTANT ISLANDS ===
	_draw_island(Vector2(1400.0, water_line), 200.0, 60.0, Color(0.12, 0.15, 0.2, 0.6))
	_draw_island(Vector2(1650.0, water_line), 120.0, 40.0, Color(0.1, 0.12, 0.18, 0.5))
	_draw_island(Vector2(100.0, water_line), 150.0, 50.0, Color(0.11, 0.13, 0.19, 0.55))
	
	# === WATER ===
	for i in range(int(water_line), int(screen_h)):
		var t = float(i - int(water_line)) / (screen_h - water_line)
		var water_col = Color(0.05, 0.35, 0.5).lerp(Color(0.02, 0.1, 0.25), t)
		# Wave distortion
		var wave_offset = sin(float(i) * 0.05 + wave_time * 2.0) * 2.0
		draw_line(Vector2(wave_offset, i), Vector2(screen_w + wave_offset, i), water_col)
	
	# === WATER SURFACE SHIMMER ===
	for x_i in range(0, int(screen_w), 40):
		var shimmer_y = water_line + sin(float(x_i) * 0.02 + wave_time * 1.5) * 5.0
		var shimmer_alpha = 0.15 + 0.1 * sin(float(x_i) * 0.05 + wave_time * 3.0)
		draw_line(
			Vector2(float(x_i), shimmer_y),
			Vector2(float(x_i) + 30.0, shimmer_y),
			Color(1.0, 0.95, 0.8, shimmer_alpha),
			2.0
		)
	
	# === BOAT ===
	_draw_boat(Vector2(boat_x, boat_y))
	
	# === CHARACTER ON BOAT ===
	_draw_character(Vector2(boat_x + 20.0, boat_y - 55.0))
	
	# === FADE OVERLAY ===
	if fade_alpha > 0.0:
		draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, fade_alpha))
	
	# === TITLE TEXT ===
	if title_alpha > 0.0:
		_draw_title(screen_w, title_alpha)
	
	# === START PROMPT ===
	if phase >= 3 and prompt_alpha > 0.0:
		_draw_prompt(screen_w, screen_h, prompt_alpha)


func _draw_cloud(pos: Vector2, scale: float) -> void:
	var alpha = 0.25
	draw_circle(pos, 30.0 * scale, Color(1.0, 0.95, 0.9, alpha))
	draw_circle(pos + Vector2(25, -10) * scale, 25.0 * scale, Color(1.0, 0.95, 0.9, alpha))
	draw_circle(pos + Vector2(-20, -5) * scale, 22.0 * scale, Color(1.0, 0.95, 0.9, alpha))
	draw_circle(pos + Vector2(10, 8) * scale, 20.0 * scale, Color(1.0, 0.95, 0.9, alpha * 0.8))


func _draw_island(pos: Vector2, width: float, height: float, col: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(21):
		var t = float(i) / 20.0
		var x = pos.x - width / 2.0 + t * width
		var y = pos.y - sin(t * PI) * height
		# Add some irregularity
		y += sin(t * PI * 3.0) * height * 0.15
		points.append(Vector2(x, y))
	points.append(Vector2(pos.x + width / 2.0, pos.y))
	points.append(Vector2(pos.x - width / 2.0, pos.y))
	if points.size() >= 3:
		draw_colored_polygon(points, col)
	
	# Palm trees silhouette
	var tree_x = pos.x + width * 0.1
	var tree_base = pos.y - height * 0.7
	draw_line(Vector2(tree_x, tree_base), Vector2(tree_x - 5, tree_base - 30), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a), 2.0)
	# Palm fronds
	for angle in [-0.8, -0.3, 0.2, 0.7]:
		var frond_end = Vector2(tree_x - 5 + cos(angle) * 20.0, tree_base - 30 + sin(angle) * 10.0 - 5.0)
		draw_line(Vector2(tree_x - 5, tree_base - 30), frond_end, Color(col.r * 0.6, col.g * 0.8, col.b * 0.6, col.a), 1.5)


func _draw_boat(pos: Vector2) -> void:
	# Boat hull
	var hull_points = PackedVector2Array([
		pos + Vector2(-60, 0),
		pos + Vector2(-70, 15),
		pos + Vector2(-50, 30),
		pos + Vector2(50, 30),
		pos + Vector2(70, 15),
		pos + Vector2(60, 0),
	])
	draw_colored_polygon(hull_points, Color(0.45, 0.28, 0.12))
	
	# Hull detail lines
	draw_line(pos + Vector2(-60, 5), pos + Vector2(60, 5), Color(0.35, 0.2, 0.08), 1.5)
	draw_line(pos + Vector2(-55, 15), pos + Vector2(55, 15), Color(0.35, 0.2, 0.08), 1.0)
	
	# Deck
	draw_line(pos + Vector2(-55, 0), pos + Vector2(55, 0), Color(0.55, 0.35, 0.15), 3.0)


func _draw_character(pos: Vector2) -> void:
	# Simple character: head, body, fishing rod
	# Body
	draw_rect(Rect2(pos.x - 8, pos.y - 25, 16, 30), Color(0.2, 0.35, 0.55))  # Blue shirt
	# Head
	draw_circle(pos + Vector2(0, -35), 10.0, Color(0.85, 0.7, 0.55))  # Skin
	# Hat (nón lá style)
	var hat_points = PackedVector2Array([
		pos + Vector2(-15, -42),
		pos + Vector2(0, -55),
		pos + Vector2(15, -42),
	])
	draw_colored_polygon(hat_points, Color(0.75, 0.65, 0.4))
	
	# Legs
	draw_line(pos + Vector2(-4, 5), pos + Vector2(-6, 20), Color(0.3, 0.25, 0.2), 3.0)
	draw_line(pos + Vector2(4, 5), pos + Vector2(6, 20), Color(0.3, 0.25, 0.2), 3.0)
	
	# Fishing rod
	var rod_start = pos + Vector2(8, -20)
	var rod_end = pos + Vector2(80, -60)
	draw_line(rod_start, rod_end, Color(0.5, 0.35, 0.15), 2.5)
	# Rod tip
	draw_line(rod_end, rod_end + Vector2(10, -5), Color(0.45, 0.3, 0.1), 1.5)
	
	# Fishing line
	var line_end = rod_end + Vector2(10, -5)
	var line_water = Vector2(line_end.x + 20, 560.0 + sin(wave_time * 2.0) * 5.0)
	draw_line(line_end, line_water, Color(0.7, 0.7, 0.7, 0.5), 1.0)
	


func _draw_title(screen_w: float, alpha: float) -> void:
	# Draw title text using draw primitives (since we can't use fonts easily in _draw)
	# We'll draw a glowing rectangle as title background
	var title_y = 200.0
	var title_rect = Rect2(screen_w / 2.0 - 400, title_y - 10, 800, 80)
	
	# Glow behind title
	for i in range(20, 0, -1):
		var glow_rect = title_rect.grow(float(i) * 2.0)
		draw_rect(glow_rect, Color(1.0, 0.85, 0.3, alpha * 0.02), true)
	
	# Title background
	draw_rect(title_rect, Color(0.0, 0.0, 0.0, alpha * 0.4), true)
	
	# We'll use the default font from ThemeDB
	var font = ThemeDB.fallback_font
	var font_size = 48
	
	# Title text with golden color
	var title_text = "HUYỀN THOẠI ĐẢO PHÚ QUỐC"
	var text_size = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(screen_w / 2.0 - text_size.x / 2.0, title_y + 48)
	
	# Shadow
	draw_string(font, text_pos + Vector2(2, 2), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.6))
	# Main text
	draw_string(font, text_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.88, 0.4, alpha))
	
	# Subtitle
	var sub_text = "Câu cá • Khám phá • Huyền thoại"
	var sub_size = font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	var sub_pos = Vector2(screen_w / 2.0 - sub_size.x / 2.0, title_y + 75)
	draw_string(font, sub_pos, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.85, 0.7, alpha * 0.8))


func _draw_prompt(screen_w: float, screen_h: float, alpha: float) -> void:
	var font = ThemeDB.fallback_font
	var prompt_text = "Nhấn phím bất kỳ để bắt đầu..."
	var font_size = 28
	var text_size = font.get_string_size(prompt_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(screen_w / 2.0 - text_size.x / 2.0, screen_h - 100.0)
	draw_string(font, text_pos, prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, alpha))
