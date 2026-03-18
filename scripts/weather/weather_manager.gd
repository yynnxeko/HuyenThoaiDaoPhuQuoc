extends Node

class_name WeatherManager

const OceanController = preload("res://scripts/game/ocean.gd")

@export var ocean: Node
@export var world_env: WorldEnvironment
@export var sun: DirectionalLight3D
@export var rain_particles: GPUParticles3D
@export var rain_screen: CanvasItem
@export var rain_sound: AudioStreamPlayer
@export var wind_sound: AudioStreamPlayer

enum Weather { CLEAR, RAIN }
var current_weather: Weather = Weather.CLEAR
var wind_strength: float = 1.0
var target_wind_strength: float = 1.0

var change_timer: Timer
var _rain_amount: float = 0.0

func _ready() -> void:
	change_timer = Timer.new()
	add_child(change_timer)
	change_timer.timeout.connect(_on_weather_timer_timeout)
	reset_weather_timer()
	
	set_weather(Weather.CLEAR)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_weather"):
		print("Weather toggled")
		toggle_weather()

func _process(delta: float) -> void:
	wind_strength = lerpf(wind_strength, target_wind_strength, delta * 0.5)
	var ocean_controller := ocean as OceanController
	if ocean_controller:
		# Wind affects wave height and speed
		ocean_controller.wave_height = lerpf(ocean_controller.wave_height, 0.5 * wind_strength, delta * 0.2)
		ocean_controller.wave_speed = lerpf(ocean_controller.wave_speed, 2.0 * wind_strength, delta * 0.2)
	
	_update_rain_screen()

func toggle_weather() -> void:
	if current_weather == Weather.CLEAR:
		set_weather(Weather.RAIN)
	else:
		set_weather(Weather.CLEAR)
	reset_weather_timer()

func set_weather(type: Weather) -> void:
	current_weather = type
	print("Weather state:", "RAIN" if current_weather == Weather.RAIN else "CLEAR")
	match type:
		Weather.CLEAR:
			target_wind_strength = 1.0
			_tween_environment(Color(0.5, 0.7, 1.0), 1.0, 0.0) # Light blue, full energy, no fog
			if rain_particles: rain_particles.emitting = false
			_tween_rain_amount(0.0)
			if rain_sound: _fade_sound(rain_sound, 0)
			if wind_sound: _fade_sound(wind_sound, -10)
		Weather.RAIN:
			target_wind_strength = 2.0
			_tween_environment(Color(0.2, 0.2, 0.3), 0.3, 0.05) # Dark blue/gray, low energy, fog
			if rain_particles: rain_particles.emitting = true
			_tween_rain_amount(1.0)
			if rain_sound: _fade_sound(rain_sound, 0)
			if wind_sound: _fade_sound(wind_sound, 0)

func _tween_environment(sky_tint: Color, sun_energy: float, fog_density: float) -> void:
	if not world_env: return
	var env = world_env.environment
	var tween = create_tween().set_parallel(true)
	tween.tween_property(env, "sky_custom_fov", env.sky_custom_fov, 2.0) # Just to trigger redraw if needed
	if sun:
		tween.tween_property(sun, "light_energy", sun_energy, 5.0)
	tween.tween_property(env, "fog_light_color", sky_tint, 5.0)
	tween.tween_property(env, "fog_density", fog_density, 5.0)
	# env.adjustment_saturation can be adjusted here too if enabled

func _fade_sound(player: AudioStreamPlayer, target_db: float) -> void:
	if not player: return
	if target_db > -40 and not player.playing: player.play()
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, 3.0)
	if target_db <= -40:
		tween.tween_callback(player.stop)

func _tween_rain_amount(target: float) -> void:
	target = clampf(target, 0.0, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "_rain_amount", target, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_rain_screen() -> void:
	if not rain_screen:
		return
	var mat := rain_screen.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("rain_amount", _rain_amount)

func reset_weather_timer() -> void:
	change_timer.wait_time = randf_range(120.0, 300.0) # 2-5 minutes
	change_timer.start()

func _on_weather_timer_timeout() -> void:
	toggle_weather()
