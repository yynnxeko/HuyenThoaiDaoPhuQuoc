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
	
	match state:
		FishState.SWIMMING:
			position.x += swim_speed * swim_direction * delta
			position.y += sin(time * wave_speed + vertical_wave_offset) * wave_amplitude * delta
		
		FishState.ATTRACTED:
			var dir_to_bait = (bait_position - position).normalized()
			position += dir_to_bait * swim_speed * 0.5 * delta
			if position.distance_to(bait_position) < 20.0:
				state = FishState.HOOKED
		
		FishState.FLEEING:
			position.x += swim_speed * swim_direction * 2.0 * delta
	
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
