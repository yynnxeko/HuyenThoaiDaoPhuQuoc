extends Node3D

## 3D Game World — manages boat, ocean, camera, fishing spots, zones

signal return_to_menu

enum GameState { NAVIGATING, FISHING, MINIGAME, UI_OPEN }
var state: GameState = GameState.NAVIGATING

# World
var world_width: float = 200.0  # 3D units
var camera_follow_speed: float = 3.0

# References (set in _ready from scene tree)
var boat: Node3D = null
var camera: Camera3D = null
var hud: Control = null
var fishing_mode_node = null

# Fishing
var fishing_spots: Array = []

# Zone
var current_zone_info = null

# HUD CanvasLayer reference
var hud_canvas: CanvasLayer = null

# Fish underwater (decorative 3D)
var fish_nodes: Array = []

# Environment time
var day_night_time: float = 0.0
var sun_light: DirectionalLight3D = null
var env: WorldEnvironment = null


func _ready() -> void:
	# Get references
	boat = $Boat3D
	camera = $Camera3D
	hud_canvas = $HUD
	hud = $HUD/HUDControl
	sun_light = $DirectionalLight3D
	env = $WorldEnvironment
	
	# Generate fishing spots
	_generate_fishing_spots()
	
	# Spawn decorative fish
	_spawn_decorative_fish()
	
	# Initial zone
	current_zone_info = ZoneDatabase.get_zone_at_position(boat.position.x * 60.0)
	
	# Keyboard shortcut hints on HUD
	if hud and hud.has_method("show_message"):
		hud.show_message("A/D: Di chuyen | E: Cau ca | M: Ban do | T: Cho | U: Nang cap")


func _process(delta: float) -> void:
	if state == GameState.NAVIGATING:
		_process_navigation(delta)
	
	# Update camera to follow boat
	_update_camera(delta)
	
	# Update day/night cycle on sun
	_update_lighting(delta)
	
	# Update decorative fish
	_update_decorative_fish(delta)
	
	# Zone check
	_check_zone()


func _process_navigation(delta: float) -> void:
	# Boat movement input
	var move_input = 0.0
	if Input.is_action_pressed("move_right"):
		move_input = 1.0
	elif Input.is_action_pressed("move_left"):
		move_input = -1.0
	
	if boat:
		boat.move_input = move_input
		# Clamp boat position
		boat.position.x = clampf(boat.position.x, -world_width / 2.0, world_width / 2.0)
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_check_fishing_spot()
	
	# Return to menu
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


func _update_camera(delta: float) -> void:
	if camera and boat:
		# Smooth follow boat X position
		var target_x = boat.position.x
		camera.position.x = lerp(camera.position.x, target_x, camera_follow_speed * delta)
		# Keep camera Y/Z fixed (side view)
		camera.position.y = 5.0
		camera.position.z = 15.0


func _update_lighting(delta: float) -> void:
	if sun_light == null:
		return
	
	var time_info = fposmod(TimeWeather.game_hour, 24.0) / 24.0  # 0.0 to 1.0
	
	# Sun angle based on time of day
	var sun_angle = (time_info - 0.25) * TAU  # noon = sun overhead
	sun_light.rotation_degrees.x = -30.0 - sin(sun_angle) * 40.0
	
	# Sun color based on time
	var period = TimeWeather.get_period_name()
	match period:
		"dawn":
			sun_light.light_color = Color(1.0, 0.7, 0.4)
			sun_light.light_energy = 0.6
		"morning":
			sun_light.light_color = Color(1.0, 0.95, 0.85)
			sun_light.light_energy = 1.0
		"afternoon":
			sun_light.light_color = Color(1.0, 0.9, 0.8)
			sun_light.light_energy = 1.1
		"evening":
			sun_light.light_color = Color(1.0, 0.6, 0.3)
			sun_light.light_energy = 0.7
		"night":
			sun_light.light_color = Color(0.3, 0.35, 0.6)
			sun_light.light_energy = 0.2


func _check_zone() -> void:
	if boat == null:
		return
	# Convert 3D position to 2D zone position (scale factor)
	var world_x = (boat.position.x + world_width / 2.0) / world_width * 12000.0
	var new_zone = ZoneDatabase.get_zone_at_position(world_x)
	if new_zone and (current_zone_info == null or new_zone.id != current_zone_info.id):
		current_zone_info = new_zone
		AudioManager.play_zone_enter()
		if hud and hud.has_method("show_zone_name"):
			hud.show_zone_name(current_zone_info.name_vn)


