extends Node2D

## Fish behavior AI — underwater fish that swim, react to bait, and can be caught

var fish_data = null  # FishDatabase.FishType
var swim_direction: float = 1.0
var swim_speed: float = 50.0
var vertical_wave_offset: float = 0.0
var wave_amplitude: float = 15.0
var wave_speed: float = 2.0
var time: float = 0.0

# State
enum FishState { SWIMMING, ATTRACTED, FLEEING, HOOKED }
var state: FishState = FishState.SWIMMING

# Bait attraction
var bait_position: Vector2 = Vector2.ZERO
var attraction_range: float = 150.0


func setup(data, direction: float = 1.0) -> void:
	fish_data = data
	swim_direction = direction
	swim_speed = data.speed
	vertical_wave_offset = randf() * TAU
	wave_amplitude = randf_range(8.0, 20.0)


func _process(delta: float) -> void:
	time += delta
	
	var target_velocity = Vector2.ZERO
	match state:
		FishState.SWIMMING:
			target_velocity.x = swim_speed * swim_direction
			target_velocity.y = cos(time * wave_speed + vertical_wave_offset) * wave_amplitude
		
		FishState.ATTRACTED:
			var dir_to_bait = (bait_position - position).normalized()
			target_velocity = dir_to_bait * swim_speed * 1.5
			if position.distance_to(bait_position) < 20.0:
				state = FishState.HOOKED
		
		FishState.FLEEING:
			target_velocity.x = swim_speed * swim_direction * 2.5
			target_velocity.y = sin(time * 5.0) * 30.0
	
	# Apply movement with slight smoothing
	position += target_velocity * delta
	
	# Rotation and flipping
	if target_velocity.length() > 1.0:
		# Flip based on horizontal direction
		var target_scale_x = sign(target_velocity.x)
		if target_scale_x != 0:
			scale.x = lerp(scale.x, target_scale_x, 10.0 * delta)
		
		# Pitch/Tilt based on vertical velocity
		var target_rotation = clamp(target_velocity.y / swim_speed, -0.4, 0.4)
		rotation = lerp_angle(rotation, target_rotation * sign(scale.x), 5.0 * delta)
	
	queue_redraw()


func attract_to_bait(bait_pos: Vector2) -> void:
	bait_position = bait_pos
	state = FishState.ATTRACTED


func flee() -> void:
	state = FishState.FLEEING


func _draw() -> void:
	# 2D drawing disabled - replace with 3D models from assets/sprites/ca
	# if fish_data == null:
	# 	return
	pass
