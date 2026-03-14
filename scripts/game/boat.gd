extends Node3D

## 3D Boat — handles movement and contains mesh for boat + character + rod

var facing_right: bool = true
var move_input: float = 0.0
var velocity_x: float = 0.0
var bob_time: float = 0.0

# Movement
var speed: float = 8.0
var acceleration: float = 12.0
var friction: float = 6.0

# Mesh nodes (created in _ready)
var hull_mesh: MeshInstance3D
var cabin_mesh: MeshInstance3D
var mast_mesh: MeshInstance3D
var character_mesh: MeshInstance3D
var hat_mesh: MeshInstance3D
var rod_mesh: MeshInstance3D


func _ready() -> void:
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


func _process(delta: float) -> void:
	bob_time += delta
	
	# Apply movement
	if move_input != 0:
		velocity_x = lerp(velocity_x, move_input * speed, acceleration * delta)
		facing_right = move_input > 0
	else:
		velocity_x = lerp(velocity_x, 0.0, friction * delta)
	
	position.x += velocity_x * delta
	
	# Wave bobbing
	position.y = sin(bob_time * 1.5) * 0.15 + cos(bob_time * 0.8) * 0.08
	
	# Tilt based on wave
	rotation_degrees.z = sin(bob_time * 1.2) * 3.0 + velocity_x * 0.5
	rotation_degrees.x = cos(bob_time * 0.9) * 1.5
	
	# Face direction
	var target_rot_y = 0.0 if facing_right else 180.0
	rotation_degrees.y = lerp_angle(rotation_degrees.y, target_rot_y, delta * 5.0)
	
	# Rod sway
	if rod_mesh:
		rod_mesh.rotation_degrees.z = -35.0 + sin(bob_time * 1.0) * 3.0
