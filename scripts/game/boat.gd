extends Node3D

## 3D Boat — handles movement and contains mesh for boat + character + rod

var facing_right: bool = true
var move_input: float = 0.0
var steer_input: float = 0.0
var throttle_input: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var yaw_velocity: float = 0.0
var current_speed: float = 0.0
var bob_time: float = 0.0

# Movement (boat-like steering)
var max_forward_speed: float = 12.0
var max_reverse_speed: float = 4.0
var acceleration: float = 4.5
var water_drag: float = 1.8
var turn_speed_deg: float = 70.0
var turn_accel: float = 4.0
var turn_damping: float = 3.5
var buoyancy_smoothing: float = 5.0 # (Used for rotation smoothing now)
var buoyancy_strength: float = 25.0 # Increased for better response
var attraction_strength: float = 10.0 # Pull toward surface
var vertical_damping: float = 0.98 # Refined damping
var gravity: float = 12.0 # Slightly heavier gravity

# Wave sampling points (offsets from center)
var boat_length: float = 3.0
var boat_width: float = 1.2
var sampling_points: Array[Vector3] = []

var ocean_manager: Node3D = null

# Mesh nodes (created in _ready)
var hull_mesh: MeshInstance3D
var cabin_mesh: MeshInstance3D
var mast_mesh: MeshInstance3D
var character_mesh: MeshInstance3D
var hat_mesh: MeshInstance3D
var rod_mesh: MeshInstance3D


func _ready() -> void:
	# Find ocean manager in the scene
	ocean_manager = get_tree().root.find_child("Ocean", true, false)
	
	# If a custom model is already attached in the scene, skip procedural mesh creation.
	if get_child_count() == 0:
		_build_boat_model()


func _build_boat_model() -> void:
	# === HULL ===
	hull_mesh = MeshInstance3D.new()
	var hull = BoxMesh.new()
	hull.size = Vector3(3.0, 0.5, 1.2)
	hull_mesh.mesh = hull
	var hull_mat = StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.5, 0.3, 0.12)
	hull_mesh.material_override = hull_mat
	hull_mesh.position = Vector3(0, 0.1, 0)
	add_child(hull_mesh)
	
	# Hull bottom (curved look)
	var keel = MeshInstance3D.new()
	var keel_mesh = BoxMesh.new()
	keel_mesh.size = Vector3(2.5, 0.3, 0.8)
	keel.mesh = keel_mesh
	var keel_mat = StandardMaterial3D.new()
	keel_mat.albedo_color = Color(0.4, 0.22, 0.08)
	keel.material_override = keel_mat
	keel.position = Vector3(0, -0.15, 0)
	add_child(keel)
	
	# Bow (front)
	var bow = MeshInstance3D.new()
	var bow_mesh_shape = PrismMesh.new()
	bow_mesh_shape.size = Vector3(1.0, 0.5, 1.0)
	bow.mesh = bow_mesh_shape
	var bow_mat = StandardMaterial3D.new()
	bow_mat.albedo_color = Color(0.55, 0.32, 0.13)
	bow.material_override = bow_mat
	bow.position = Vector3(1.8, 0.1, 0)
	bow.rotation_degrees = Vector3(0, 0, -90)
	add_child(bow)
	
	# === CABIN (small) ===
	cabin_mesh = MeshInstance3D.new()
	var cabin = BoxMesh.new()
	cabin.size = Vector3(0.8, 0.6, 0.8)
	cabin_mesh.mesh = cabin
	var cabin_mat = StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.6, 0.38, 0.18)
	cabin_mesh.material_override = cabin_mat
	cabin_mesh.position = Vector3(-0.6, 0.65, 0)
	add_child(cabin_mesh)
	
	# Roof
	var roof = MeshInstance3D.new()
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(1.0, 0.1, 1.0)
	roof.mesh = roof_mesh
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.45, 0.25, 0.1)
	roof.material_override = roof_mat
	roof.position = Vector3(-0.6, 1.0, 0)
	add_child(roof)
	
	# === CHARACTER ===
	# Body
	character_mesh = MeshInstance3D.new()
	var body = CapsuleMesh.new()
	body.radius = 0.15
	body.height = 0.6
	character_mesh.mesh = body
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.4, 0.6)
	character_mesh.material_override = body_mat
	character_mesh.position = Vector3(0.5, 0.8, 0)
	add_child(character_mesh)
	
	# Head
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.12
	head_mesh.height = 0.24
	head.mesh = head_mesh
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.5)
	head.material_override = head_mat
	head.position = Vector3(0.5, 1.2, 0)
	add_child(head)
	
	# Nón lá (conical hat) — using a CylinderMesh as cone
	hat_mesh = MeshInstance3D.new()
	var hat = CylinderMesh.new()
	hat.top_radius = 0.01
	hat.bottom_radius = 0.25
	hat.height = 0.2
	hat_mesh.mesh = hat
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color(0.78, 0.68, 0.42)
	hat_mesh.material_override = hat_mat
	hat_mesh.position = Vector3(0.5, 1.38, 0)
	add_child(hat_mesh)
	
	# === FISHING ROD ===
	rod_mesh = MeshInstance3D.new()
	var rod = CylinderMesh.new()
	rod.top_radius = 0.015
	rod.bottom_radius = 0.03
	rod.height = 2.5
	rod_mesh.mesh = rod
	var rod_mat = StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.55, 0.4, 0.15)
	rod_mesh.material_override = rod_mat
	rod_mesh.position = Vector3(1.2, 1.5, 0)
	rod_mesh.rotation_degrees = Vector3(0, 0, -35)
	add_child(rod_mesh)
	
	# === HEADLIGHTS ===
	_add_headlight(Vector3(2.3, 0.4, 0.45))
	_add_headlight(Vector3(2.3, 0.4, -0.45))


