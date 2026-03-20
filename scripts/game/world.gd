extends Node3D

## 3D Game World — manages boat, ocean, camera, fishing spots, zones

signal return_to_menu
signal go_to_village

enum GameState { NAVIGATING, FISHING, MINIGAME, UI_OPEN }
var state: GameState = GameState.NAVIGATING

enum CameraMode { BOAT_THIRD_PERSON, TOP_DOWN_FISHING, BAIT_FOLLOW }
var camera_mode: CameraMode = CameraMode.BOAT_THIRD_PERSON

# World
var world_width: float = 500.0  # 3D units
var world_depth: float = 100.0  # 3D units (Z range)
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

# Underwater layers
var mist_particles: GPUParticles3D = null
var plankton_particles: GPUParticles3D = null
var underwater_plane: MeshInstance3D = null
var underwater_props_root: Node3D = null
var seaweed_nodes: Array = []
var seabed_noise: FastNoiseLite = null
var bubble_nodes: Array = []
var bubble_spawn_timer: float = 0.0
var bubble_spawn_interval: float = 1.6

# Dynamic Chunk Loading
var spawned_chunks: Dictionary = {} # {chunk_index: Node3D}
const CHUNK_SIZE: float = 30.0
const LOAD_RADIUS: int = 1 # Tải khối hiện tại và 1 khối kế bên
var last_chunk_index: int = -999

# Underwater assets (optional)
var underwater_prop_catalog = [
	# ĐÃ SỬA: Thêm "sprites/sanho/" vào đường dẫn
	{"type": "coral", "path": "res://assets/sprites/sanho/coral.glb"}, 
	{"type": "rock", "path": "res://assets/sprites/rock/river_rock.glb"},
	{"type": "seaweed", "path": "res://assets/sprites/seaweed/sea_weed.glb"},
	{"type": "coral_main", "path": "res://assets/sprites/sanho/coral.glb"},
	{"type": "coral_piece", "path": "res://assets/sprites/sanho/coral_piece.glb"},
	{"type": "starfish", "path": "res://assets/sprites/saobien/starfish.glb"},
	{"type": "deep_coral", "path": "res://assets/sprites/sanho/deep-sea_corals.glb"}
]

# References (set in _ready from scene tree)
var boat: Node3D = null
var camera: Camera3D = null
var hud: Control = null
var fishing_mode_node = null
var ocean: MeshInstance3D = null
var ocean_mesh: MeshInstance3D = null

# Fishing
var fishing_spots: Array = []
var _key_held_t: bool = false
var _key_held_u: bool = false
var _is_fish_fighting: bool = false

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
	"ca_thu": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"ca_mu": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"ca_nuc": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"ca_chim": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_hong": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_bop": "res://assets/sprites/ca/paracheirodon_innesi___tetra_neon.glb",
	"ca_ngu": "res://assets/sprites/ca/jikin_goldfish.glb",
	"ca_kiem": "res://assets/sprites/ca/model_62a_-_shortfin_mako.glb",
	"ca_map": "res://assets/sprites/ca/model_62a_-_shortfin_mako.glb",
	"muc_khong_lo": "res://assets/sprites/ca/bream_fish__dorade_royale.glb",
	"rong_bien": "res://assets/sprites/ca/jikin_goldfish.glb",
	"rua_vang": "res://assets/sprites/ca/jikin_goldfish.glb"
}

# Environment time
var day_night_time: float = 0.0
var sun_light: DirectionalLight3D = null
var env: WorldEnvironment = null

# Moon and Stars
var moon_mesh: MeshInstance3D = null
var stars_mesh: Node3D = null


func _ready() -> void:
	# BƯỚC SỬA LỖI: Get references một cách an toàn tuyệt đối
	boat = get_node_or_null("Boat3D")
	camera = get_node_or_null("Camera3D")
	ocean_mesh = get_node_or_null("OceanMesh") 
	ocean = ocean_mesh # Đỡ phải tìm 2 lần
	
	
	if camera:
		camera.current = true
		if camera.get_script():
			camera.set_process(false)
			camera.set_physics_process(false)
			camera.set_process_input(false)
			camera.set_process_unhandled_input(false)
		default_camera_fov = camera.fov
			
	hud_canvas = get_node_or_null("HUD")
	hud = get_node_or_null("HUD/HUDControl")
	sun_light = get_node_or_null("DirectionalLight3D")
	env = get_node_or_null("WorldEnvironment")
	
	_sync_water_level()

	# Initialize seabed noise
	seabed_noise = FastNoiseLite.new()
	seabed_noise.seed = randi()
	seabed_noise.frequency = 0.04
	seabed_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Underwater layers
	_setup_underwater_layers()
	
	if ocean and camera:
		if ocean.has_method("set"): 
			ocean.follow_camera = camera
	
	_setup_moon_and_stars()
	
	# Generate fishing spots
	_generate_fishing_spots()
	
	# Spawn decorative fish
	_spawn_decorative_fish()
	
	# Initial zone
	if boat:
		current_zone_info = ZoneDatabase.get_zone_at_position(boat.position.x * 60.0)
	
	# Keyboard shortcut hints on HUD
	if hud and hud.has_method("show_message"):
		hud.show_message("W/S: Ga | A/D: Lai | E: Cau | M: Ban do | T: Cho | U: Nang cap | B: Ve lang")


