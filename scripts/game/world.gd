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
var active_fish_3d: Node3D = null
var active_fish_data = null
var nearby_fish_nodes: Array = []  # Pool of 3D nodes for nearby fish in fishing mode

# Mapping from database ID to individual GLB asset files in assets/sprites/ca
var fish_id_to_asset = {
	"ca_thu": "res://assets/sprites/ca/guppy_fish.glb",
	"ca_mu": "res://assets/sprites/ca/guppy_fish.glb",
	"ca_nuc": "res://assets/sprites/ca/guppy_fish.glb",
	"ca_chim": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_hong": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_bop": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_ngu": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_kiem": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_map": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"muc_khong_lo": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"rong_bien": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"rua_vang": "res://assets/sprites/ca/bream_fish__dorade_royale.glb"
}

# Environment time
var day_night_time: float = 0.0
var sun_light: DirectionalLight3D = null
var env: WorldEnvironment = null

# Moon and Stars
var moon_mesh: MeshInstance3D = null
var stars_mesh: Node3D = null


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
	
	_setup_moon_and_stars()
	
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
	
	# Update HUD boat rotation for compass
	if hud and boat:
		hud.boat_rotation = boat.rotation.y
	
	# Update camera to follow boat
	_update_camera(delta)
	
	# Update day/night cycle on sun
	_update_lighting(delta)
	
	# Update decorative fish
	_update_decorative_fish(delta)
	
	# Zone check
	_check_zone()


func _process_navigation(_delta: float) -> void:
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


func _update_lighting(_delta: float) -> void:
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
	
	# Update Sky colors from TimeWeather
	if env and env.environment and env.environment.sky:
		var sky_mat = env.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			sky_mat.sky_top_color = TimeWeather.get_sky_top_color()
			sky_mat.sky_horizon_color = TimeWeather.get_sky_bottom_color()
	
	# Update Moon and Stars visibility
	if moon_mesh:
		moon_mesh.visible = (period == "night" or period == "evening" or period == "dawn")
		# Simple orbit for moon
		var moon_angle = (time_info + 0.25) * TAU
		moon_mesh.position = Vector3(cos(moon_angle), sin(moon_angle), -0.5) * 80.0
	
	if stars_mesh:
		stars_mesh.visible = (period == "night")


func _setup_moon_and_stars() -> void:
	# Create a simple Moon
	moon_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 4.0
	sphere.height = 8.0
	moon_mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.8)
	mat.emission_energy_multiplier = 2.0
	moon_mesh.material_override = mat
	add_child(moon_mesh)
	
	# Create a very simple starfield using many tiny meshes (since I can't easily create GPUParticles here)
	stars_mesh = GPUParticles3D.new() # Placeholder node name
	# For now, let's just use the sky material's features if possible, or add a few distant spheres
	var stars_node = Node3D.new()
	stars_node.name = "Stars"
	add_child(stars_node)
	for i in range(100):
		var star = MeshInstance3D.new()
		var s_mesh = SphereMesh.new()
		s_mesh.radius = 0.2
		s_mesh.height = 0.4
		star.mesh = s_mesh
		var s_mat = StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(1, 1, 1, randf_range(0.5, 1.0))
		star.material_override = s_mat
		star.position = Vector3(
			randf_range(-100, 100),
			randf_range(20, 80),
			randf_range(-100, 100)
		).normalized() * 150.0
		stars_node.add_child(star)
	stars_mesh = stars_node # Assign the container


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
	var all_fish_types = FishDatabase.get_all_fish()
	
	for i in range(6):
		var f_data = all_fish_types.pick_random()
		var asset_path = fish_id_to_asset.get(f_data.id, "res://assets/sprites/ca/guppy_fish.glb")
		var fish_scene = load(asset_path)
		if not fish_scene: continue
		
		var fish_instance = fish_scene.instantiate()
		# Wrapping in a Node3D to fix orientation and local offset
		var wrapper = Node3D.new()
		add_child(wrapper)
		wrapper.add_child(fish_instance)
		
		# Some GLB files have different orientations, adjust if needed
		# Usually we want the fish to face its local Z axis
		fish_instance.position = Vector3.ZERO
		fish_instance.rotation.y = PI/2 
		
		wrapper.position = Vector3(
			randf_range(-world_width / 2.0, world_width / 2.0),
			randf_range(-10, -5),
			randf_range(-4.0, 4.0)
		)
		
		var s = f_data.max_size * 0.08
		if f_data.rarity == "legendary": s = clampf(s, 0.25, 0.5)
		wrapper.scale = Vector3(s, s, s)
		
		var swim_dir = [-1.0, 1.0].pick_random()
		wrapper.rotation.y = PI/2 if swim_dir > 0 else -PI/2
		
		# Setup real animations from GLB
		_setup_fish_animation(fish_instance, 1.0 + f_data.speed * 0.02)
		
		fish_nodes.append({
			"node": wrapper,
			"speed": f_data.speed * 0.05,
			"dir": swim_dir,
			"wave_offset": randf() * TAU,
			"base_y": wrapper.position.y # Lưu lại độ sâu ban đầu
		})


