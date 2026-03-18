class_name OceanController
extends MeshInstance3D

@export var follow_target: Node3D

## Ocean Manager
## Repositions the ocean mesh and provides CPU-side Gerstner wave sampling.

@export_group("Wave Parameters - Shallow")
@export var s_amplitude: float = 0.25
@export var s_wavelength: float = 40.0
@export var s_speed: float = 1.3
@export var s_steepness: float = 0.4

@export_group("Wave Parameters - Deep")
@export var d_amplitude: float = 2.5
@export var d_wavelength: float = 200.0
@export var d_speed: float = 0.8
@export var d_steepness: float = 0.6

@export_group("Noise / Zones")
@export var noise_scale: float = 0.001
@export var noise_resource: FastNoiseLite
@export var spawn_pos: Vector3 = Vector3.ZERO

@export_group("Infinite Ocean")
@export var follow_camera: Camera3D
@export var grid_size: float = 10.0 # Snap size for stability

var time_scale: float = 1.0
var _noise: FastNoiseLite
var wave_time: float = 0.0
var noise_cache = {}

func _ready() -> void:
	if not noise_resource:
		_noise = FastNoiseLite.new()
		_noise.seed = randi()
		_noise.frequency = 0.01 # Internal frequency, adjusted by noise_scale externally
	else:
		_noise = noise_resource
	
	# Ensure material is set up
	var mat = get_active_material(0) as ShaderMaterial
	if mat:
		# Create a texture from the noise if not already provided
		var tex = NoiseTexture2D.new()
		tex.noise = _noise
		tex.seamless = true
		mat.set_shader_parameter("noise_tex", tex)
		_update_shader_params()

func _physics_process(delta: float) -> void:
	wave_time += delta * time_scale
	if follow_target:
		global_position.x = snappedf(follow_target.global_position.x, 10.0)
		global_position.z = snappedf(follow_target.global_position.z, 10.0)
	elif follow_camera:
		var cam_pos = follow_camera.global_position
		# Snap position to grid to avoid vertex jittering
		var snapped_pos = Vector3(
			floor(cam_pos.x / grid_size) * grid_size,
			0,
			floor(cam_pos.z / grid_size) * grid_size
		)
		global_position = snapped_pos
	
	# Update time scale if needed
	_update_shader_params()

func _update_shader_params() -> void:
	var mat = get_active_material(0) as ShaderMaterial
	if not mat: return
	
	mat.set_shader_parameter("noise_scale", noise_scale)
	mat.set_shader_parameter("spawn_pos", spawn_pos)
	mat.set_shader_parameter("s_amplitude", s_amplitude)
	mat.set_shader_parameter("s_wavelength", s_wavelength)
	mat.set_shader_parameter("s_speed", s_speed)
	mat.set_shader_parameter("s_steepness", s_steepness)
	
	mat.set_shader_parameter("d_amplitude", d_amplitude)
	mat.set_shader_parameter("d_wavelength", d_wavelength)
	mat.set_shader_parameter("d_speed", d_speed)
	mat.set_shader_parameter("d_steepness", d_steepness)

## Returns the wave height at a given world position
func get_wave_height(world_pos: Vector3) -> float:
	var t = wave_time
	var local_pos = world_pos - global_position
	
	# Sample noise (matching shader's v_noise)
	# NoiseTexture2D with NoiseResource(frequency=F) and width=W 
	# maps UV(0,1) to noise coords (0, W).
	# Shader uses UV = world_pos.xz * noise_scale.
	# So we sample noise at world_pos.xz * noise_scale * texture_width.
	# We'll assume default 512 for width if not specified.
	var noise_coord_scale = noise_scale * 512.0
	var raw_n = (_noise.get_noise_2d(world_pos.x * noise_coord_scale, world_pos.z * noise_coord_scale) + 1.0) * 0.5

	var key = str(int(world_pos.x)) + "_" + str(int(world_pos.z))

	var prev = noise_cache.get(key, raw_n)
	var original_n = lerp(prev, raw_n, 0.05)

	noise_cache[key] = original_n
	
	# Spawn Safety Bias
	var dist_to_spawn = Vector2(world_pos.x, world_pos.z).distance_to(Vector2(spawn_pos.x, spawn_pos.z))
	var safety_bias = clamp((dist_to_spawn - 0.0) / (800.0 - 0.0), 0.0, 1.0)
	safety_bias = safety_bias * safety_bias * (3.0 - 2.0 * safety_bias) # smoothstep manually
	
	var n = lerp(0.0, original_n, safety_bias)
	
	var amp = lerp(s_amplitude, d_amplitude, n)
	var len = lerp(s_wavelength, d_wavelength, n)
	var spd = lerp(s_speed, d_speed, n)
	var stp = lerp(s_steepness, d_steepness, n)
	
	var total_h = 0.0
	
	# Wave 1
	total_h += _calculate_gerstner_h(world_pos, t, amp, len, spd, stp, Vector2(1.0, 0.2).normalized())
	# Wave 2
	total_h += _calculate_gerstner_h(world_pos, t, amp * 0.6, len * 0.5, spd * 1.2, stp * 0.8, Vector2(-0.7, 0.7).normalized())
	# Wave 3
	total_h += _calculate_gerstner_h(world_pos, t, amp * 0.3, len * 0.2, spd * 1.5, stp * 0.5, Vector2(0.2, 0.9).normalized())
	
	return total_h + global_position.y

func _calculate_gerstner_h(pos: Vector3, t: float, a: float, l: float, s: float, q: float, d: Vector2) -> float:
	var k = 2.0 * PI / l
	s = clamp(s, 0.0, 2.0)
	var f = k * (d.dot(Vector2(pos.x, pos.z)) - s * t)
	return a * sin(f)
