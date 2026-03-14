extends Node2D

## Main game world — manages boat navigation, fishing spots, and zone transitions

signal return_to_menu

enum GameState { NAVIGATING, FISHING, MINIGAME, UI_OPEN }
var state: GameState = GameState.NAVIGATING

# World scrolling
var camera_x: float = 0.0
var world_width: float = 12000.0

# Boat reference
@onready var boat: Node2D = $Boat
@onready var hud: Control = $HUD/HUDControl
@onready var fishing_mode: Node2D = null
@onready var minigame: Node2D = null

# Fishing spots
var fishing_spots: Array = []
var active_spot: Node2D = null

# Water line Y position
const WATER_LINE_Y: float = 540.0

# Drawing
var wave_time: float = 0.0
var cloud_positions: Array = []

# Fish underwater
var underwater_fish: Array = []

# Zone
var current_zone_info = null


func _ready() -> void:
	# Initialize clouds
	for i in range(8):
		cloud_positions.append({
			"x": randf_range(0, 1920),
			"y": randf_range(60, 200),
			"scale": randf_range(0.4, 1.2),
			"speed": randf_range(8.0, 25.0),
		})
	
	# Generate fishing spots
	_generate_fishing_spots()
	
	# Generate some decorative fish
	_spawn_decorative_fish()
	
	# Set initial zone
	current_zone_info = ZoneDatabase.get_zone_at_position(camera_x)
	
	# Connect signal for weather changes
	TimeWeather.weather_changed.connect(_on_weather_changed)
	TimeWeather.period_changed.connect(_on_period_changed)


func _process(delta: float) -> void:
	wave_time += delta
	
	# Move clouds
	for cloud in cloud_positions:
		cloud["x"] += cloud["speed"] * delta
		if cloud["x"] > 1920 + 100:
			cloud["x"] = -100.0
	
	match state:
		GameState.NAVIGATING:
			_process_navigation(delta)
		GameState.FISHING:
			_process_fishing(delta)
	
	# Update decorative fish
	_update_decorative_fish(delta)
	
	# Update zone
	var new_zone = ZoneDatabase.get_zone_at_position(boat.global_position.x + camera_x)
	if new_zone and (current_zone_info == null or new_zone.id != current_zone_info.id):
		current_zone_info = new_zone
		AudioManager.play_zone_enter()
		if hud and hud.has_method("show_zone_name"):
			hud.show_zone_name(current_zone_info.name_vn)
	
	queue_redraw()


func _process_navigation(delta: float) -> void:
	# Boat movement
	var input_dir = 0.0
	if Input.is_action_pressed("move_right"):
		input_dir = 1.0
	elif Input.is_action_pressed("move_left"):
		input_dir = -1.0
	
	if input_dir != 0.0:
		var speed = GameData.get_boat_speed()
		boat.position.x += input_dir * speed * delta
		boat.facing_right = input_dir > 0
	
	# Camera follows boat
	var target_cam_x = boat.position.x - 500.0
	camera_x = lerp(camera_x, target_cam_x, delta * 2.0)
	camera_x = clampf(camera_x, 0.0, world_width - 1920.0)
	
	# Boat bobbing
	boat.position.y = WATER_LINE_Y - 30.0 + sin(wave_time * 1.5 + boat.position.x * 0.01) * 8.0
	
	# Clamp boat position
	boat.position.x = clampf(boat.position.x, camera_x + 100, camera_x + 1820)
	
	# Check for fishing spot interaction
	if Input.is_action_just_pressed("interact"):
		_check_fishing_spot()
	
	# Pause / Return to menu
	if Input.is_action_just_pressed("pause"):
		return_to_menu.emit()
	
	# Map
	if Input.is_action_just_pressed("open_map"):
		_open_map()
	
	# Collection
	if Input.is_action_just_pressed("open_collection"):
		_open_collection()