func _update_decorative_fish(delta: float) -> void:
	var time_val = Time.get_ticks_msec() * 0.001
	for fish in fish_nodes:
		var node: Node3D = fish["node"]
		if node == null: continue
		
		# Save previous position for velocity calculation
		var prev_pos = node.position
		
		# Horizontal movement
		node.position.x += fish["speed"] * fish["dir"] * delta
		
		# Vertical movement (sine wave)
		var wave_speed = 1.2
		var wave_amp = 0.4
		node.position.y = fish.get("base_y", -5.0) + sin(time_val * wave_speed + fish["wave_offset"]) * wave_amp
		
		# Boundary wrap
		if node.position.x > world_width / 2.0 + 8:
			node.position.x = -world_width / 2.0 - 8
			prev_pos = node.position
		elif node.position.x < -world_width / 2.0 - 8:
			node.position.x = world_width / 2.0 + 8
			prev_pos = node.position
			
		# Smooth Rotation
		var velocity = (node.position - prev_pos) / (delta if delta > 0 else 0.001)
		
		# Yaw (Direction)
		var target_yaw = PI/2 if fish["dir"] > 0 else -PI/2
		# Only update yaw if we're not just wrapping or at zero velocity
		if abs(velocity.x) > 0.01:
			node.rotation.y = lerp_angle(node.rotation.y, target_yaw, 4.0 * delta)
			
		# Pitch (Tilting up/down)
		# If dir is negative, we need to flip the pitch logic because the fish is facing the other way
		var pitch_factor = 1.0 if fish["dir"] > 0 else -1.0
		var target_pitch = clamp(velocity.y * 0.8 * pitch_factor, -0.5, 0.5)
		node.rotation.z = lerp_angle(node.rotation.z, target_pitch, 3.0 * delta)


func _check_fishing_spot() -> void:
	if boat == null: return
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
		hud.show_message("Khong co diem cau ca gan day!")


func _enter_fishing_mode(spot: Dictionary) -> void:
	state = GameState.FISHING
	camera_mode = CameraMode.BOAT_THIRD_PERSON
	var fishing_scene = load("res://scenes/game/fishing_mode.tscn")
	if fishing_scene:
		fishing_mode_node = fishing_scene.instantiate()
		var spot_2d = {
			"x": spot["x2d"],
			"y": 540.0,
			"zone": spot["zone"],
			"glow_time": spot["glow_time"],
		}
		fishing_mode_node.setup(spot_2d, current_zone_info, boat, camera)
		fishing_mode_node.fishing_ended.connect(_on_fishing_ended)
		fishing_mode_node.fish_caught.connect(_on_fish_caught)
		fishing_mode_node.visual_fish_update.connect(_on_visual_fish_update)
		if fishing_mode_node.has_signal("nearby_fish_visual_update"):
			fishing_mode_node.nearby_fish_visual_update.connect(_on_nearby_visual_update)
		if fishing_mode_node.has_signal("bait_camera_update"):
			fishing_mode_node.bait_camera_update.connect(_on_bait_camera_update)
		if fishing_mode_node.has_signal("bait_camera_end"):
			fishing_mode_node.bait_camera_end.connect(_on_bait_camera_end)
		fishing_mode_node.child_entered_tree.connect(_on_fishing_child_entered)
		
		var overlay = CanvasLayer.new()
		overlay.layer = 10
		overlay.name = "FishingOverlay"
		overlay.add_child(fishing_mode_node)
		add_child(overlay)


