extends RigidBody3D
class_name BoatBuoyancy

@export var ocean: Node

@export_group("Float Points")
@export var float_points: Array[Marker3D] = []
@export var auto_create_float_points: bool = true
@export var boat_length: float = 3.0
@export var boat_width: float = 1.2
@export var float_point_height: float = -0.7 # 🔥 FIX

@export_group("Buoyancy")
@export var buoyancy_force: float = 320.0
@export var max_buoyancy_force: float = 1200.0
@export var vertical_damping: float = 8.0

@export_group("Water Drag")
@export var water_drag: float = 0.7
@export var water_drag_quadratic: float = 0.025
@export var water_angular_drag: float = 1.2

@export_group("Stability")
@export var stability_torque: float = 12.0
@export var stability_angular_damping: float = 2.5

@export_group("Propulsion")
@export var engine_force: float = 2600.0
@export var reverse_force: float = 1200.0
@export var steer_torque: float = 220.0
@export var max_speed: float = 24.0

@export_group("Steering Feel")
@export var steer_smoothing: float = 8.0
@export var max_yaw_rate: float = 1.6
@export var yaw_damping: float = 2.0

@export_group("Safety")
@export var max_linear_speed: float = 35.0
@export var water_stick_force: float = 15.0
@export var max_angular_speed: float = 8.0

var depth_cache = {}
var is_in_water: bool = false
var submerged_ratio: float = 0.0

var steer_input: float = 0.0
var throttle_input: float = 0.0
var _steer_smoothed: float = 0.0

func _ready() -> void:
	print("BOAT READY")

	if not ocean:
		ocean = get_tree().root.find_child("Ocean", true, false)

	print("Ocean node:", ocean)

	set_physics_process(true)

	if auto_create_float_points and float_points.is_empty():
		_create_default_float_points()

	print("Float points:", float_points.size())

	# 🔥 MASS + DAMPING FIX
	mass = 120.0
	linear_damp = 1.8
	angular_damp = 3.5

	can_sleep = false
	sleeping = false


func set_input(p_steer: float, p_throttle: float) -> void:
	steer_input = clampf(p_steer, -1.0, 1.0)
	throttle_input = clampf(p_throttle, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	if not ocean:
		return

	_apply_propulsion()

	# safety clamp
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed

	if angular_velocity.length() > max_angular_speed:
		angular_velocity = angular_velocity.normalized() * max_angular_speed

	is_in_water = false
	var submerged_points := 0

	for marker in float_points:
		if not marker:
			continue

		var world_pos = marker.global_position
		var ocean_controller := ocean as OceanController
		var wave_h = ocean_controller.get_wave_height(world_pos) if ocean_controller else 0.0

		var raw_depth = wave_h - world_pos.y
		raw_depth = clamp(raw_depth, -0.5, 2.0)

		if raw_depth < -0.2:
			continue

		var key = marker.get_instance_id()
		var prev = depth_cache.get(key, raw_depth)
		var depth = lerp(prev, raw_depth, 0.25)
		depth_cache[key] = depth

		is_in_water = true
		submerged_points += 1

		var fmag = clampf(depth * buoyancy_force, 0.0, max_buoyancy_force)

		var force = Vector3.UP * fmag
		var local_offset = to_local(marker.global_position)

		apply_force(force, local_offset)

	# ===== WATER EFFECT =====
	if is_in_water:
		submerged_ratio = float(submerged_points) / float(float_points.size())

		# 🔥 GIỮ THUYỀN KHÔNG BAY KHỎI NƯỚC
		var ocean_controller := ocean as OceanController
		var wave_h = ocean_controller.get_wave_height(global_position)
		var diff = wave_h - global_position.y
		var stick_force = diff * water_stick_force * mass
		stick_force = clamp(stick_force, -2000.0, 2000.0)
		apply_central_force(Vector3.UP * stick_force)

		# 🔥 DOWNFORCE (fix bay)
		var down_force = -Vector3.UP * mass * 0.4
		apply_central_force(down_force)

		# vertical damping
		if linear_velocity.y < 0.0:
			var damping_force = -linear_velocity.y * vertical_damping * mass
			damping_force = clamp(damping_force, 0.0, 4000.0)
			apply_central_force(Vector3.UP * damping_force)

		# drag ngang
		var hv = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		var speed = hv.length()

		if speed > 0.001:
			var drag_dir = -hv / speed
			var drag_mag = (water_drag * speed + water_drag_quadratic * speed * speed) * mass
			apply_central_force(drag_dir * drag_mag)

		# angular drag
		apply_torque(-angular_velocity * water_angular_drag * mass)

		# giữ upright
		var tilt_axis = global_basis.y.cross(Vector3.UP)
		apply_torque(tilt_axis * stability_torque * mass)
		apply_torque(-angular_velocity * stability_angular_damping * mass)

		# yaw damping
		apply_torque(Vector3.UP * (-angular_velocity.y * yaw_damping * mass))

		# 🔥 CHỐNG CẮM ĐẦU
		var forward = -global_basis.z
		var pitch = forward.dot(Vector3.UP)
		apply_torque(Vector3.RIGHT * (-pitch * 10.0 * mass))

	else:
		submerged_ratio = 0.0


func _apply_propulsion() -> void:
	if absf(throttle_input) > 0.01 or absf(steer_input) > 0.01:
		sleeping = false

	var forward = global_basis.x
	forward.y = 0.0
	forward = forward.normalized()

	var horiz_speed = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()

	if horiz_speed > max_speed:
		var hv = Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized() * max_speed
		linear_velocity = Vector3(hv.x, linear_velocity.y, hv.z)

	var thrust = engine_force if throttle_input >= 0.0 else reverse_force
	apply_central_force(forward * (throttle_input * thrust))

	_steer_smoothed = lerpf(_steer_smoothed, steer_input, 0.1)

	var steer_strength = lerpf(0.1, 1.0, clampf(horiz_speed / 10.0, 0.0, 1.0))
	apply_torque(Vector3.UP * (_steer_smoothed * steer_torque * steer_strength))

	if absf(angular_velocity.y) > max_yaw_rate:
		angular_velocity.y = sign(angular_velocity.y) * max_yaw_rate


func _create_default_float_points() -> void:
	var root := Node3D.new()
	root.name = "FloatPoints"
	add_child(root)

	var offsets := [
		Vector3( boat_length * 0.6, float_point_height,  boat_width * 0.5),
		Vector3( boat_length * 0.6, float_point_height, -boat_width * 0.5),
		Vector3(-boat_length * 0.5, float_point_height,  boat_width * 0.5),
		Vector3(-boat_length * 0.5, float_point_height, -boat_width * 0.5),
		Vector3(0, float_point_height, 0)
	]

	for i in range(offsets.size()):
		var m := Marker3D.new()
		m.position = offsets[i]
		root.add_child(m)
		float_points.append(m)