func _process(delta: float) -> void:
	if state == GameState.NAVIGATING:
		_process_navigation(delta)
	
	# Cập nhật sóng (thuyền dập dìu) trước tiên
	_update_boat_waves(delta)
	
	# Cập nhật góc nhìn và ánh sáng
	_update_camera(delta)
	_update_lighting(delta)
	
	# Cập nhật La bàn trên UI
	if hud and boat:
		hud.boat_rotation = boat.rotation.y
	
	# Các hiệu ứng môi trường
	_update_decorative_fish(delta)
	_update_seaweed(delta)
	_update_bubbles(delta)
	_sync_water_level()
	_update_underwater_effects(delta)
	
	# Xử lý Map và tải khu vực
	_check_zone()
	_update_dynamic_chunks()

func _process_navigation(_delta: float) -> void:
	var steer_input = 0.0
	if Input.is_action_pressed("move_right"): steer_input = 1.0
	elif Input.is_action_pressed("move_left"): steer_input = -1.0

	var throttle_input = 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): throttle_input += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): throttle_input -= 1.0
	
	if boat:
		# Vẫn truyền tín hiệu cho tàu (phòng hờ script tàu cần dùng cho hiệu ứng chân vịt/âm thanh)
		if "steer_input" in boat: boat.steer_input = steer_input
		if "throttle_input" in boat: boat.throttle_input = throttle_input
		
		# ========================================================
		# ĐỘNG CƠ DỰ PHÒNG: ÉP THUYỀN CHẠY TRỰC TIẾP TỪ WORLD.GD
		# ========================================================
		var turn_speed = 0.5  # Tốc độ quay vô lăng (chỉnh to lên nếu muốn cua gắt)
		var move_speed = 3.5 # Tốc độ chạy tới/lui (chỉnh to lên nếu muốn chạy nhanh)
		
		# 1. Ép thuyền quay trái/phải
		if steer_input != 0.0:
			boat.rotate_y(-steer_input * turn_speed * _delta)
			
		# 2. Ép thuyền lướt tới/lui
		if throttle_input != 0.0:
			# Dựa theo cấu trúc code camera của bạn, mũi thuyền đang hướng về trục X
			var forward_dir = boat.global_basis.x.normalized()
			boat.global_position += forward_dir * throttle_input * move_speed * _delta
		
		# ========================================================
		
		# Giới hạn không cho tàu chạy ra khỏi mép bản đồ
		var half_w = world_width / 2.0
		var half_d = world_depth / 2.0
		if boat.position.x < -half_w or boat.position.x > half_w or boat.position.z < -half_d or boat.position.z > half_d:
			boat.position.x = clampf(boat.position.x, -half_w, half_w)
			boat.position.z = clampf(boat.position.z, -half_d, half_d)
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_check_fishing_spot()
	if Input.is_action_just_pressed("pause"):
		return_to_menu.emit()
	if Input.is_action_just_pressed("open_map"):
		_open_map()
	if Input.is_action_just_pressed("open_collection"):
		_open_collection()
	if Input.is_action_just_pressed("go_to_village") or Input.is_action_just_pressed("return_to_game"):
		go_to_village.emit()
	if Input.is_physical_key_pressed(KEY_T) and not _key_held_t:
		_key_held_t = true
		_open_market()
	elif not Input.is_physical_key_pressed(KEY_T):
		_key_held_t = false
	if Input.is_physical_key_pressed(KEY_U) and not _key_held_u:
		_key_held_u = true
		_open_shop()
	elif not Input.is_physical_key_pressed(KEY_U):
		_key_held_u = false


func _update_camera(delta: float) -> void:
	if camera and boat:
		if camera_mode == CameraMode.BAIT_FOLLOW:
			# Lấy tọa độ mồi ban đầu (đang bị lỗi ném quá xa)
			var raw_bait_x3d = _x2d_to_3d(bait_x2d)
			
			# === ĐÃ SỬA: KÉO MỒI CÂU LẠI GẦN SÁT MẠN THUYỀN ===
			# Tính xem mồi đang bị văng ra cách thuyền bao xa
			var dist_from_boat = raw_bait_x3d - boat.position.x
			# Bóp nhỏ khoảng cách ném lại và giới hạn TỐI ĐA chỉ được ném xa 8 mét
			var safe_dist = clampf(dist_from_boat * 0.3, -8.0, 8.0) 
			var bait_x3d = boat.position.x + safe_dist
			# ===================================================
			
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
			# Chase camera: GÓC NHÌN LÁI TÀU
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

	# Make night actually dark even with HDRI sky:
	# - Force ambient from COLOR (not SKY), so we can control it.
	# - Reduce background energy at night to avoid "washed-out" bright scenes.
	if env and env.environment:
		var e := env.environment
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		
		# Start darkening from 18:00, finish by 20:00.
		var h := fposmod(TimeWeather.game_hour, 24.0)
		var t := clampf((h - 18.0) / 2.0, 0.0, 1.0) # 0 at 18:00, 1 at 20:00
		if period == "night":
			t = 1.0
		
		var day_col := Color(0.95, 0.98, 1.0)
		var night_col := Color(0.18, 0.22, 0.32) # Sáng hơn xíu
		e.ambient_light_color = day_col.lerp(night_col, t)
		e.ambient_light_energy = lerpf(1.0, 0.28, t) # Từ 0.18 lên 0.28
		e.background_energy_multiplier = lerpf(1.0, 0.35, t) # Từ 0.25 lên 0.35
	
	# Update Sky colors from TimeWeather
	if env and env.environment and env.environment.sky:
		var sky_mat = env.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			sky_mat.sky_top_color = TimeWeather.get_sky_top_color()
			sky_mat.sky_horizon_color = TimeWeather.get_sky_bottom_color()
	
	# Update Ocean Shader with lighting
	var target_ocean_mesh: MeshInstance3D = ocean_mesh
	if target_ocean_mesh == null and ocean is MeshInstance3D:
		target_ocean_mesh = ocean as MeshInstance3D
	if target_ocean_mesh and target_ocean_mesh.material_override:
		var mat = target_ocean_mesh.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("sun_color", sun_light.light_color)
			# Calculate factor based on sun elevation
			var sun_factor = clamp(1.0 - TimeWeather.get_sun_position_normalized(), 0.0, 1.0)
			# Push factor higher during sunset/dawn
			if period == "evening" or period == "dawn":
				sun_factor = max(sun_factor, 0.6)
			mat.set_shader_parameter("sun_factor", sun_factor)
	
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


