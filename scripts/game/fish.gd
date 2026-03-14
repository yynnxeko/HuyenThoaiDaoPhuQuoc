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
	if fish_data == null:
		return
	
	var size = fish_data.max_size * 15.0
	var col = fish_data.color
	var dir = swim_direction
	
	# Body
	var body_points = PackedVector2Array([
		Vector2(-size * dir, 0),
		Vector2(-size * 0.3 * dir, -size * 0.4),
		Vector2(size * 0.5 * dir, -size * 0.2),
		Vector2(size * dir, 0),
		Vector2(size * 0.5 * dir, size * 0.2),
		Vector2(-size * 0.3 * dir, size * 0.4),
	])
	draw_colored_polygon(body_points, col)
	
	# Tail
	var tail_points = PackedVector2Array([
		Vector2(-size * dir, 0),
		Vector2(-size * 1.3 * dir, -size * 0.35),
		Vector2(-size * 1.3 * dir, size * 0.35),
	])
	draw_colored_polygon(tail_points, col.darkened(0.2))
	
	# Fin
	var fin_points = PackedVector2Array([
		Vector2(0, -size * 0.3),
		Vector2(size * 0.2 * dir, -size * 0.6),
		Vector2(size * 0.3 * dir, -size * 0.2),
	])
	draw_colored_polygon(fin_points, col.lightened(0.1))
	
	# Eye
	draw_circle(Vector2(size * 0.5 * dir, -size * 0.08), size * 0.1, Color.WHITE)
	draw_circle(Vector2(size * 0.55 * dir, -size * 0.08), size * 0.05, Color.BLACK)
	
	# Rarity glow for epic+ fish
	if fish_data.rarity == "epic" or fish_data.rarity == "legendary":
		var glow_color = FishDatabase.get_rarity_color(fish_data.rarity)
		glow_color.a = 0.15 + 0.1 * sin(time * 3.0)
		draw_circle(Vector2.ZERO, size * 1.5, glow_color)