func _unhandled_key_input(event: InputEvent) -> void:
	if state != GameState.NAVIGATING:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			_open_market()
		elif event.keycode == KEY_U:
			_open_shop()


func _process_fishing(_delta: float) -> void:
	pass  # Fishing mode handles itself


func _generate_fishing_spots() -> void:
	# Create fishing spots throughout the world
	var spot_positions = [
		300, 800, 1400, 2200, 2800, 3500, 4200, 4800, 5500,
		6200, 6800, 7500, 8200, 8800, 9500, 10200, 10800, 11500
	]
	for xpos in spot_positions:
		fishing_spots.append({
			"x": float(xpos),
			"y": WATER_LINE_Y,
			"zone": ZoneDatabase.get_zone_at_position(float(xpos)).id,
			"glow_time": randf() * TAU,
		})


func _spawn_decorative_fish() -> void:
	for i in range(15):
		underwater_fish.append({
			"x": randf_range(0, world_width),
			"y": randf_range(WATER_LINE_Y + 40, 900),
			"speed": randf_range(20, 80),
			"direction": [-1.0, 1.0][randi() % 2],
			"size": randf_range(8, 25),
			"color": Color(randf_range(0.3, 0.7), randf_range(0.4, 0.8), randf_range(0.5, 0.9), 0.4),
			"wave_offset": randf() * TAU,
		})


func _update_decorative_fish(delta: float) -> void:
	for fish in underwater_fish:
		fish["x"] += fish["speed"] * fish["direction"] * delta
		fish["y"] += sin(wave_time * 2.0 + fish["wave_offset"]) * 0.3
		# Wrap around
		if fish["x"] > world_width + 100:
			fish["x"] = -50.0
		elif fish["x"] < -100:
			fish["x"] = world_width + 50.0


func _check_fishing_spot() -> void:
	for spot in fishing_spots:
		var dist = abs(boat.position.x + camera_x - spot["x"])
		if dist < 100.0:
			# Check if zone is unlocked
			if not GameData.is_zone_unlocked(spot["zone"]):
				if hud and hud.has_method("show_message"):
					hud.show_message("Cần nâng cấp thuyền để đến khu vực này!")
				return
			_enter_fishing_mode(spot)
			return
	
	# No spot nearby — show hint
	if hud and hud.has_method("show_message"):
		hud.show_message("Không có điểm câu cá gần đây. Tìm các điểm sáng trên mặt nước!")


func _enter_fishing_mode(spot: Dictionary) -> void:
	state = GameState.FISHING
	# Load fishing mode scene
	var fishing_scene = load("res://scenes/game/fishing_mode.tscn")
	if fishing_scene:
		fishing_mode = fishing_scene.instantiate()
		fishing_mode.setup(spot, current_zone_info, boat)
		fishing_mode.fishing_ended.connect(_on_fishing_ended)
		fishing_mode.fish_caught.connect(_on_fish_caught)
		add_child(fishing_mode)


func _on_fishing_ended() -> void:
	state = GameState.NAVIGATING
	if fishing_mode:
		fishing_mode.queue_free()
		fishing_mode = null


func _on_fish_caught(fish_id: String, size: float) -> void:
	var fish_data = FishDatabase.get_fish_by_id(fish_id)
	if fish_data:
		GameData.register_catch(fish_id, size, fish_data.base_price)
		if hud and hud.has_method("show_catch"):
			hud.show_catch(fish_data)


func _on_weather_changed(weather_name: String) -> void:
	if hud and hud.has_method("update_weather"):
		hud.update_weather(weather_name)


func _on_period_changed(period_name: String) -> void:
	if hud and hud.has_method("update_time_period"):
		hud.update_time_period(period_name)



func _open_map() -> void:
	if state == GameState.UI_OPEN:
		return
	state = GameState.UI_OPEN
	AudioManager.play_ui_open()
	var map_scene = load("res://scenes/ui/map_screen.tscn")
	if map_scene:
		var map_root = map_scene.instantiate()
		var map_ctrl = map_root.get_child(0)
		map_ctrl.map_closed.connect(func():
			state = GameState.NAVIGATING
			map_root.queue_free()
		)
		map_ctrl.zone_selected.connect(_on_zone_selected)
		add_child(map_root)