# ==========================================
# THÊM MỚI: HIỆU ỨNG SƯƠNG MŨ DƯỚI NƯỚC (FOG)
# ==========================================
func _update_underwater_effects(delta: float) -> void:
	if env and env.environment and camera:
		var cam_y = camera.global_position.y
		
		# Dời bầy bụi phù du đi theo camera để luôn thấy bụi
		if plankton_particles:
			plankton_particles.global_position = camera.global_position
			
		if cam_y < water_level_y:
			# ... (dưới nước giữ nguyên) ...
			if plankton_particles: plankton_particles.emitting = true
		else:
			# === ĐÃ SỬA: Thêm sương mù mù mù nhẹ nhàng post-processing khi trên trời ===
			# Đặt density thấp hơn, but increase it as camera gets higher
			env.environment.volumetric_fog_enabled = true
			env.environment.volumetric_fog_albedo = Color(0.8, 0.9, 1.0) # Màu trời mù tươi
			
			# Tính toán density mù dựa trên độ cao
			var mist_density = 0.002
			if cam_y > water_level_y + 10.0:
				mist_density = clampf(0.002 + (cam_y - 10.0) * 0.001, 0.002, 0.01)
				
			env.environment.volumetric_fog_density = lerpf(env.environment.volumetric_fog_density, mist_density, delta * 3.0)
			
			if plankton_particles: plankton_particles.emitting = false


func _check_zone() -> void:
	if boat == null:
		return
	# Convert 3D position to 2D zone position
	var world_x = (boat.position.x + world_width / 2.0) / world_width * 12000.0
	var new_zone = ZoneDatabase.get_zone_at_position(world_x)
	
	if new_zone and (current_zone_info == null or new_zone.id != current_zone_info.id):
		current_zone_info = new_zone
		AudioManager.play_zone_enter()
		if hud and hud.has_method("show_zone_name"):
			hud.show_zone_name(current_zone_info.name_vn)
		
		# Tái tạo môi trường khi sang map mới
		_respawn_underwater_props()
		_spawn_decorative_fish() # THÊM DÒNG NÀY: Xóa cá map cũ, đẻ cá map mới


func _sync_water_level() -> void:
	if ocean_mesh:
		water_level_y = ocean_mesh.global_position.y
		if underwater_plane and is_instance_valid(underwater_plane):
			underwater_plane.position.y = water_level_y - 12.0 # Kéo đáy biển sâu xuống tí xíu


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


func _setup_underwater_layers() -> void:
	_create_underwater_plane()
	_respawn_underwater_props()


func _create_underwater_plane() -> void:
	if underwater_plane and is_instance_valid(underwater_plane):
		underwater_plane.queue_free()
	underwater_plane = MeshInstance3D.new()
	underwater_plane.name = "UnderwaterDepthPlane"
	
	# Tạo Mesh gồ ghề bằng SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var size = Vector2(400, 80)
	var subdiv = Vector2i(80, 20)
	var step_x = size.x / subdiv.x
	var step_z = size.y / subdiv.y
	
	for z in range(subdiv.y + 1):
		for x in range(subdiv.x + 1):
			var px = -size.x/2.0 + x * step_x
			var pz = -size.y/2.0 + z * step_z
			var py = seabed_noise.get_noise_2d(px, pz) * 5.0 # Độ cao tối đa 5.0 đơn vị
			
			st.set_uv(Vector2(float(x)/subdiv.x * 40, float(z)/subdiv.y * 10))
			st.add_vertex(Vector3(px, py, pz))
			
	for z in range(subdiv.y):
		for x in range(subdiv.x):
			var i = z * (subdiv.x + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + subdiv.x + 1)
			
			st.add_index(i + 1)
			st.add_index(i + subdiv.x + 2)
			st.add_index(i + subdiv.x + 1)
			
	st.generate_normals()
	underwater_plane.mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	var tex = load("res://assets/sprites/under-sea/4e153ad6124e9c10c55f.jpg")
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.08, 0.3, 0.45, 1.0)
	
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	underwater_plane.material_override = mat
	
	underwater_plane.position = Vector3(0, water_level_y - 12.0, 0)
	add_child(underwater_plane)


func _respawn_underwater_props() -> void:
	if underwater_props_root and is_instance_valid(underwater_props_root):
		underwater_props_root.queue_free()
	underwater_props_root = Node3D.new()
	underwater_props_root.name = "UnderwaterProps"
	add_child(underwater_props_root)
	seaweed_nodes.clear()
	# Các khối sẽ tự động được load trong _process thông qua _update_dynamic_chunks

