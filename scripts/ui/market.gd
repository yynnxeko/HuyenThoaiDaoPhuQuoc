extends Control

## Market screen — sell caught fish for money

signal market_closed

var selected_fish_id: String = ""
var fish_list: Array = []
var scroll_offset: int = 0
var hover_index: int = -1
var sell_animation_timer: float = 0.0
var sell_message: String = ""


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_fish_list()


func _refresh_fish_list() -> void:
	fish_list.clear()
	for fish_id in GameData.caught_fish:
		var data = GameData.caught_fish[fish_id]
		if data["count"] > 0:
			var fish_type = FishDatabase.get_fish_by_id(fish_id)
			if fish_type:
				fish_list.append({
					"id": fish_id,
					"type": fish_type,
					"count": data["count"],
					"best_size": data["best_size"],
				})


func _process(delta: float) -> void:
	if sell_animation_timer > 0:
		sell_animation_timer -= delta
		if sell_animation_timer <= 0:
			sell_message = ""
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			market_closed.emit()
		elif event.keycode == KEY_UP:
			hover_index = max(0, hover_index - 1)
		elif event.keycode == KEY_DOWN:
			hover_index = min(fish_list.size() - 1, hover_index + 1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_sell_selected()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(fish_list.size()):
			var btn_y = 260.0 + float(i) * 70.0
			if event.position.x >= 1100 and event.position.x <= 1280 and \
			   event.position.y >= btn_y - 15 and event.position.y <= btn_y + 30:
				hover_index = i
				_sell_selected()
				break


func _sell_selected() -> void:
	if hover_index < 0 or hover_index >= fish_list.size():
		return
	var item = fish_list[hover_index]
	var price = item["type"].base_price
	GameData.sell_fish(item["id"], 1, price)
	sell_message = "Da ban " + item["type"].name_vn + " voi gia " + str(price) + " $!"
	sell_animation_timer = 2.0
	_refresh_fish_list()
	if hover_index >= fish_list.size():
		hover_index = fish_list.size() - 1


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var sw = 1920.0
	var sh = 1080.0
	
	# Overlay
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.7))
	
	# Panel
	var panel = Rect2(300, 100, 1320, 880)
	draw_rect(panel, Color(0.05, 0.07, 0.12, 0.95))
	draw_rect(panel, Color(0.3, 0.6, 0.8, 0.4), false, 2.0)
	
	# Title
	draw_string(font, Vector2(360, 160), "CHO CA PHU QUOC", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.9, 0.5))
	
	# Money
	draw_string(font, Vector2(1200, 160), str(GameData.money) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.9, 0.3))
	
	# Column headers
	draw_string(font, Vector2(360, 210), "Loai ca", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(700, 210), "Do hiem", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(870, 210), "So luong", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(1000, 210), "Gia", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.7))
	draw_line(Vector2(340, 220), Vector2(1580, 220), Color(0.3, 0.3, 0.4), 1.0)
	
	if fish_list.size() == 0:
		draw_string(font, Vector2(360, 300), "Chua co ca nao de ban. Hay di cau truoc!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.6, 0.6))
	else:
		for i in range(fish_list.size()):
			var item = fish_list[i]
			var y = 260.0 + float(i) * 70.0
			var rarity_color = FishDatabase.get_rarity_color(item["type"].rarity)
			
			if i == hover_index:
				draw_rect(Rect2(340, y - 20, 1240, 60), Color(0.2, 0.4, 0.6, 0.3))
			
			draw_string(font, Vector2(360, y + 10), item["type"].name_vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
			draw_string(font, Vector2(360, y + 32), item["type"].name_en, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.6, 0.6))
			draw_string(font, Vector2(700, y + 10), FishDatabase.get_rarity_name_vn(item["type"].rarity), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, rarity_color)
			draw_string(font, Vector2(870, y + 10), "x" + str(item["count"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
			draw_string(font, Vector2(1000, y + 10), str(item["type"].base_price) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.3))
			
			var btn_rect = Rect2(1100, y - 10, 160, 38)
			draw_rect(btn_rect, Color(0.15, 0.5, 0.25, 0.75))
			draw_rect(btn_rect, Color(0.3, 0.8, 0.4, 0.4), false, 1.5)
			draw_string(font, Vector2(1125, y + 16), "Ban 1 con", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.9))
	
	if sell_message != "":
		draw_string(font, Vector2(360, 920), sell_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 1.0, 0.4, clampf(sell_animation_timer, 0.0, 1.0)))
	
	draw_string(font, Vector2(360, 960), "Nhan ESC de dong", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.5))
