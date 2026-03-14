extends Control

## Map screen — shows zones and allows navigation

signal map_closed
signal zone_selected(zone_id: String)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			map_closed.emit()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zones = ZoneDatabase.get_all_zones()
		for i in range(zones.size()):
			var zone = zones[i]
			var card_x = 250.0 + float(i) * 280.0
			if event.position.x >= card_x and event.position.x <= card_x + 250 and \
			   event.position.y >= 350 and event.position.y <= 650:
				if GameData.is_zone_unlocked(zone.id):
					zone_selected.emit(zone.id)
					map_closed.emit()
					return


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var sw = 1920.0
	var sh = 1080.0
	
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.75))
	
	draw_rect(Rect2(180, 80, 1560, 920), Color(0.04, 0.06, 0.1, 0.95))
	draw_rect(Rect2(180, 80, 1560, 920), Color(0.3, 0.5, 0.8, 0.3), false, 2.0)
	
	draw_string(font, Vector2(240, 140), "BAN DO BIEN PHU QUOC", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.5, 0.85, 1.0))
	draw_string(font, Vector2(240, 175), "Nhan vao khu vuc de di chuyen den", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.6))
	
	var zones = ZoneDatabase.get_all_zones()
	
	for i in range(zones.size() - 1):
		var x1 = 375.0 + float(i) * 280.0
		var x2 = 375.0 + float(i + 1) * 280.0
		draw_line(Vector2(x1, 500), Vector2(x2, 500), Color(0.3, 0.4, 0.5, 0.4), 2.0)
	
	for i in range(zones.size()):
		var zone = zones[i]
		var card_x = 250.0 + float(i) * 280.0
		var is_unlocked = GameData.is_zone_unlocked(zone.id)
		var is_current = zone.id == GameData.current_zone
		
		var card_bg = Color(0.1, 0.2, 0.3, 0.7) if is_unlocked else Color(0.08, 0.08, 0.1, 0.5)
		if is_current:
			card_bg = Color(0.1, 0.3, 0.2, 0.7)
		draw_rect(Rect2(card_x, 350, 250, 300), card_bg)
		
		var border_col = Color(0.3, 0.7, 0.9, 0.5) if is_unlocked else Color(0.3, 0.3, 0.3, 0.3)
		if is_current:
			border_col = Color(0.3, 0.9, 0.5, 0.6)
		draw_rect(Rect2(card_x, 350, 250, 300), border_col, false, 2.0)
		
		draw_rect(Rect2(card_x + 10, 360, 230, 80), zone.bg_color_tint)
		
		var name_col = Color(1, 1, 1, 0.95) if is_unlocked else Color(0.5, 0.5, 0.5)
		draw_string(font, Vector2(card_x + 15, 470), zone.name_vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, name_col)
		draw_string(font, Vector2(card_x + 15, 493), zone.name_en, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.6, 0.7))
		draw_string(font, Vector2(card_x + 15, 520), "Do sau: " + str(int(zone.water_depth)) + "m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.7, 0.8))
		
		if is_unlocked:
			if is_current:
				draw_string(font, Vector2(card_x + 15, 545), "Dang o day", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1.0, 0.5))
			else:
				draw_string(font, Vector2(card_x + 15, 545), "Nhan de di den", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0))
		else:
			draw_string(font, Vector2(card_x + 15, 545), "Can thuyen Lv." + str(zone.unlock_boat_level + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.4, 0.3))
	
	draw_line(Vector2(220, 720), Vector2(1700, 720), Color(0.3, 0.3, 0.4, 0.5), 1.0)
	draw_string(font, Vector2(240, 755), "Trang bi hien tai:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.9))
	draw_string(font, Vector2(240, 785), "Can: " + GameData.ROD_NAMES[GameData.rod_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 0.9))
	draw_string(font, Vector2(500, 785), "Thuyen: " + GameData.BOAT_NAMES[GameData.boat_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 0.9))
	draw_string(font, Vector2(760, 785), "Moi: " + GameData.BAIT_NAMES[GameData.bait_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 0.9))
	draw_string(font, Vector2(1020, 785), "Day: " + GameData.LINE_NAMES[GameData.line_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 0.9))
	
	draw_string(font, Vector2(240, 970), "Nhan ESC hoac M de dong", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.5))
