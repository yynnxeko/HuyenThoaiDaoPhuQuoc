extends Node3D

## 3D Game World — manages boat, ocean, camera, fishing spots, zones

signal return_to_menu
signal go_to_village

enum GameState { NAVIGATING, FISHING, MINIGAME, UI_OPEN }
var state: GameState = GameState.NAVIGATING

enum CameraMode { BOAT_THIRD_PERSON, TOP_DOWN_FISHING, BAIT_FOLLOW }
var camera_mode: CameraMode = CameraMode.BOAT_THIRD_PERSON

# World
var world_width: float = 200.0  # 3D units
var camera_follow_speed: float = 3.0
var top_down_height: float = 16.0
var top_down_offset: Vector3 = Vector3(0, 0, 0)
var top_down_fov: float = 60.0
var default_camera_fov: float = 50.0
var water_level_y: float = 0.0
var bait_max_depth_3d: float = 6.0
var bait_camera_above: float = 6.0
var bait_camera_below: float = -2.0
var bait_camera_z_offset: float = 6.0
var bait_camera_fov: float = 70.0
var bait_x2d: float = 6000.0
var bait_depth_ratio: float = 0.0

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
	if camera:
		default_camera_fov = camera.fov
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
		hud.show_message("W/S: Ga | A/D: Lai | E: Cau | M: Ban do | T: Cho | U: Nang cap | B: Ve lang")


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
	# Boat steering input
	var steer_input = 0.0
	if Input.is_action_pressed("move_right"):
		steer_input = 1.0
	elif Input.is_action_pressed("move_left"):
		steer_input = -1.0

	# Boat throttle input (W/S or Up/Down)
	var throttle_input = 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		throttle_input += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		throttle_input -= 1.0
	
	if boat:
		boat.steer_input = steer_input
		boat.throttle_input = throttle_input
		# Keep boat inside gameplay area.
		boat.position.x = clampf(boat.position.x, -world_width / 2.0, world_width / 2.0)
		boat.position.z = clampf(boat.position.z, -7.0, 7.0)
	
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
	
	# Go to Village (Key V hoặc B)
	if Input.is_action_just_pressed("go_to_village") or Input.is_action_just_pressed("return_to_game"):
		go_to_village.emit()


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
		if camera_mode == CameraMode.BAIT_FOLLOW:
			var bait_x3d = _x2d_to_3d(bait_x2d)
			var depth_y = lerpf(water_level_y, water_level_y - bait_max_depth_3d, bait_depth_ratio)
			var target = Vector3(bait_x3d, depth_y, boat.position.z)
			var cam_height = lerpf(bait_camera_above, bait_camera_below, bait_depth_ratio)
			var desired_pos = target + Vector3(0, cam_height, bait_camera_z_offset)
			camera.position = camera.position.lerp(desired_pos, camera_follow_speed * delta)
			camera.look_at(target, Vector3.UP)
			camera.fov = lerpf(camera.fov, bait_camera_fov, 6.0 * delta)
		elif camera_mode == CameraMode.TOP_DOWN_FISHING:
			var target = boat.position + top_down_offset
			var desired_pos = target + Vector3(0, top_down_height, 0)
			camera.position = camera.position.lerp(desired_pos, camera_follow_speed * delta)
			camera.look_at(target, Vector3.FORWARD)
			camera.fov = lerpf(camera.fov, top_down_fov, 6.0 * delta)
		else:
			# Chase camera: behind and above boat, looking toward bow.
			var forward = boat.global_basis.x.normalized()
			var desired_pos = boat.position - forward * 8.0 + Vector3(0, 3.5, 0)
			camera.position = camera.position.lerp(desired_pos, camera_follow_speed * delta)
			camera.look_at(boat.position + forward * 3.0, Vector3.UP)
			camera.fov = lerpf(camera.fov, default_camera_fov, 6.0 * delta)


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
		var dist = Vector2(boat.position.x - spot["x3d"], boat.position.z).length()
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
	camera_mode = CameraMode.BOAT_THIRD_PERSON
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
		fishing_mode_node.setup(spot_2d, current_zone_info, boat, camera)
		fishing_mode_node.fishing_ended.connect(_on_fishing_ended)
		fishing_mode_node.fish_caught.connect(_on_fish_caught)
		if fishing_mode_node.has_signal("bait_camera_update"):
			fishing_mode_node.bait_camera_update.connect(_on_bait_camera_update)
		if fishing_mode_node.has_signal("bait_camera_end"):
			fishing_mode_node.bait_camera_end.connect(_on_bait_camera_end)
		# Add to a CanvasLayer so it overlays the 3D view
		var overlay = CanvasLayer.new()
		overlay.layer = 10
		overlay.name = "FishingOverlay"
		overlay.add_child(fishing_mode_node)
		add_child(overlay)


func _on_fishing_ended() -> void:
	state = GameState.NAVIGATING
	camera_mode = CameraMode.BOAT_THIRD_PERSON
	var overlay = get_node_or_null("FishingOverlay")
	if overlay:
		overlay.queue_free()
	fishing_mode_node = null


func _on_bait_camera_update(x2d: float, depth_ratio: float) -> void:
	bait_x2d = x2d
	bait_depth_ratio = depth_ratio
	camera_mode = CameraMode.BAIT_FOLLOW


func _on_bait_camera_end() -> void:
	if state != GameState.NAVIGATING:
		camera_mode = CameraMode.BOAT_THIRD_PERSON


func _x2d_to_3d(x2d: float) -> float:
	return (x2d / 12000.0) * world_width - world_width / 2.0


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