func _open_collection() -> void:
	if state == GameState.UI_OPEN:
		return
	state = GameState.UI_OPEN
	AudioManager.play_ui_open()
	var col_scene = load("res://scenes/ui/collection.tscn")
	if col_scene:
		var col_root = col_scene.instantiate()
		var col_ctrl = col_root.get_child(0)
		col_ctrl.collection_closed.connect(func():
			state = GameState.NAVIGATING
			col_root.queue_free()
		)
		add_child(col_root)


func _open_market() -> void:
	if state == GameState.UI_OPEN:
		return
	state = GameState.UI_OPEN
	AudioManager.play_ui_open()
	var market_scene = load("res://scenes/ui/market.tscn")
	if market_scene:
		var market_root = market_scene.instantiate()
		var market_ctrl = market_root.get_child(0)
		market_ctrl.market_closed.connect(func():
			state = GameState.NAVIGATING
			market_root.queue_free()
		)
		add_child(market_root)


func _open_shop() -> void:
	if state == GameState.UI_OPEN:
		return
	state = GameState.UI_OPEN
	AudioManager.play_ui_open()
	var shop_scene = load("res://scenes/ui/upgrade_shop.tscn")
	if shop_scene:
		var shop_root = shop_scene.instantiate()
		var shop_ctrl = shop_root.get_child(0)
		shop_ctrl.shop_closed.connect(func():
			state = GameState.NAVIGATING
			shop_root.queue_free()
		)
		add_child(shop_root)


func _on_zone_selected(zone_id: String) -> void:
	var zone = ZoneDatabase.get_zone_by_id(zone_id)
	if zone:
		GameData.current_zone = zone_id
		# Move boat to zone start
		boat.position.x = zone.world_x_start + 200.0
		camera_x = zone.world_x_start
		current_zone_info = zone
		if hud and hud.has_method("show_zone_name"):
			hud.show_zone_name(zone.name_vn)


