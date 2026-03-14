extends Control

## Fish collection / encyclopedia

signal collection_closed


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_C:
			collection_closed.emit()


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var sw = 1920.0
	var sh = 1080.0
	
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.75))
	
	draw_rect(Rect2(200, 50, 1520, 980), Color(0.04, 0.06, 0.1, 0.95))
	draw_rect(Rect2(200, 50, 1520, 980), Color(0.3, 0.5, 0.9, 0.3), false, 2.0)
	
	draw_string(font, Vector2(260, 110), "BO SUU TAP CA", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.5, 0.85, 1.0))
	
	var all_fish = FishDatabase.get_all_fish()
	var caught_count = GameData.caught_fish.size()
	draw_string(font, Vector2(1400, 110), str(caught_count) + "/" + str(all_fish.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.9, 1.0))
	
	var col_count = 3
	var card_w = 460.0
	var card_h = 140.0
	var start_x = 240.0
	var start_y = 140.0
	
	for i in range(all_fish.size()):
		var fish = all_fish[i]
		var col = i % col_count
		var row = i / col_count
		var x = start_x + float(col) * (card_w + 20)
		var y = start_y + float(row) * (card_h + 15)
		
		var is_caught = fish.id in GameData.caught_fish
		var rarity_color = FishDatabase.get_rarity_color(fish.rarity)
		
		var card_bg = Color(0.08, 0.1, 0.15, 0.8) if is_caught else Color(0.04, 0.04, 0.06, 0.6)
		draw_rect(Rect2(x, y, card_w, card_h), card_bg)
		draw_rect(Rect2(x, y, card_w, card_h), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.3 if is_caught else 0.1), false, 1.5)
		
		draw_rect(Rect2(x, y, 4, card_h), rarity_color if is_caught else Color(0.3, 0.3, 0.3, 0.3))
		
		if is_caught:
			draw_string(font, Vector2(x + 20, y + 30), fish.name_vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))
			draw_string(font, Vector2(x + 20, y + 50), fish.name_en, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.6, 0.6))
			draw_string(font, Vector2(x + 20, y + 75), FishDatabase.get_rarity_name_vn(fish.rarity), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, rarity_color)
			
			var catch_info = GameData.caught_fish[fish.id]
			draw_string(font, Vector2(x + 20, y + 100), "Da bat: " + str(catch_info["count"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.8, 0.9))
			draw_string(font, Vector2(x + 200, y + 100), "Co lon nhat: " + ("%.1f" % catch_info["best_size"]) + " m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.8, 0.9))
			draw_string(font, Vector2(x + 20, y + 125), str(fish.base_price) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.3))
		else:
			draw_string(font, Vector2(x + 20, y + 35), "??? (" + FishDatabase.get_rarity_name_vn(fish.rarity) + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.4, 0.4, 0.4))
			draw_string(font, Vector2(x + 20, y + 65), "Chua phat hien", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.3, 0.35))
	
	draw_string(font, Vector2(260, 1010), "Nhan ESC hoac C de dong", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.5))