func _generate_fishing_spots() -> void:
	# Place fishing spot markers in 3D
	var spot_x_positions = [-80, -55, -30, -10, 10, 30, 50, 70, 85]
	for xpos in spot_x_positions:
		var world_x_2d = (float(xpos) + world_width / 2.0) / world_width * 12000.0
		fishing_spots.append({
			"x3d": float(xpos),
			"x2d": world_x_2d,
			"zone": ZoneDatabase.get_zone_at_position(world_x_2d).id,
			"glow_time": randf() * TAU,
		})
		# Create visual marker (glowing sphere)
		_create_spot_marker(Vector3(float(xpos), 0.05, 0))


func _create_spot_marker(pos: Vector3) -> void:
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	marker.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	marker.position = pos
	add_child(marker)


func _spawn_decorative_fish() -> void:
	for i in range(12):
		var fish_mesh = MeshInstance3D.new()
		var capsule = CapsuleMesh.new()
		capsule.radius = randf_range(0.08, 0.2)
		capsule.height = randf_range(0.4, 0.8)
		fish_mesh.mesh = capsule
		fish_mesh.rotation_degrees.z = 90  # Horizontal
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0.3, 0.7), randf_range(0.4, 0.8), randf_range(0.5, 0.9), 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fish_mesh.material_override = mat
		
		fish_mesh.position = Vector3(
			randf_range(-world_width / 2.0, world_width / 2.0),
			randf_range(-2.0, -0.5),
			randf_range(-3.0, 3.0)
		)
		add_child(fish_mesh)
		fish_nodes.append({
			"node": fish_mesh,
			"speed": randf_range(1.0, 4.0),
			"dir": [-1.0, 1.0][randi() % 2],
			"wave_offset": randf() * TAU,
		})


func _update_decorative_fish(delta: float) -> void:
	for fish in fish_nodes:
		var node: MeshInstance3D = fish["node"]
		if node == null:
			continue
		node.position.x += fish["speed"] * fish["dir"] * delta
		node.position.y = -1.0 + sin(Time.get_ticks_msec() * 0.001 + fish["wave_offset"]) * 0.3
		# Wrap
		if node.position.x > world_width / 2.0 + 5:
			node.position.x = -world_width / 2.0 - 5
		elif node.position.x < -world_width / 2.0 - 5:
			node.position.x = world_width / 2.0 + 5


func _check_fishing_spot() -> void:
	if boat == null:
		return
	for spot in fishing_spots:
		var dist = abs(boat.position.x - spot["x3d"])
		if dist < 3.0:
			if not GameData.is_zone_unlocked(spot["zone"]):
				if hud and hud.has_method("show_message"):
					hud.show_message("Can nang cap thuyen de den khu vuc nay!")
				return
			_enter_fishing_mode(spot)
			return
	if hud and hud.has_method("show_message"):
		hud.show_message("Khong co diem cau ca gan day. Tim cac diem sang tren mat nuoc!")


func _enter_fishing_mode(spot: Dictionary) -> void:
	state = GameState.FISHING
	var fishing_scene = load("res://scenes/game/fishing_mode.tscn")
	if fishing_scene:
		fishing_mode_node = fishing_scene.instantiate()
		# Convert 3D spot to 2D data for fishing mode (fishing UI stays 2D overlay)
		var spot_2d = {
			"x": spot["x2d"],
			"y": 540.0,
			"zone": spot["zone"],
			"glow_time": spot["glow_time"],
		}
		fishing_mode_node.setup(spot_2d, current_zone_info, null)
		fishing_mode_node.fishing_ended.connect(_on_fishing_ended)
		fishing_mode_node.fish_caught.connect(_on_fish_caught)
		# Add to a CanvasLayer so it overlays the 3D view
		var overlay = CanvasLayer.new()
		overlay.layer = 10
		overlay.name = "FishingOverlay"
		overlay.add_child(fishing_mode_node)
		add_child(overlay)


func _on_fishing_ended() -> void:
	state = GameState.NAVIGATING
	var overlay = get_node_or_null("FishingOverlay")
	if overlay:
		overlay.queue_free()
	fishing_mode_node = null


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


# ============ UI SCREENS ============

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
	if not GameData.is_zone_unlocked(zone_id):
		if hud and hud.has_method("show_message"):
			hud.show_message("Chua mo khoa khu vuc nay!")
		return
	var zone = ZoneDatabase.get_zone_by_id(zone_id)
	if zone and boat:
		# Teleport boat to zone center in 3D
		var zone_center_2d = (zone.world_x_start + zone.world_x_end) / 2.0
		var x_3d = (zone_center_2d / 12000.0) * world_width - world_width / 2.0
		boat.position.x = x_3d
		current_zone_info = zone
