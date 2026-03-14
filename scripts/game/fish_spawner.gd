extends Node2D

## Fish spawner — manages spawning fish based on zone, time, and weather conditions

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var max_fish: int = 8
var active_fish: Array = []
var zone_id: String = "coastal"

# Spawn boundaries
var spawn_y_min: float = 580.0
var spawn_y_max: float = 950.0
var spawn_x_range: float = 2000.0  # Centered on camera


func _process(delta: float) -> void:
	spawn_timer += delta
	
	# Clean up dead fish
	active_fish = active_fish.filter(func(f): return is_instance_valid(f))
	
	if spawn_timer >= spawn_interval and active_fish.size() < max_fish:
		spawn_timer = 0.0
		_try_spawn_fish()


func _try_spawn_fish() -> void:
	var period = TimeWeather.get_period_name()
	var weather = TimeWeather.get_weather_name()
	var full_moon = TimeWeather.is_full_moon()
	
	var available = FishDatabase.get_fish_for_zone(zone_id, period, weather, full_moon)
	if available.size() == 0:
		return
	
	# Weighted random selection
	var total_weight = 0.0
	for fish in available:
		total_weight += FishDatabase.get_spawn_weight(fish.rarity)
	
	var roll = randf() * total_weight
	var accumulated = 0.0
	var selected = available[0]
	for fish in available:
		accumulated += FishDatabase.get_spawn_weight(fish.rarity)
		if roll <= accumulated:
			selected = fish
			break
	
	# Create fish instance
	var fish_scene = load("res://scenes/game/fish.tscn")
	if fish_scene:
		var fish_node = fish_scene.instantiate()
		var direction = [-1.0, 1.0][randi() % 2]
		var spawn_x = -100.0 if direction > 0 else spawn_x_range + 100.0
		var spawn_y = randf_range(spawn_y_min, spawn_y_max)
		
		fish_node.position = Vector2(spawn_x, spawn_y)
		fish_node.setup(selected, direction)
		add_child(fish_node)
		active_fish.append(fish_node)


func set_zone(new_zone_id: String) -> void:
	zone_id = new_zone_id
