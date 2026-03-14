extends Control

## HUD — displays time, weather, money, zone, and messages

var message_text: String = ""
var message_timer: float = 0.0
var zone_name_text: String = ""
var zone_name_timer: float = 0.0
var catch_data = null
var catch_timer: float = 0.0


func _ready() -> void:
	# Fill entire screen
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Message timer
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_text = ""
	
	# Zone name timer
	if zone_name_timer > 0:
		zone_name_timer -= delta
		if zone_name_timer <= 0:
			zone_name_text = ""
	
	# Catch popup timer
	if catch_timer > 0:
		catch_timer -= delta
		if catch_timer <= 0:
			catch_data = null
	
	queue_redraw()


func show_message(text: String, duration: float = 3.0) -> void:
	message_text = text
	message_timer = duration


func show_zone_name(zone_name: String) -> void:
	zone_name_text = zone_name
	zone_name_timer = 3.0


func show_catch(fish_data) -> void:
	catch_data = fish_data
	catch_timer = 3.0


func update_weather(_weather: String) -> void:
	pass


func update_time_period(_period: String) -> void:
	pass


func _draw() -> void:
	var font = ThemeDB.fallback_font
	
	# === TOP LEFT: Time & Weather Panel ===
	var panel_x = 20.0
	var panel_y = 20.0
	
	# Panel background with border
	_draw_panel(Rect2(panel_x, panel_y, 300, 100), Color(0.02, 0.05, 0.12, 0.75), Color(0.2, 0.5, 0.8, 0.4))
	
	# Time
	var time_str = TimeWeather.get_time_string() + "  " + TimeWeather.get_period_display_name()
	draw_string(font, Vector2(panel_x + 15, panel_y + 30), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.8))
	
	# Day
	draw_string(font, Vector2(panel_x + 15, panel_y + 55), "Ngay " + str(TimeWeather.game_day), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.75, 0.8))
	
	# Weather
	var weather_str = TimeWeather.get_weather_display_name()
	draw_string(font, Vector2(panel_x + 15, panel_y + 82), weather_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.9, 1.0))
	
	# Full moon indicator
	if TimeWeather.is_full_moon():
		draw_string(font, Vector2(panel_x + 180, panel_y + 55), "Trang Tron!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.9, 0.5))
	
	# === TOP RIGHT: Money ===
	var money_x = 1920.0 - 280.0
	_draw_panel(Rect2(money_x, panel_y, 260, 50), Color(0.08, 0.05, 0.02, 0.75), Color(0.9, 0.7, 0.2, 0.4))
	draw_string(font, Vector2(money_x + 15, panel_y + 35), str(GameData.money) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.9, 0.3))
	
	# Fish count
	_draw_panel(Rect2(money_x, panel_y + 60, 260, 38), Color(0.02, 0.05, 0.1, 0.65), Color(0.3, 0.6, 0.9, 0.3))
	draw_string(font, Vector2(money_x + 15, panel_y + 88), "Ca da bat: " + str(GameData.total_fish_caught), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.85, 1.0))
	
	# === BOTTOM: Controls hint ===
	var controls = "A/D: Di chuyen | E: Cau ca | SPACE: Tha cau | M: Ban do | C: Bo suu tap | T: Cho | U: Nang cap"
	draw_string(font, Vector2(20, 1060), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
	
	# === CENTER: Zone name ===
	if zone_name_text != "":
		var zone_alpha = clampf(zone_name_timer, 0.0, 1.0)
		var zone_text_size = font.get_string_size(zone_name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
		var zone_x = 960 - zone_text_size.x / 2.0
		_draw_panel(Rect2(zone_x - 40, 140, zone_text_size.x + 80, 65), Color(0, 0, 0, 0.5 * zone_alpha), Color(0.3, 0.8, 1.0, 0.4 * zone_alpha))
		draw_string(font, Vector2(zone_x, 185), zone_name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.4, 0.9, 1.0, zone_alpha))
	
	# === CENTER: Message ===
	if message_text != "":
		var msg_alpha = clampf(message_timer, 0.0, 1.0)
		var msg_size = font.get_string_size(message_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		var msg_x = 960 - msg_size.x / 2.0
		_draw_panel(Rect2(msg_x - 20, 475, msg_size.x + 40, 45), Color(0, 0, 0, 0.65 * msg_alpha), Color(1.0, 0.8, 0.3, 0.4 * msg_alpha))
		draw_string(font, Vector2(msg_x, 508), message_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 0.8, msg_alpha))
	
	# === CATCH POPUP ===
	if catch_data != null:
		_draw_catch_popup()


func _draw_catch_popup() -> void:
	var font = ThemeDB.fallback_font
	var catch_alpha = clampf(catch_timer, 0.0, 1.0)
	var rarity_color = FishDatabase.get_rarity_color(catch_data.rarity)
	
	# Popup panel
	var popup_rect = Rect2(660, 280, 600, 180)
	_draw_panel(popup_rect, Color(0.02, 0.04, 0.08, 0.85 * catch_alpha), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.6 * catch_alpha))
	
	# Glow border for rare+
	if catch_data.rarity != "common":
		for i in range(3):
			var glow_rect = popup_rect.grow(float(i + 1) * 2.0)
			draw_rect(glow_rect, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.08 * catch_alpha), false, 1.0)
	
	# Title
	draw_string(font, Vector2(700, 330), "BAT DUOC CA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.3, 1.0, 0.4, catch_alpha))
	
	# Fish name
	draw_string(font, Vector2(700, 375), catch_data.name_vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(rarity_color.r, rarity_color.g, rarity_color.b, catch_alpha))
	
	# Rarity
	draw_string(font, Vector2(700, 410), FishDatabase.get_rarity_name_vn(catch_data.rarity), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(rarity_color.r, rarity_color.g, rarity_color.b, catch_alpha * 0.8))
	
	# Price
	draw_string(font, Vector2(700, 445), "Gia tri: " + str(catch_data.base_price) + " $", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.3, catch_alpha))


func _draw_panel(rect: Rect2, bg_color: Color, border_color: Color) -> void:
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 1.5)
	# Inner highlight line at top
	draw_line(Vector2(rect.position.x + 1, rect.position.y + 1), Vector2(rect.end.x - 1, rect.position.y + 1), Color(1, 1, 1, 0.05), 1.0)