func _on_fishing_ended() -> void:
	state = GameState.NAVIGATING
	camera_mode = CameraMode.BOAT_THIRD_PERSON
	var overlay = get_node_or_null("FishingOverlay")
	if overlay: overlay.queue_free()
	fishing_mode_node = null
	
	if active_fish_3d:
		active_fish_3d.queue_free()
		active_fish_3d = null
		active_fish_data = null
	
	for node in nearby_fish_nodes:
		node.queue_free()
	nearby_fish_nodes.clear()


func _on_visual_fish_update(pos_2d: Vector2, fish_data, p_visible: bool, is_fighting: bool) -> void:
	if not p_visible or fish_data == null:
		if active_fish_3d: active_fish_3d.hide()
		return
	
	if active_fish_3d == null or active_fish_data != fish_data:
		if active_fish_3d: active_fish_3d.queue_free()
		
		var asset_path = fish_id_to_asset.get(fish_data.id, "res://assets/sprites/ca/guppy_fish.glb")
		var fish_scene = load(asset_path)
		if not fish_scene: return
		
		var fish_instance = fish_scene.instantiate()
		active_fish_3d = Node3D.new()
		add_child(active_fish_3d)
		active_fish_3d.add_child(fish_instance)
		
		# Setup real animations from GLB
		_setup_fish_animation(fish_instance, 1.2)
		
		fish_instance.position = Vector3.ZERO
		fish_instance.rotation.y = PI/2
		active_fish_data = fish_data
	
	if active_fish_3d:
		active_fish_3d.show()
		var ray_origin = camera.project_ray_origin(pos_2d)
		var ray_normal = camera.project_ray_normal(pos_2d)
		var depth_y = lerpf(water_level_y, water_level_y - bait_max_depth_3d, bait_depth_ratio) - 1.5
		var cam_forward = -camera.global_basis.z
		
		var target_pos = Vector3.ZERO
		if abs(ray_normal.y) > 0.0001:
			var t = (depth_y - ray_origin.y) / ray_normal.y
			target_pos = ray_origin + ray_normal * t
		else:
			target_pos = ray_origin + ray_normal * 10.0
		
		target_pos += cam_forward * 0.5
		
		# Smooth position follow
		var follow_speed = 8.0 if is_fighting else 4.0
		active_fish_3d.global_position = active_fish_3d.global_position.lerp(target_pos, follow_speed * get_process_delta_time())
		
		var s = fish_data.max_size * 0.1
		if fish_data.rarity == "legendary": s = clampf(s, 0.3, 0.75)
		active_fish_3d.scale = active_fish_3d.scale.lerp(Vector3(s, s, s), 5.0 * get_process_delta_time())
		
		# Smooth orientation
		var cam_right = camera.global_basis.x
		var look_target = active_fish_3d.global_position + cam_right
		# In fighting mode, make it more erratic
		if is_fighting:
			look_target += Vector3(sin(Time.get_ticks_msec()*0.01), cos(Time.get_ticks_msec()*0.01), 0) * 0.5
		
		var current_quat = active_fish_3d.quaternion
		var look_dir = cam_right
		if is_fighting:
			look_dir += Vector3(sin(Time.get_ticks_msec()*0.01), cos(Time.get_ticks_msec()*0.01), 0) * 0.5
		
		# Ensure look_dir is not zero before look_at
		if look_dir.length_squared() > 0.001:
			active_fish_3d.look_at(active_fish_3d.global_position + look_dir, Vector3.UP)
			var target_quat = active_fish_3d.quaternion
			active_fish_3d.quaternion = current_quat.slerp(target_quat, 6.0 * get_process_delta_time())
		
		if is_fighting:
			active_fish_3d.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.3
			active_fish_3d.rotation.x = cos(Time.get_ticks_msec() * 0.015) * 0.1


