extends Control

## Main Menu — beautiful start screen with animated background

signal start_game
signal continue_game
signal quit_game

var time: float = 0.0
var title_glow: float = 0.0

# Button hover tracking
var hovered_button: int = -1
var selected_button: int = 0
var button_rects: Array[Rect2] = []

# Background texture
var bg_texture: Texture2D = null

# Particles for atmosphere
var particles: Array = []

# Has save data?
var has_save: bool = false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Load background
	bg_texture = load("res://assets/sprites/menu_background.png")
	
	# Check for save data
	has_save = FileAccess.file_exists("user://save_data.json")
	
	# Create floating particles
	for i in range(30):
		particles.append({
			"x": randf_range(0, 1920),
			"y": randf_range(0, 1080),
			"speed_x": randf_range(-8, 8),
			"speed_y": randf_range(-15, -5),
			"size": randf_range(1.5, 4.0),
			"alpha": randf_range(0.1, 0.4),
			"phase": randf() * TAU,
		})
	
	# Define button positions
	var btn_x = 760.0
	var btn_y = 550.0
	var btn_w = 400.0
	var btn_h = 60.0
	var btn_gap = 80.0
	
	button_rects.clear()
	button_rects.append(Rect2(btn_x, btn_y, btn_w, btn_h))  # New Game
	if has_save:
		button_rects.append(Rect2(btn_x, btn_y + btn_gap, btn_w, btn_h))  # Continue
		button_rects.append(Rect2(btn_x, btn_y + btn_gap * 2, btn_w, btn_h))  # Quit
	else:
		button_rects.append(Rect2(btn_x, btn_y + btn_gap, btn_w, btn_h))  # Quit


func _process(delta: float) -> void:
	time += delta
	title_glow = 0.5 + 0.5 * sin(time * 1.5)
	
	# Update particles
	for p in particles:
		p["x"] += p["speed_x"] * delta
		p["y"] += p["speed_y"] * delta + sin(time + p["phase"]) * 0.5
		if p["y"] < -10:
			p["y"] = 1090.0
			p["x"] = randf_range(0, 1920)
		if p["x"] < -10:
			p["x"] = 1930.0
		elif p["x"] > 1930:
			p["x"] = -10.0
	
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var max_btn = button_rects.size() - 1
		if event.keycode == KEY_UP:
			selected_button = max(0, selected_button - 1)
		elif event.keycode == KEY_DOWN:
			selected_button = min(max_btn, selected_button + 1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_button_pressed(selected_button)
	
	if event is InputEventMouseMotion:
		hovered_button = -1
		for i in range(button_rects.size()):
			if button_rects[i].has_point(event.position):
				hovered_button = i
				selected_button = i
				break
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(button_rects.size()):
			if button_rects[i].has_point(event.position):
				_on_button_pressed(i)
				break


func _on_button_pressed(index: int) -> void:
	if has_save:
		match index:
			0: 
				GameData.reset_game()
				start_game.emit()
			1: continue_game.emit()
			2: get_tree().quit()
	else:
		match index:
			0: start_game.emit()
			1: get_tree().quit()


func _draw() -> void:
	var sw = 1920.0
	var sh = 1080.0
	
	# === BACKGROUND IMAGE ===
	if bg_texture:
		var tex_size = bg_texture.get_size()
		var scale = max(sw / tex_size.x, sh / tex_size.y)
		var draw_size = tex_size * scale
		var offset = (Vector2(sw, sh) - draw_size) / 2.0
		draw_texture_rect(bg_texture, Rect2(offset, draw_size), false)
	else:
		# Fallback gradient if no image
		for i in range(int(sh)):
			var t = float(i) / sh
			var col = Color(0.15, 0.05, 0.25).lerp(Color(0.95, 0.45, 0.15), t * 0.6)
			draw_line(Vector2(0, i), Vector2(sw, i), col)
	
	# === ANIMATED OVERLAY (subtle waves) ===
	for i in range(0, int(sh), 3):
		var wave = sin(float(i) * 0.02 + time * 0.8) * 0.015
		draw_rect(Rect2(0, i, sw, 2), Color(0, 0, 0.1, wave * wave * 50.0))
	
	# === FLOATING PARTICLES ===
	for p in particles:
		var alpha = p["alpha"] * (0.7 + 0.3 * sin(time * 2.0 + p["phase"]))
		draw_circle(Vector2(p["x"], p["y"]), p["size"], Color(1.0, 0.95, 0.8, alpha))
	
	# === DARK VIGNETTE ===
	_draw_vignette(sw, sh)
	
	# === TITLE AREA ===
	_draw_title(sw)
	
	# === MENU BUTTONS ===
	_draw_buttons()
	
	# === BOTTOM TEXT ===
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(sw / 2.0 - 120, sh - 30), "Phu Quoc Island, Vietnam", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.3))
	draw_string(font, Vector2(20, sh - 30), "v1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.2))


func _draw_vignette(sw: float, sh: float) -> void:
	# Top darkness
	for i in range(200):
		var a = (1.0 - float(i) / 200.0) * 0.6
		draw_line(Vector2(0, i), Vector2(sw, i), Color(0, 0, 0.02, a))
	# Bottom darkness
	for i in range(300):
		var y = sh - float(i)
		var a = (1.0 - float(i) / 300.0) * 0.5
		draw_line(Vector2(0, y), Vector2(sw, y), Color(0, 0, 0.02, a))
	# Left/right edges
	for i in range(150):
		var a = (1.0 - float(i) / 150.0) * 0.3
		draw_line(Vector2(i, 0), Vector2(i, sh), Color(0, 0, 0, a))
		draw_line(Vector2(sw - i, 0), Vector2(sw - i, sh), Color(0, 0, 0, a))


func _draw_title(sw: float) -> void:
	var font = ThemeDB.fallback_font
	var title_y = 280.0
	
	# Title glow background
	var glow_rect = Rect2(sw / 2.0 - 450, title_y - 80, 900, 200)
	for i in range(20, 0, -1):
		var glow_r = glow_rect.grow(float(i) * 3.0)
		draw_rect(glow_r, Color(1.0, 0.75, 0.2, 0.005 * title_glow))
	
	# Dark panel behind title
	draw_rect(Rect2(sw / 2.0 - 420, title_y - 60, 840, 170), Color(0, 0, 0, 0.45))
	# Top accent line
	draw_line(Vector2(sw / 2.0 - 420, title_y - 60), Vector2(sw / 2.0 + 420, title_y - 60), Color(1.0, 0.8, 0.3, 0.6 * title_glow), 2.0)
	# Bottom accent line
	draw_line(Vector2(sw / 2.0 - 420, title_y + 110), Vector2(sw / 2.0 + 420, title_y + 110), Color(1.0, 0.8, 0.3, 0.4 * title_glow), 2.0)
	
	# Main title
	var title = "HUYEN THOAI"
	var title2 = "DAO PHU QUOC"
	var t1_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 56)
	var t2_size = font.get_string_size(title2, HORIZONTAL_ALIGNMENT_CENTER, -1, 56)
	
	# Shadow
	draw_string(font, Vector2(sw / 2.0 - t1_size.x / 2.0 + 3, title_y + 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(sw / 2.0 - t2_size.x / 2.0 + 3, title_y + 68), title2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0, 0, 0, 0.5))
	
	# Golden text
	var gold = Color(1.0, 0.88, 0.35 + title_glow * 0.15)
	draw_string(font, Vector2(sw / 2.0 - t1_size.x / 2.0, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, gold)
	draw_string(font, Vector2(sw / 2.0 - t2_size.x / 2.0, title_y + 65), title2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, gold)
	
	# Subtitle
	var sub = "Cau ca - Kham pha - Huyen thoai"
	var sub_size = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, Vector2(sw / 2.0 - sub_size.x / 2.0, title_y + 100), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.85, 0.65, 0.7))