func _draw() -> void:
	var screen_w = 1920.0
	var screen_h = 1080.0
	
	# === SKY ===
	var sky_top = TimeWeather.get_sky_top_color()
	var sky_bottom = TimeWeather.get_sky_bottom_color()
	for i in range(int(WATER_LINE_Y)):
		var t = float(i) / WATER_LINE_Y
		draw_line(Vector2(0, i), Vector2(screen_w, i), sky_top.lerp(sky_bottom, t))
	
	# === SUN / MOON ===
	var sun_norm = TimeWeather.get_sun_position_normalized()
	if sun_norm > 0.0:
		var sun_x = 300.0 + sun_norm * 400.0
		var sun_y = WATER_LINE_Y - sun_norm * 350.0
		# Glow
		for r in range(60, 0, -2):
			draw_circle(Vector2(sun_x, sun_y), float(r), Color(1.0, 0.9, 0.5, 0.015))
		draw_circle(Vector2(sun_x, sun_y), 30.0, Color(1.0, 0.95, 0.7, 0.9))
	elif TimeWeather.current_period == TimeWeather.TimePeriod.NIGHT:
		# Moon
		var moon_brightness = 0.6 if TimeWeather.is_full_moon() else 0.3
		draw_circle(Vector2(1400, 120), 25.0, Color(0.9, 0.9, 1.0, moon_brightness))
		if TimeWeather.is_full_moon():
			for r in range(40, 0, -2):
				draw_circle(Vector2(1400, 120), float(r), Color(0.8, 0.85, 1.0, 0.01))
	
	# === CLOUDS ===
	for cloud in cloud_positions:
		_draw_cloud(Vector2(cloud["x"], cloud["y"]), cloud["scale"])
	
	# === DISTANT ISLANDS (parallax) ===
	var parallax_offset = camera_x * 0.1
	_draw_island(Vector2(800.0 - parallax_offset, WATER_LINE_Y), 250.0, 70.0, 0.3)
	_draw_island(Vector2(1500.0 - parallax_offset, WATER_LINE_Y), 180.0, 50.0, 0.25)
	_draw_island(Vector2(2200.0 - parallax_offset * 0.5, WATER_LINE_Y), 300.0, 90.0, 0.2)
	
	# === WATER ===
	var water_color = TimeWeather.get_water_color()
	for i in range(int(WATER_LINE_Y), int(screen_h)):
		var t = float(i - int(WATER_LINE_Y)) / (screen_h - WATER_LINE_Y)
		var col = water_color.lerp(Color(water_color.r * 0.3, water_color.g * 0.3, water_color.b * 0.4, 0.95), t)
		var wave_off = sin(float(i) * 0.05 + wave_time * 2.0 - camera_x * 0.003) * 2.0
		draw_line(Vector2(wave_off, i), Vector2(screen_w + wave_off, i), col)
	
	# === WATER SURFACE SHIMMER ===
	var ambient = TimeWeather.get_ambient_light()
	for x_i in range(0, int(screen_w), 35):
		var world_x_pos = float(x_i) + camera_x
		var shimmer_y = WATER_LINE_Y + sin(world_x_pos * 0.015 + wave_time * 1.5) * 4.0
		var shimmer_a = (0.1 + 0.08 * sin(world_x_pos * 0.03 + wave_time * 3.0)) * ambient
		draw_line(Vector2(float(x_i), shimmer_y), Vector2(float(x_i) + 25.0, shimmer_y),
			Color(1.0, 0.95, 0.8, shimmer_a), 1.5)
	
	# === UNDERWATER CORAL ===
	_draw_corals(camera_x)
	
	# === DECORATIVE FISH ===
	for fish in underwater_fish:
		var screen_x = fish["x"] - camera_x
		if screen_x > -50 and screen_x < screen_w + 50:
			_draw_fish_shape(Vector2(screen_x, fish["y"]), fish["size"], fish["color"], fish["direction"])
	
	# === FISHING SPOTS ===
	for spot in fishing_spots:
		var screen_x = spot["x"] - camera_x
		if screen_x > -50 and screen_x < screen_w + 50:
			spot["glow_time"] += 0.02
			var glow = 0.3 + 0.2 * sin(spot["glow_time"])
			# Glowing circle on water
			draw_circle(Vector2(screen_x, spot["y"]), 15.0, Color(0.3, 0.9, 1.0, glow * 0.3))
			draw_circle(Vector2(screen_x, spot["y"]), 8.0, Color(0.5, 1.0, 1.0, glow * 0.5))
			draw_circle(Vector2(screen_x, spot["y"]), 3.0, Color(0.8, 1.0, 1.0, glow))
	
	# === WEATHER EFFECTS ===
	if TimeWeather.current_weather == TimeWeather.Weather.RAIN or TimeWeather.current_weather == TimeWeather.Weather.STORM:
		_draw_rain()
	if TimeWeather.current_weather == TimeWeather.Weather.STORM:
		_draw_storm_overlay()


func _draw_cloud(pos: Vector2, scale: float) -> void:
	var alpha = 0.2 * TimeWeather.get_ambient_light()
	var col = Color(1.0, 0.97, 0.92, alpha)
	draw_circle(pos, 28.0 * scale, col)
	draw_circle(pos + Vector2(22, -8) * scale, 22.0 * scale, col)
	draw_circle(pos + Vector2(-18, -4) * scale, 20.0 * scale, col)
	draw_circle(pos + Vector2(8, 7) * scale, 18.0 * scale, col)