func _on_nearby_visual_update(fish_list: Array) -> void:
	while nearby_fish_nodes.size() < fish_list.size():
		var node = Node3D.new()
		add_child(node)
		nearby_fish_nodes.append(node)
	
	for i in range(nearby_fish_nodes.size()):
		var node: Node3D = nearby_fish_nodes[i]
		if i >= fish_list.size():
			node.hide()
			continue
		
		var f_data_2d = fish_list[i]
		var f_id = f_data_2d.get("fish_id", "ca_thu")
		
		if node.get_meta("fish_id", "") != f_id:
			for child in node.get_children(): child.queue_free()
			var asset_path = fish_id_to_asset.get(f_id, "res://assets/sprites/ca/guppy_fish.glb")
			var fish_scene = load(asset_path)
			if fish_scene:
				var fish_instance = fish_scene.instantiate()
				fish_instance.position = Vector3.ZERO
				fish_instance.rotation.y = PI/2
				node.add_child(fish_instance)
				
				# Setup real animations from GLB
				_setup_fish_animation(fish_instance, 1.0 + f_data_2d.speed * 0.01)
			node.set_meta("fish_id", f_id)
		
		var pos_2d = Vector2(f_data_2d.x, f_data_2d.y)
		var depth_y = lerpf(water_level_y, water_level_y - bait_max_depth_3d, bait_depth_ratio)
		var ray_origin = camera.project_ray_origin(pos_2d)
		var ray_normal = camera.project_ray_normal(pos_2d)
		
		var target_pos = Vector3.ZERO
		if abs(ray_normal.y) > 0.0001:
			var t = (depth_y - ray_origin.y) / ray_normal.y
			target_pos = ray_origin + ray_normal * t
		else:
			target_pos = ray_origin + ray_normal * 10.0
		
		# Smooth position
		node.global_position = node.global_position.lerp(target_pos, 5.0 * get_process_delta_time())
		
		var s = f_data_2d.size * 0.003
		node.scale = node.scale.lerp(Vector3(s, s, s), 4.0 * get_process_delta_time())
		
		# Smooth rotation
		var cam_right = camera.global_basis.x
		var current_quat = node.quaternion
		var look_dir = cam_right * f_data_2d.dir
		# Avoid zero vector look_at
		if look_dir.length_squared() > 0.001:
			node.look_at(node.global_position + look_dir, Vector3.UP)
			var target_quat = node.quaternion
			node.quaternion = current_quat.slerp(target_quat, 6.0 * get_process_delta_time())
		
		# Vertical tilt for nearby fish
		var vertical_vel = sin(Time.get_ticks_msec() * 0.002 + i) # Approximation of its wave move
		node.rotation.z = vertical_vel * 0.15 * (1.0 if f_data_2d.dir >= 0 else -1.0)
		
		node.show()


func _on_fishing_child_entered(node: Node) -> void:
	if node.has_signal("boss_visual_update"):
		node.boss_visual_update.connect(_on_boss_visual_update)


func _on_boss_visual_update(pos_2d: Vector2, fish_data: Object, p_visible: bool) -> void:
	_on_visual_fish_update(pos_2d, fish_data, p_visible, true)


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
	if state == GameState.UI_OPEN: return
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
	if state == GameState.UI_OPEN: return
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
	if state == GameState.UI_OPEN: return
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
	if state == GameState.UI_OPEN: return
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
		var zone_center_2d = (zone.world_x_start + zone.world_x_end) / 2.0
		var x_3d = (zone_center_2d / 12000.0) * world_width - world_width / 2.0
		boat.position.x = x_3d
		current_zone_info = zone


func _setup_fish_animation(node: Node, anim_speed: float = 1.0) -> void:
	var anim_player: AnimationPlayer = null
	
	# Tìm AnimationPlayer trong node hoặc con của nó
	if node is AnimationPlayer:
		anim_player = node
	else:
		anim_player = node.get_node_or_null("AnimationPlayer")
		if not anim_player:
			for child in node.get_children():
				if child is AnimationPlayer:
					anim_player = child
					break
				var deeper = child.get_node_or_null("AnimationPlayer")
				if deeper:
					anim_player = deeper
					break
	
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if anim_list.is_empty():
			return
			
		var anim_to_play = ""
		
		# Ưu tiên tìm các animation có tên liên quan đến "swim"
		var swim_keywords = ["swim", "swimming", "move", "action"]
		for key in swim_keywords:
			for a in anim_list:
				if a.to_lower().contains(key):
					anim_to_play = a
					break
			if anim_to_play != "": break
			
		# Nếu không tìm thấy, chơi animation đầu tiên
		if anim_to_play == "":
			anim_to_play = anim_list[0]
			
		if anim_to_play != "":
			# Đảm bảo animation lặp (loop)
			var anim = anim_player.get_animation(anim_to_play)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			
			anim_player.play(anim_to_play)
			anim_player.speed_scale = anim_speed