func _draw_buttons() -> void:
	var font = ThemeDB.fallback_font
	
	var labels: Array[String] = []
	if has_save:
		labels = ["GAME MOI", "TIEP TUC", "THOAT"]
	else:
		labels = ["BAT DAU", "THOAT"]
	
	for i in range(button_rects.size()):
		if i >= labels.size():
			break
		var rect = button_rects[i]
		var is_selected = i == selected_button
		var is_hovered = i == hovered_button
		
		# Button background
		var bg_alpha = 0.7 if is_selected else 0.4
		var bg_color = Color(0.1, 0.15, 0.25, bg_alpha)
		if is_selected:
			bg_color = Color(0.15, 0.25, 0.4, bg_alpha)
		draw_rect(rect, bg_color)
		
		# Border
		var border_color = Color(1.0, 0.85, 0.3, 0.7) if is_selected else Color(0.5, 0.6, 0.7, 0.3)
		draw_rect(rect, border_color, false, 2.0 if is_selected else 1.0)
		
		# Glow for selected
		if is_selected:
			var glow_rect = rect.grow(3.0)
			draw_rect(glow_rect, Color(1.0, 0.85, 0.3, 0.08 + title_glow * 0.05), false, 2.0)
			# Left accent
			draw_rect(Rect2(rect.position.x, rect.position.y, 4, rect.size.y), Color(1.0, 0.85, 0.3, 0.8))
		
		# Label
		var label = labels[i]
		var label_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
		var label_x = rect.position.x + (rect.size.x - label_size.x) / 2.0
		var label_y = rect.position.y + rect.size.y / 2.0 + 10.0
		var label_color = Color(1.0, 0.95, 0.8) if is_selected else Color(0.7, 0.7, 0.75)
		draw_string(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, label_color)
	
	# Navigation hint
	var hint = "Up/Down: Chon | Enter: Xac nhan"
	var hint_y = button_rects[button_rects.size() - 1].end.y + 40
	draw_string(font, Vector2(820, hint_y), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.3))