# ==========================================
# HỆ THỐNG TẢI MAP THEO CHUNK (TỐI ƯU LAG)
# ==========================================
func _update_dynamic_chunks() -> void:
	if boat == null: return
	
	var current_chunk = int(floor(boat.position.x / CHUNK_SIZE))
	
	# Chỉ xử lý nếu tàu đã sang chunk mới
	if current_chunk != last_chunk_index:
		last_chunk_index = current_chunk
		
		# 1. Tạo các chunk mới trong tầm nhìn (hiện tại và lân cận)
		for i in range(current_chunk - LOAD_RADIUS, current_chunk + LOAD_RADIUS + 1):
			if not spawned_chunks.has(i):
				_spawn_chunk(i)
		
		# 2. Xóa các chunk đã ở quá xa
		var chunks_to_remove = []
		for idx in spawned_chunks.keys():
			if abs(idx - current_chunk) > LOAD_RADIUS + 1:
				chunks_to_remove.append(idx)
		
		for idx in chunks_to_remove:
			var chunk_node = spawned_chunks[idx]
			if is_instance_valid(chunk_node):
				chunk_node.queue_free()
			spawned_chunks.erase(idx)
			
		# Cập nhật danh sách rong biển để chạy hiệu ứng animation
		_sync_seaweed_nodes()

func _spawn_chunk(idx: int) -> void:
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_" + str(idx)
	underwater_props_root.add_child(chunk_node)
	spawned_chunks[idx] = chunk_node
	
	var profile = _get_zone_profile()
	var count_per_chunk = 8 # Số lượng cố định mỗi khối để ổn định hiệu năng
	var weights: Dictionary = profile.get("weights", {})
	
	var start_x = idx * CHUNK_SIZE
	var end_x = start_x + CHUNK_SIZE
	
	for i in range(count_per_chunk):
		var picked = _pick_underwater_prop(weights)
		if picked.is_empty(): continue
		
		var scene: PackedScene = picked["scene"]
		var p: Node3D = scene.instantiate() if scene else _create_underwater_fallback(str(picked["type"]))
		chunk_node.add_child(p)
		
		if scene:
			_setup_node_animation(p, randf_range(0.8, 1.2))
		
		var spawn_x = randf_range(start_x, end_x)
		var spawn_z = randf_range(-25.0, 25.0)
		var noise_y = seabed_noise.get_noise_2d(spawn_x, spawn_z) * 5.0
		var ground_y = (water_level_y - 12.0) + noise_y
		
		p.position = Vector3(spawn_x, ground_y, spawn_z)
		p.set_meta("type", str(picked["type"]))
		
		# Tinh chỉnh kích thước đồng bộ
		var s = randf_range(0.5, 2.0)
		var type = str(picked["type"])
		if type == "starfish": s = randf_range(0.1, 0.3)
		elif type == "coral_main": s = randf_range(0.05, 0.15)
		elif type.contains("coral"): s = randf_range(0.1, 0.4)
		elif type == "seaweed": s = randf_range(0.6, 1.5)
		elif type == "rock": s = randf_range(0.8, 2.5)
		p.scale = Vector3(s, s, s)
		p.rotation.y = randf() * TAU

func _sync_seaweed_nodes() -> void:
	seaweed_nodes.clear()
	for chunk in spawned_chunks.values():
		# ĐIỂM SỬA LỖI: Kiểm tra xem chunk này còn tồn tại không, nếu là "bóng ma" thì bỏ qua
		if not is_instance_valid(chunk):
			continue
			
		for p in chunk.get_children():
			if p.get_meta("type", "") == "seaweed":
				seaweed_nodes.append(p)



func _get_zone_profile() -> Dictionary:
	var zone_id := "" if current_zone_info == null else str(current_zone_info.id).to_lower()
	
	# Định nghĩa base weights cho mọi khu vực để đảm bảo loại nào cũng có thể xuất hiện
	var weights = {
		"seaweed": 0.2,
		"rock": 0.2,
		"coral": 0.1,
		"coral_main": 0.1,
		"coral_piece": 0.1,
		"starfish": 0.1,
		"deep_coral": 0.05
	}
	var count = 30
	
	# Tinh chỉnh theo khu vực
	if zone_id.find("coast") != -1 or zone_id.find("shore") != -1 or zone_id.find("coastal") != -1:
		count = 35
		weights["seaweed"] = 0.5
		weights["starfish"] = 0.2
	elif zone_id.find("reef") != -1:
		count = 45
		weights["coral_main"] = 0.4
		weights["coral"] = 0.3
		weights["starfish"] = 0.1
	elif zone_id.find("offshore") != -1 or zone_id.find("open") != -1:
		count = 32
		weights["coral_piece"] = 0.3
		weights["starfish"] = 0.2
		weights["rock"] = 0.3
	elif zone_id.find("abyss") != -1 or zone_id.find("deep") != -1:
		count = 25
		weights["deep_coral"] = 0.4
		weights["rock"] = 0.4
	
	return {"count": count, "weights": weights}