func _add_headlight(pos: Vector3) -> void:
	# Visual fixture
	var light_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.2
	light_mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.8)
	mat.emission_energy_multiplier = 4.0
	light_mesh.material_override = mat
	light_mesh.position = pos
	light_mesh.rotation_degrees.z = 90
	add_child(light_mesh)
	
	# Light source
	var light = SpotLight3D.new()
	light.position = pos + Vector3(0.2, 0, 0)
	light.light_color = Color(1.0, 1.0, 0.9)
	light.light_energy = 5.0
	light.spot_range = 25.0
	light.spot_angle = 45.0
	light.shadow_enabled = true
	add_child(light)


func _process(delta: float) -> void:
	bob_time += delta
	# Backward compatibility in case caller still sets move_input.
	if absf(steer_input) < 0.001:
		steer_input = move_input
	
	# Apply steering (A/D rotates the boat like a rudder)
	var target_yaw_velocity = steer_input * deg_to_rad(turn_speed_deg)
	yaw_velocity = lerpf(yaw_velocity, target_yaw_velocity, turn_accel * delta)
	yaw_velocity = lerpf(yaw_velocity, 0.0, turn_damping * delta)
	rotation.y += yaw_velocity * delta

	# Player throttle controls forward/reverse speed.
	var forward = global_basis.x.normalized()
	var target_speed = 0.0
	if throttle_input > 0.0:
		target_speed = throttle_input * max_forward_speed
	elif throttle_input < 0.0:
		target_speed = throttle_input * max_reverse_speed
	current_speed = lerpf(current_speed, target_speed, acceleration * delta)
	current_speed = lerpf(current_speed, 0.0, water_drag * delta)
	velocity = forward * current_speed
	position += velocity * delta

	# Keep gameplay on water lane.
	position.z = clampf(position.z, -35.0, 35.0)
	
	# === Wave-based water simulation (force-based) ===
	if ocean_manager and ocean_manager.has_method("get_wave_height"):
		# Multi-point sampling for pitch and roll
		var p_front = global_position + global_basis.x * (boat_length * 0.5)
		var p_back = global_position - global_basis.x * (boat_length * 0.5)
		var p_left = global_position - global_basis.z * (boat_width * 0.5)
		var p_right = global_position + global_basis.z * (boat_width * 0.5)
		
		var h_front = ocean_manager.get_wave_height(p_front)
		var h_back = ocean_manager.get_wave_height(p_back)
		var h_left = ocean_manager.get_wave_height(p_left)
		var h_right = ocean_manager.get_wave_height(p_right)
		var h_center = (h_front + h_back + h_left + h_right) * 0.25
		
		# Buoyancy Physics (Vertical Force)
		# Allow boat to dip slightly into waves (no offset)
		var target_y = h_center
		
		# Gravity
		velocity.y -= gravity * delta
		
		# Buoyancy/Stick Force logic
		var diff = target_y - global_position.y
		# Clamped diff for attraction force prevents extreme snapping
		var attraction_diff = clampf(diff, -2.0, 2.0)
		
		if diff > 0:
			# Immersion buoyancy (stronger)
			velocity.y += attraction_diff * buoyancy_strength * delta
		else:
			# Stick-to-water force (gentle pull if above)
			velocity.y += attraction_diff * attraction_strength * delta
			
		# Vertical damping
		velocity.y *= 0.98
		
		# Apply vertical movement manually
		position.y += velocity.y * delta
		
		# Clamp extreme vertical velocity to avoid bouncing artifacts
		velocity.y = clampf(velocity.y, -15.0, 15.0)
		
		# Calculate target pitch and roll
		var target_pitch = atan2(h_back - h_front, boat_length)
		var target_roll = atan2(h_left - h_right, boat_width)
		
		# Smooth rotation for "heavy" feel
		rotation.z = lerp_angle(rotation.z, target_roll, 2.0 * delta)
		rotation.x = lerp_angle(rotation.x, target_pitch, 2.0 * delta)
	else:
		# Fallback if no ocean manager
		velocity.y -= gravity * delta
		position.y += velocity.y * delta
		if position.y < 0.1:
			position.y = 0.1
			velocity.y = 0
		rotation.x = lerp_angle(rotation.x, 0, 3.0 * delta)
		rotation.z = lerp_angle(rotation.z, 0, 3.0 * delta)

	facing_right = global_basis.x.x >= 0.0
	
	# Rod sway
	if rod_mesh:
		rod_mesh.rotation_degrees.z = -35.0 + sin(bob_time * 1.0) * 3.0