func _draw_island(pos: Vector2, width: float, height: float, alpha: float) -> void:
	var points = PackedVector2Array()
	for i in range(21):
		var t = float(i) / 20.0
		var x = pos.x - width / 2.0 + t * width
		var y = pos.y - sin(t * PI) * height + sin(t * PI * 3.0) * height * 0.12
		points.append(Vector2(x, y))
	points.append(Vector2(pos.x + width / 2.0, pos.y))
	points.append(Vector2(pos.x - width / 2.0, pos.y))
	if points.size() >= 3:
		draw_colored_polygon(points, Color(0.1, 0.15, 0.2, alpha))


func _draw_corals(cam_x: float) -> void:
	var coral_colors = [
		Color(0.8, 0.3, 0.4, 0.3),
		Color(0.9, 0.6, 0.2, 0.3),
		Color(0.3, 0.7, 0.5, 0.3),
		Color(0.5, 0.3, 0.8, 0.25),
	]
	# Draw coral clusters at fixed world positions
	var coral_positions_world = [500, 1200, 2500, 3200, 4100, 5000, 6000, 7000, 8500, 10000]
	for i in range(coral_positions_world.size()):
		var world_x = float(coral_positions_world[i])
		var screen_x = world_x - cam_x
		if screen_x < -100 or screen_x > 2020:
			continue
		var col = coral_colors[i % coral_colors.size()]
		_draw_single_coral(Vector2(screen_x, 950), col, 20.0 + float(i % 3) * 10.0)
		_draw_single_coral(Vector2(screen_x + 40, 970), col.lightened(0.1), 15.0 + float(i % 2) * 8.0)


func _draw_single_coral(base: Vector2, col: Color, height: float) -> void:
	# Simple branching coral
	for branch in range(3):
		var angle = -PI / 2.0 + float(branch - 1) * 0.4
		var end = base + Vector2(cos(angle), sin(angle)) * height
		draw_line(base, end, col, 3.0)
		# Sub-branches
		for sub in range(2):
			var sub_angle = angle + float(sub - 0.5) * 0.5
			var sub_end = end + Vector2(cos(sub_angle), sin(sub_angle)) * height * 0.4
			draw_line(end, sub_end, col.lightened(0.15), 2.0)


func _draw_fish_shape(pos: Vector2, size: float, col: Color, direction: float) -> void:
	var dir = -1.0 if direction < 0 else 1.0
	# Body
	var body_points = PackedVector2Array([
		pos + Vector2(-size * dir, 0),
		pos + Vector2(-size * 0.3 * dir, -size * 0.4),
		pos + Vector2(size * 0.5 * dir, -size * 0.2),
		pos + Vector2(size * dir, 0),
		pos + Vector2(size * 0.5 * dir, size * 0.2),
		pos + Vector2(-size * 0.3 * dir, size * 0.4),
	])
	if body_points.size() >= 3:
		draw_colored_polygon(body_points, col)
	# Tail
	var tail_points = PackedVector2Array([
		pos + Vector2(-size * dir, 0),
		pos + Vector2(-size * 1.3 * dir, -size * 0.3),
		pos + Vector2(-size * 1.3 * dir, size * 0.3),
	])
	if tail_points.size() >= 3:
		draw_colored_polygon(tail_points, col.darkened(0.15))
	# Eye
	draw_circle(pos + Vector2(size * 0.4 * dir, -size * 0.05), size * 0.1, Color(1, 1, 1, col.a))


func _draw_rain() -> void:
	var intensity = 40 if TimeWeather.current_weather == TimeWeather.Weather.STORM else 20
	for i in range(intensity):
		var rx = fmod(float(i) * 97.0 + wave_time * 200.0, 1920.0)
		var ry = fmod(float(i) * 53.0 + wave_time * 400.0, 1080.0)
		draw_line(Vector2(rx, ry), Vector2(rx - 2, ry + 15), Color(0.7, 0.75, 0.85, 0.3), 1.0)


func _draw_storm_overlay() -> void:
	# Dark overlay for storm
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.05, 0.05, 0.1, 0.3))