func _pick_underwater_prop(weights: Dictionary) -> Dictionary:
	var available: Array = []
	for item in underwater_prop_catalog:
		# ĐIỂM SỬA: Kiểm tra file có tồn tại thật ngoài đời không trước khi load
		if ResourceLoader.exists(item["path"]):
			var scene = load(item["path"])
			available.append({"type": item["type"], "scene": scene})
		else:
			# Nếu mất file thì dùng đồ giả (fallback) thay vì báo lỗi đỏ
			available.append({"type": item["type"], "scene": null}) 
			
	if available.is_empty():
		return {}
		
	var total_weight := 0.0
	for item in available:
		total_weight += float(weights.get(item.type, 0.0))
		
	if total_weight <= 0.0:
		return available.pick_random()
		
	var roll = randf() * total_weight
	var acc = 0.0
	for item in available:
		acc += float(weights.get(item.type, 0.0))
		if roll <= acc:
			return item
			
	return available[0]


# Hàm cũ đã được thay thế bởi hệ thống chunk
func _spawn_underwater_props() -> void:
	pass


func _create_underwater_fallback(kind: String) -> Node3D:
	var mesh_instance = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	
	# Đã chỉnh sửa: Phối lại màu dịu mắt hơn, thêm độ nhám để trông bớt giống cục nhựa
	mat.roughness = 0.8 
	
	if kind == "coral":
		var mesh = SphereMesh.new()
		mesh.radius = 0.4
		mesh.height = 0.8
		mesh_instance.mesh = mesh
		mat.albedo_color = Color(0.75, 0.4, 0.5, 1.0)
	elif kind == "seaweed":
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.12
		mesh.height = 1.2
		mesh_instance.mesh = mesh
		mat.albedo_color = Color(0.15, 0.45, 0.3, 1.0)
	else:
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.8, 0.5, 0.6)
		mesh_instance.mesh = mesh
		mat.albedo_color = Color(0.2, 0.35, 0.4, 1.0)
		
	mesh_instance.material_override = mat
	var wrapper = Node3D.new()
	wrapper.add_child(mesh_instance)
	return wrapper


func _update_seaweed(_delta: float) -> void:
	for weed in seaweed_nodes:
		if weed == null:
			continue
		weed.rotation.z = sin(Time.get_ticks_msec() * 0.001 + weed.position.x) * 0.1


func _spawn_bubble() -> void:
	var b = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = randf_range(0.05, 0.15)
	b.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b.material_override = mat
	add_child(b)

	b.position = Vector3(
		randf_range(-10.0, 10.0),
		water_level_y - 5.0,
		randf_range(-5.0, 5.0)
	)

	bubble_nodes.append({
		"node": b,
		"speed": randf_range(0.6, 1.6),
		"life": randf_range(3.0, 6.0)
	})


func _update_bubbles(delta: float) -> void:
	bubble_spawn_timer += delta
	if bubble_spawn_timer >= bubble_spawn_interval:
		bubble_spawn_timer = 0.0
		_spawn_bubble()

	for i in range(bubble_nodes.size() - 1, -1, -1):
		var data = bubble_nodes[i]
		var node: Node3D = data["node"]
		if node == null:
			bubble_nodes.remove_at(i)
			continue
		data["life"] = float(data["life"]) - delta
		node.position.y += float(data["speed"]) * delta
		bubble_nodes[i] = data
		if float(data["life"]) <= 0.0 or node.position.y > water_level_y + 1.0:
			node.queue_free()
			bubble_nodes.remove_at(i)


# ==========================================
# SPAWN CÁ THEO KHU VỰC VÀ BÁM SÁT THUYỀN
# ==========================================
func _spawn_decorative_fish() -> void:
	for fish in fish_nodes:
		if is_instance_valid(fish["node"]):
			fish["node"].queue_free()
	fish_nodes.clear()
	
	var boat_x = 0.0
	if boat != null: boat_x = boat.position.x

	var zone_id = "coastal"
	if current_zone_info != null:
		zone_id = current_zone_info.id

	var all_fish_types = FishDatabase.get_all_fish()
	var zone_fish = []
	for f in all_fish_types:
		if zone_id in f.zones: 
			zone_fish.append(f)
			
	if zone_fish.is_empty(): zone_fish = all_fish_types

	var school_count = 6
	if zone_id in ["deep_sea", "abyss"]: school_count = 3 

	for b in range(school_count):
		var f_data = zone_fish.pick_random()
		var fallback_path = "res://assets/sprites/ca/bream_fish__dorade_royale.glb"
		var asset_path = fish_id_to_asset.get(f_data.id, fallback_path)
		var fish_scene = load(asset_path)
		if not fish_scene: continue
		
		var spawn_x = boat_x + randf_range(-35.0, 35.0)
		var spawn_y = water_level_y - randf_range(2.0, 10.0)
		
		if zone_id == "coral_reef": spawn_y = water_level_y - randf_range(5.0, 15.0)
		elif zone_id == "open_sea": spawn_y = water_level_y - randf_range(8.0, 18.0)
		elif zone_id in ["deep_sea", "abyss"]: spawn_y = water_level_y - randf_range(15.0, 25.0)
			
		var school_center = Vector3(spawn_x, spawn_y, randf_range(-15.0, 10.0))
		var school_size = randi_range(2, 5) 
		if f_data.rarity in ["epic", "legendary"] or f_data.max_size > 2.0: school_size = 1 
		
		for i in range(school_size):
			var fish_instance = fish_scene.instantiate()
			_fix_fish_material(fish_instance)
			var wrapper = Node3D.new()
			add_child(wrapper)
			wrapper.add_child(fish_instance)
			
			fish_instance.position = Vector3.ZERO
			fish_instance.rotation.y = PI
			
			wrapper.position = school_center + Vector3(randf_range(-3, 3), randf_range(-1, 1), randf_range(-3, 3))
			
			var base_scale = f_data.max_size * 0.03
			var s = clampf(base_scale, 0.08, 0.4)
			if f_data.rarity == "legendary": s = clampf(base_scale, 0.2, 0.6)
			
			if asset_path.contains("jikin_goldfish"): s *= 0.03
			elif asset_path.contains("model_62a"): s *= 0.012
			elif asset_path.contains("bream_fish"): s *= 0.3
				
			wrapper.scale = Vector3(s * randf_range(0.85, 1.15), s * randf_range(0.85, 1.15), s * randf_range(0.85, 1.15))
			_setup_fish_animation(fish_instance, 1.0 + f_data.speed * 0.02)
			
			fish_nodes.append({
				"node": wrapper,
				"base_speed": f_data.speed * 0.04 + randf_range(-0.01, 0.01),
				"velocity": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * f_data.speed * 0.04,
				"target_pos": wrapper.position,
				"think_timer": 0.0
			})

