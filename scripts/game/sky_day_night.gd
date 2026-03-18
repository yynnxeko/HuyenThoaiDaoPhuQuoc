extends WorldEnvironment

@export var control_lighting: bool = true
@export var switch_sky: bool = false

# Sibling sun light (DirectionalLight3D) to dim at night.
@export var sun_light_path: NodePath

@export var day_sky_path: String = "res://assets/sprites/sky/kloppenheim_06_puresky_4k.exr"
@export var night_sky_path: String = "res://assets/sprites/sky/qwantani_night_puresky_4k.exr"

@export_range(0.0, 24.0, 0.1) var night_start_hour: float = 18.0
@export_range(0.0, 24.0, 0.1) var day_start_hour: float = 6.0

# Ambient tinting (subtle; sky HDRI still provides most of the look).
@export var day_ambient_color: Color = Color(1, 1, 1, 1)
@export var night_ambient_color: Color = Color(0.12, 0.16, 0.25, 1)

# How dark night gets (0..1). 0 = pitch black, 1 = same as day.
@export_range(0.0, 1.0, 0.01) var night_intensity: float = 0.18

# Curve control (bigger = darker nights faster).
@export_range(0.5, 3.0, 0.05) var intensity_curve: float = 1.6

var _day_tex: Texture2D
var _night_tex: Texture2D
var _is_night_applied: bool = false

var _sun: DirectionalLight3D
var _base_sun_energy: float = 1.0
var _base_ambient_energy: float = 1.0


func _ready() -> void:
	if switch_sky:
		_day_tex = load(day_sky_path)
		_night_tex = load(night_sky_path)

	if control_lighting:
		_sun = get_node_or_null(sun_light_path) as DirectionalLight3D if sun_light_path != NodePath("") else null
		if _sun != null:
			_base_sun_energy = _sun.light_energy
		if environment != null:
			_base_ambient_energy = environment.ambient_light_energy

	if TimeWeather and TimeWeather.has_signal("time_changed"):
		TimeWeather.time_changed.connect(_on_time_changed)
	_apply_for_hour(TimeWeather.game_hour)


func _exit_tree() -> void:
	if TimeWeather and TimeWeather.has_signal("time_changed") and TimeWeather.time_changed.is_connected(_on_time_changed):
		TimeWeather.time_changed.disconnect(_on_time_changed)


func _on_time_changed(hour: float) -> void:
	_apply_for_hour(hour)


func _apply_for_hour(hour: float) -> void:
	var is_night := _is_night(hour)

	if switch_sky:
		if is_night != _is_night_applied:
			_is_night_applied = is_night
			var env_sky := environment
			if env_sky != null:
				if env_sky.sky == null:
					env_sky.sky = Sky.new()
				if env_sky.sky.sky_material == null:
					env_sky.sky.sky_material = PanoramaSkyMaterial.new()
				var pano := env_sky.sky.sky_material
				if pano is PanoramaSkyMaterial:
					(pano as PanoramaSkyMaterial).panorama = (_night_tex if is_night else _day_tex)

	if control_lighting:
		_apply_lighting(hour, is_night)


func _apply_lighting(hour: float, is_night: bool) -> void:
	var env := environment
	if env == null:
		return

	# Use existing day/night curve from TimeWeather for smooth transitions.
	var a := 1.0
	if TimeWeather and TimeWeather.has_method("get_ambient_light"):
		a = clamp(TimeWeather.get_ambient_light(), 0.0, 1.0)

	# Map ambient light (0..1) into intensity with a curve and floor at night_intensity.
	var intensity := pow(a, intensity_curve)
	intensity = lerp(night_intensity, 1.0, intensity)

	# Sun dims much stronger than ambient (sun should feel "gone" at night).
	if _sun != null:
		var sun_intensity := pow(a, max(1.0, intensity_curve + 0.8))
		sun_intensity = lerp(0.0, 1.0, sun_intensity)
		_sun.light_energy = _base_sun_energy * sun_intensity

	# Ambient: keep a minimum so scene isn't pure black.
	env.ambient_light_energy = _base_ambient_energy * intensity
	env.ambient_light_color = day_ambient_color.lerp(night_ambient_color, 1.0 - intensity)


func _is_night(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	# Night from night_start_hour .. 24, and 0 .. day_start_hour
	if night_start_hour < day_start_hour:
		return h >= night_start_hour and h < day_start_hour
	return h >= night_start_hour or h < day_start_hour

