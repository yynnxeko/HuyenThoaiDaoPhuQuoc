extends Control

## Upgrade shop — buy improvements for rod, boat, bait, and line

signal shop_closed

var selected_category: int = 0
var buy_message: String = ""
var buy_message_timer: float = 0.0

const CATEGORIES = ["Can Cau", "Thuyen", "Moi", "Day Cau"]


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if buy_message_timer > 0:
		buy_message_timer -= delta
		if buy_message_timer <= 0:
			buy_message = ""
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			shop_closed.emit()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			selected_category = (selected_category - 1 + 4) % 4
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			selected_category = (selected_category + 1) % 4
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_try_upgrade()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(4):
			var tab_x = 400.0 + float(i) * 250.0
			if event.position.x >= tab_x and event.position.x <= tab_x + 220 and \
			   event.position.y >= 180 and event.position.y <= 220:
				selected_category = i
		if event.position.x >= 800 and event.position.x <= 1100 and \
		   event.position.y >= 700 and event.position.y <= 750:
			_try_upgrade()


func _try_upgrade() -> void:
	var success = false
	match selected_category:
		0: success = GameData.upgrade_rod()
		1: success = GameData.upgrade_boat()
		2: success = GameData.upgrade_bait()
		3: success = GameData.upgrade_line()
	
	if success:
		buy_message = "Nang cap thanh cong!"
		buy_message_timer = 2.0
	else:
		buy_message = "Khong du tien hoac da dat cap toi da!"
		buy_message_timer = 2.0


func _get_current_level() -> int:
	match selected_category:
		0: return GameData.rod_level
		1: return GameData.boat_level
		2: return GameData.bait_level
		3: return GameData.line_level
	return 0


func _get_names() -> Array:
	match selected_category:
		0: return Array(GameData.ROD_NAMES)
		1: return Array(GameData.BOAT_NAMES)
		2: return Array(GameData.BAIT_NAMES)
		3: return Array(GameData.LINE_NAMES)
	return []


func _get_prices() -> Array:
	match selected_category:
		0: return Array(GameData.ROD_PRICES)
		1: return Array(GameData.BOAT_PRICES)
		2: return Array(GameData.BAIT_PRICES)
		3: return Array(GameData.LINE_PRICES)
	return []


func _get_stats() -> Array:
	match selected_category:
		0: return Array(GameData.ROD_REEL_SPEED)
		1: return Array(GameData.BOAT_SPEED)
		2: return Array(GameData.BAIT_ATTRACT)
		3: return Array(GameData.LINE_STRENGTH)
	return []


func _get_stat_name() -> String:
	match selected_category:
		0: return "Toc do keo"
		1: return "Toc do thuyen"
		2: return "Hap dan ca"
		3: return "Suc chiu luc"
	return ""


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var sw = 1920.0
	var sh = 1080.0
	
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.7))
	
	var panel = Rect2(350, 100, 1220, 850)
	draw_rect(panel, Color(0.06, 0.05, 0.1, 0.95))
	draw_rect(panel, Color(0.8, 0.6, 0.2, 0.4), false, 2.0)
	
	draw_string(font, Vector2(410, 160), "CUA HANG NANG CAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.85, 0.4))
	draw_string(font, Vector2(1200, 160), str(GameData.money) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.9, 0.3))
	
	for i in range(4):
		var tab_x = 400.0 + float(i) * 250.0
		var tab_color = Color(0.25, 0.4, 0.6, 0.7) if i == selected_category else Color(0.15, 0.15, 0.2, 0.5)
		draw_rect(Rect2(tab_x, 185, 220, 35), tab_color)
		draw_rect(Rect2(tab_x, 185, 220, 35), Color(1, 1, 1, 0.15), false, 1.0)
		draw_string(font, Vector2(tab_x + 20, 212), CATEGORIES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
	
	var level = _get_current_level()
	var names = _get_names()
	var prices = _get_prices()
	var stats = _get_stats()
	var stat_name = _get_stat_name()
	
	for i in range(names.size()):
		var y = 280.0 + float(i) * 100.0
		var is_current = i == level
		var is_next = i == level + 1
		var is_locked = i > level + 1
		
		var bg_color = Color(0.1, 0.25, 0.15, 0.5) if is_current else Color(0.08, 0.08, 0.12, 0.35)
		if is_next:
			bg_color = Color(0.15, 0.15, 0.08, 0.45)
		draw_rect(Rect2(400, y - 10, 1120, 85), bg_color)
		draw_rect(Rect2(400, y - 10, 1120, 85), Color(1, 1, 1, 0.05), false, 1.0)
		
		var level_text = "Lv." + str(i + 1) + "  " + names[i]
		var name_col = Color(0.3, 1.0, 0.5) if is_current else Color(1, 1, 1, 0.4 if is_locked else 0.9)
		draw_string(font, Vector2(420, y + 22), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, name_col)
		draw_string(font, Vector2(420, y + 50), stat_name + ": " + str(stats[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.7, 0.85, 0.7))
		
		if is_current:
			draw_string(font, Vector2(1300, y + 22), "Hien tai", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 1.0, 0.5))
		elif is_next:
			draw_string(font, Vector2(1100, y + 22), "Gia: " + str(prices[i]) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.9, 0.3))
		elif is_locked:
			draw_string(font, Vector2(1300, y + 22), "Khoa", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 0.5, 0.5))
	
	if level < names.size() - 1:
		var can_afford = GameData.money >= prices[level + 1]
		var btn_color = Color(0.15, 0.5, 0.25, 0.8) if can_afford else Color(0.35, 0.15, 0.15, 0.6)
		draw_rect(Rect2(800, 700, 300, 50), btn_color)
		draw_rect(Rect2(800, 700, 300, 50), Color(1, 1, 1, 0.2), false, 1.5)
		draw_string(font, Vector2(830, 733), "Nang cap - " + str(prices[level + 1]) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
	else:
		draw_string(font, Vector2(830, 730), "Da dat cap toi da!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	
	if buy_message != "":
		draw_string(font, Vector2(800, 780), buy_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 0.8, clampf(buy_message_timer, 0, 1)))
	
	draw_string(font, Vector2(410, 920), "ESC: Dong | A/D: Chuyen muc | Enter: Nang cap", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.5))