# ==========================================
# AI CÁ BƠI LƯỢN (BÁM SÁT THUYỀN THEO KHU VỰC)
# ==========================================
func _update_decorative_fish(delta: float) -> void:
	for fish in fish_nodes:
		var node: Node3D = fish["node"]
		if not is_instance_valid(node): continue
		
		# 1. TƯ DUY TÌM ĐƯỜNG MỚI
		fish["think_timer"] -= delta
		if fish["think_timer"] <= 0.0 or node.global_position.distance_to(fish["target_pos"]) < 1.5:
			fish["think_timer"] = randf_range(3.0, 7.0)
			
			var forward_dir = fish["velocity"].normalized()
			if forward_dir == Vector3.ZERO: forward_dir = Vector3.FORWARD
			
			var random_steer = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
			var new_dir = (forward_dir * 1.5 + random_steer).normalized()
			fish["target_pos"] = node.global_position + new_dir * randf_range(5.0, 15.0)
			
			var current_boat_x = boat.position.x if boat != null else 0.0
			
			# Xích cá lại, không cho bơi cách thuyền quá 45 mét
			fish["target_pos"].x = clampf(fish["target_pos"].x, current_boat_x - 45.0, current_boat_x + 45.0)
			
			# Lặn không vượt quá đáy hoặc nổi lên quá mặt nước (dùng chung cho mọi loại cá)
			fish["target_pos"].y = clampf(fish["target_pos"].y, water_level_y - 25.0, water_level_y - 2.0)
			fish["target_pos"].z = clampf(fish["target_pos"].z, -15.0, 15.0)
			
		# 2. BẺ LÁI & DI CHUYỂN
		var desired_velocity = (fish["target_pos"] - node.global_position).normalized() * fish["base_speed"]
		fish["velocity"] = fish["velocity"].lerp(desired_velocity, delta * 1.2)
		node.global_position += fish["velocity"] * delta

		# === ĐÃ SỬA: ÉP VỊ TRÍ Y CỦA CÁ LUÔN NẰM DƯỚI NƯỚC ===
		# Ngăn cá bay lên, ngay cả khi quán tính cố gắng đẩy chúng lên.
		# Đặt cách mặt nước ít nhất 1.5 đơn vị để tránh Z-fighting.
		node.global_position.y = min(node.global_position.y, water_level_y - 1.5)
		
		if node.global_position.y >= water_level_y - 3.5:
			node.global_position.y = water_level_y - 3.5
		
		if fish["velocity"].length_squared() > 0.001:
			var look_target = node.global_position + fish["velocity"]
			var current_quat = node.quaternion
			
			node.look_at(look_target, Vector3.UP)
			var target_quat = node.quaternion
			node.quaternion = current_quat.slerp(target_quat, 3.0 * delta)
			
			var pitch_angle = clampf(fish["velocity"].y * 1.5, -0.4, 0.4)
			node.rotation.x = lerp_angle(node.rotation.x, pitch_angle, 4.0 * delta)
			
			var turn_rate = current_quat.angle_to(target_quat)
			var turn_dir = sign(current_quat.get_axis().dot(Vector3.UP)) 
			if turn_dir == 0: turn_dir = 1.0 
			var roll_angle = turn_rate * turn_dir * -1.5 
			
			node.rotation.z = lerp_angle(node.rotation.z, clampf(roll_angle, -0.6, 0.6), 2.0 * delta)

func _check_fishing_spot() -> void:
	if boat == null: return
	for spot in fishing_spots:
		var dist = Vector2(boat.position.x - spot["x3d"], boat.position.z).length()
		if dist < 3.0:
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
	# === ĐÃ SỬA: Tắt cờ trạng thái camera ===
	_is_fish_fighting = false
	
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
	# === ĐÃ SỬA: Cập nhật cờ trạng thái camera ===
	_is_fish_fighting = is_fighting
	
	if not p_visible or fish_data == null:
		if active_fish_3d: active_fish_3d.hide()
		return
	
	if active_fish_3d == null or active_fish_data != fish_data:
		if active_fish_3d: active_fish_3d.queue_free()
		
		var asset_path = fish_id_to_asset.get(fish_data.id, "res://assets/sprites/ca/bream_fish__dorade_royale.glb")
		var fish_scene = load(asset_path)
		if not fish_scene: return
		
		var fish_instance = fish_scene.instantiate()
		_fix_fish_material(fish_instance)
		active_fish_3d = Node3D.new()
		add_child(active_fish_3d)
		active_fish_3d.add_child(fish_instance)
		
		_setup_node_animation(fish_instance, 1.2)
		
		fish_instance.position = Vector3.ZERO
		fish_instance.rotation.y = PI/2
		active_fish_data = fish_data
	
	if active_fish_3d:
		active_fish_3d.show()
		var ray_origin = camera.project_ray_origin(pos_2d)
		var ray_normal = camera.project_ray_normal(pos_2d)
		var depth_y = lerpf(water_level_y, water_level_y - bait_max_depth_3d, bait_depth_ratio) # Loại bỏ offset để khớp mồi
		var cam_forward = -camera.global_basis.z
		
		# Vị trí gốc của cục mồi
		var base_target_pos = Vector3.ZERO
		if abs(ray_normal.y) > 0.0001:
			var t = (depth_y - ray_origin.y) / ray_normal.y
			base_target_pos = ray_origin + ray_normal * t
		else:
			base_target_pos = ray_origin + ray_normal * 10.0
		
		base_target_pos += cam_forward * 0.5
		var final_target_pos = base_target_pos
		var time_sec = Time.get_ticks_msec() * 0.001
		
		# ==========================================
		# LOGIC DI CHUYỂN: VỜN MỒI & CẮN CÂU
		# ==========================================
		if is_fighting:
			# Đã cắn câu: Giãy giụa loạn xạ quanh trục mồi
			final_target_pos += Vector3(sin(time_sec * 15.0), cos(time_sec * 20.0), sin(time_sec * 12.0)) * 0.5
		else:
			# VỜN MỒI: Lượn vòng tròn và nhấp nhô thăm dò
			var circle_radius = 1.2 # Bán kính vòng lượn
			var circling_speed = 2.5 # Tốc độ bơi quanh mồi
			# Hiệu ứng lao vào dạt ra (darting)
			var darting = sin(time_sec * 4.0) * 0.6 
			
			var offset_x = cos(time_sec * circling_speed) * (circle_radius + darting)
			var offset_z = sin(time_sec * circling_speed) * (circle_radius + darting)
			var offset_y = sin(time_sec * 3.0) * 0.3 # Nhấp nhô lên xuống
			
			final_target_pos += Vector3(offset_x, offset_y, offset_z)

		# Nội suy di chuyển mượt mà
		var follow_speed = 12.0 if is_fighting else 4.0
		active_fish_3d.global_position = active_fish_3d.global_position.lerp(final_target_pos, follow_speed * get_process_delta_time())
		
		if active_fish_3d.global_position.y > water_level_y - 2.0:
			active_fish_3d.global_position.y = water_level_y - 2.0
			
		# Scale kích thước cá
		var s = fish_data.max_size * 0.03
		if fish_data.id == "ca_map": s *= 0.015
		s = clampf(s, 0.08, 0.5)
		
		var asset_path = fish_id_to_asset.get(fish_data.id, "res://assets/sprites/ca/bream_fish__dorade_royale.glb")
		if asset_path.contains("jikin_goldfish"): s *= 0.03
		elif asset_path.contains("model_62a"): s *= 0.012
		elif asset_path.contains("bream_fish"): s *= 0.3
		
		active_fish_3d.scale = active_fish_3d.scale.lerp(Vector3(s, s, s), 5.0 * get_process_delta_time())
		
		# ==========================================
		# LOGIC XOAY HƯỚNG MẶT CÁ
		# ==========================================
		var current_quat = active_fish_3d.quaternion
		# Cá tự động nhìn theo hướng nó đang di chuyển (rất tự nhiên khi bơi lượn)
		var look_dir = final_target_pos - active_fish_3d.global_position
		
		if is_fighting:
			# Nếu đang giãy, hướng mặt cũng phải giật giật
			look_dir += Vector3(sin(time_sec * 25.0), cos(time_sec * 25.0), 0) * 1.0
			
		if look_dir.length_squared() > 0.001:
			active_fish_3d.look_at(active_fish_3d.global_position + look_dir, Vector3.UP)
			var target_quat = active_fish_3d.quaternion
			active_fish_3d.quaternion = current_quat.slerp(target_quat, (10.0 if is_fighting else 5.0) * get_process_delta_time())
		
		# Tạo độ nghiêng (Roll/Pitch) cho thêm phần sống động
		if is_fighting:
			active_fish_3d.rotation.z = sin(time_sec * 20.0) * 0.4 # Lật mình
			active_fish_3d.rotation.x = cos(time_sec * 15.0) * 0.2
		else:
			# Nghiêng người nhẹ khi ôm cua bơi vòng tròn
			active_fish_3d.rotation.z = sin(time_sec * 2.5) * 0.15

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
			var asset_path = fish_id_to_asset.get(f_id, "res://assets/sprites/ca/bream_fish__dorade_royale.glb")
			var fish_scene = load(asset_path)
			if fish_scene:
				var fish_instance = fish_scene.instantiate()
				_fix_fish_material(fish_instance)
				fish_instance.position = Vector3.ZERO
				fish_instance.rotation.y = PI/2
				node.add_child(fish_instance)
				
				# Setup real animations from GLB
				_setup_node_animation(fish_instance, 1.0 + f_data_2d.speed * 0.01)
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
		
		if node.global_position.y > water_level_y - 2.5:
			node.global_position.y = water_level_y - 2.5
			
		var s = f_data_2d.size * 0.0012
		if f_id == "ca_map": s *= 0.015
		s = clampf(s, 0.08, 0.5)
		
		var asset_path = fish_id_to_asset.get(f_id, "res://assets/sprites/ca/bream_fish__dorade_royale.glb")
		if asset_path.contains("jikin_goldfish"): s *= 0.03
		elif asset_path.contains("model_62a"): s *= 0.012
		elif asset_path.contains("bream_fish"): s *= 0.3
		
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
	# === ĐÃ SỬA: BÓP LỰC NÉM MỒI KHI CÂU CÁ ===
	if state == GameState.FISHING and boat != null:
		var boat_x2d = (boat.position.x + world_width / 2.0) / world_width * 12000.0
		var dist_2d = x2d - boat_x2d
		# Ép lực ném về lại chuẩn của map 200.0 cũ để mồi luôn rơi ngay sát mạn tàu
		return boat.position.x + dist_2d * (200.0 / 12000.0)
		
	# Bình thường (tính toán Map, Zone) thì giữ tỷ lệ theo map khổng lồ
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
		
		# ĐÃ SỬA: Ép Camera dịch chuyển tức thì theo tàu, chống lỗi "mất tàu"
		if camera:
			var forward = boat.global_basis.x.normalized()
			camera.position = boat.position - forward * 8.0 + Vector3(0, 3.5, 0)


func _setup_node_animation(node: Node, anim_speed: float = 1.0) -> void:
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
			
# ==========================================
# HIỆU ỨNG THUYỀN DẬP DÌU THEO SÓNG
# ==========================================
func _update_boat_waves(delta: float) -> void:
	if boat == null:
		return
		
	var time_sec = Time.get_ticks_msec() * 0.001
	
	# 1. Tính toán độ cao của sóng (Y) tại vị trí của thuyền
	var wave_y = sin(time_sec * 2.0 + boat.global_position.x * 0.1) * 0.3
	wave_y += cos(time_sec * 1.5 + boat.global_position.z * 0.15) * 0.2
	
	# === ĐÃ SỬA: CHỈNH LẠI ĐỘ NỔI CỦA THUYỀN ===
	# Nếu số này ÂM (-): Thuyền chìm xuống
	# Nếu số này DƯƠNG (+): Thuyền nổi lên cao
	# Bạn hãy tự chỉnh số 0.5 này lên xuống (ví dụ 1.0, 1.5, hoặc 0.0) 
	# cho đến khi thấy mạn thuyền nằm vừa vặn trên mặt nước nhé!
	var boat_sink_depth = 0.3
	
	var target_y = water_level_y + wave_y + boat_sink_depth
	
	boat.global_position.y = lerpf(boat.global_position.y, target_y, 4.0 * delta)
	
	# 2. Tính toán độ nghiêng (Ngóc mũi/cắm đầu và Lắc lư mạn thuyền)
	var pitch_angle = cos(time_sec * 2.0 + boat.global_position.x * 0.1) * 0.12 
	var roll_angle = sin(time_sec * 1.5 + boat.global_position.z * 0.15) * 0.08  
	
	boat.rotation.z = lerp_angle(boat.rotation.z, pitch_angle, 3.0 * delta)
	boat.rotation.x = lerp_angle(boat.rotation.x, roll_angle, 3.0 * delta)

# ==========================================
# FIX LỖI VẬT LIỆU XUYÊN NƯỚC 
# ==========================================
func _fix_fish_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var mat = node.get_surface_override_material(i)
				if mat == null:
					mat = mesh.surface_get_material(i)
				
				if mat is BaseMaterial3D:
					var new_mat = mat.duplicate()
					# Bắt buộc bật Depth Test để cá bị che khuất bởi mặt nước
					new_mat.no_depth_test = false
					new_mat.render_priority = 0
					
					# Xóa TOÀN BỘ độ trong suốt (Transparent) của con cá, biến nó thành khối đặc (Opaque)
					# Đây là CÁCH DUY NHẤT để cá 100% bị che khuất bởi mặt nước có shader trong suốt
					new_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					new_mat.cull_mode = BaseMaterial3D.CULL_BACK
					new_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
						
					node.set_surface_override_material(i, new_mat)
	
	for child in node.get_children():
		_fix_fish_material(child)

# ==========================================
# HÀM CHẠY ANIMATION CHO CÁ (BỊ THẤT LẠC)
# ==========================================
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

func _setup_air_effects() -> void:
	# Tạo bụi phù du mù mờ cho post-processing fog khí mù mù
	mist_particles = GPUParticles3D.new()
	mist_particles.name = "MistParticles"
	mist_particles.emitting = false # Sẽ được bật khi ở trên trời
	add_child(mist_particles)
	
	# === TẠO CHẤT LIỆU MÙ MỜ PHÙ DU SIÊU MÙ MỜ ===
	var mist_mat = ShaderMaterial.new()
	mist_mat.shader = load("res://assets/shaders/fog_particles_sky.gdshader") # Tui sẽ đưa shader ở lượt sau
	
	mist_particles.process_material = mist_mat
	
	# === TẠO MESH MÙ MỜ PHÙ DU ===
	var mist_mesh = QuadMesh.new()
	mist_mesh.material = mist_mat
	mist_mesh.size = Vector2(0.3, 0.3)
	
	mist_particles.draw_pass_1 = mist_mesh
	
	# Đặt số lượng bụi khổng lồ cho bầu trời
	mist_particles.amount = 500
