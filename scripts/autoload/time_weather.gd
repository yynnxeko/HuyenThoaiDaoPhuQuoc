extends Node

## Day/night cycle and weather system singleton

signal time_changed(hour: float)
signal period_changed(new_period: String)
signal weather_changed(new_weather: String)
signal full_moon_started()
signal full_moon_ended()

# Time settings: 1 real second = 10 game minute
const GAME_MINUTES_PER_REAL_SECOND: float = 10.0

# Current game time (0.0 - 24.0 hours)
var game_hour: float = 6.0  # Start at sunrise (6 AM)
var game_day: int = 1
var moon_cycle_day: int = 15  # Start with full moon for testing stars/moon
const MOON_CYCLE_LENGTH: int = 30

# Time periods
enum TimePeriod { DAWN, MORNING, AFTERNOON, EVENING, NIGHT }
var current_period: TimePeriod = TimePeriod.DAWN

# Weather
enum Weather { CLEAR, CLOUDY, RAIN, STORM }
var current_weather: Weather = Weather.CLEAR
var weather_timer: float = 0.0
var weather_duration: float = 120.0  # seconds until next weather change

# Sky colors for each period (vibrant blue for day, dark for night)
const SKY_COLORS = {
	"dawn_top": Color(0.15, 0.05, 0.25),
	"dawn_bottom": Color(0.95, 0.45, 0.15),
	"morning_top": Color(0.2, 0.5, 0.8),      # Matches village
	"morning_bottom": Color(0.65, 0.7, 0.8),   # Matches village
	"afternoon_top": Color(0.1, 0.45, 0.85),
	"afternoon_bottom": Color(0.6, 0.75, 0.9),
	"evening_top": Color(0.2, 0.1, 0.3),
	"evening_bottom": Color(0.9, 0.35, 0.1),
	"night_top": Color(0.01, 0.01, 0.05),
	"night_bottom": Color(0.02, 0.02, 0.08),
}

# Water colors for each period
const WATER_COLORS = {
	"dawn": Color(0.1, 0.35, 0.5, 0.85),
	"morning": Color(0.05, 0.45, 0.6, 0.8),
	"afternoon": Color(0.08, 0.4, 0.55, 0.8),
	"evening": Color(0.15, 0.25, 0.4, 0.85),
	"night": Color(0.06, 0.15, 0.25, 0.9), # Tăng chút đỉnh cho sáng hơn dưới biển
}


func _ready() -> void:
	_update_period()
	_randomize_weather_duration()


func _process(delta: float) -> void:
	var was_full_moon := is_full_moon()

	# Advance game time
	game_hour += (GAME_MINUTES_PER_REAL_SECOND * delta) / 60.0
	if game_hour >= 24.0:
		game_hour -= 24.0
		game_day += 1
		moon_cycle_day = (moon_cycle_day + 1) % MOON_CYCLE_LENGTH
		if is_full_moon():
			full_moon_started.emit()
		elif was_full_moon:
			full_moon_ended.emit()
	
	time_changed.emit(game_hour)
	_update_period()
	
	# Weather timer
	weather_timer += delta
	if weather_timer >= weather_duration:
		weather_timer = 0.0
		_change_weather()


func _update_period() -> void:
	var old_period = current_period
	if game_hour >= 5.0 and game_hour < 7.0:
		current_period = TimePeriod.DAWN
	elif game_hour >= 7.0 and game_hour < 12.0:
		current_period = TimePeriod.MORNING
	elif game_hour >= 12.0 and game_hour < 17.0:
		current_period = TimePeriod.AFTERNOON
	elif game_hour >= 17.0 and game_hour < 20.0:
		current_period = TimePeriod.EVENING
	else:
		current_period = TimePeriod.NIGHT
	
	if old_period != current_period:
		period_changed.emit(get_period_name())


func _change_weather() -> void:
	var old_weather = current_weather
	var roll = randf()
	match current_weather:
		Weather.CLEAR:
			if roll < 0.6:
				current_weather = Weather.CLEAR
			elif roll < 0.85:
				current_weather = Weather.CLOUDY
			else:
				current_weather = Weather.RAIN
		Weather.CLOUDY:
			if roll < 0.3:
				current_weather = Weather.CLEAR
			elif roll < 0.6:
				current_weather = Weather.CLOUDY
			elif roll < 0.85:
				current_weather = Weather.RAIN
			else:
				current_weather = Weather.STORM
		Weather.RAIN:
			if roll < 0.2:
				current_weather = Weather.CLEAR
			elif roll < 0.5:
				current_weather = Weather.CLOUDY
			elif roll < 0.75:
				current_weather = Weather.RAIN
			else:
				current_weather = Weather.STORM
		Weather.STORM:
			if roll < 0.1:
				current_weather = Weather.CLEAR
			elif roll < 0.4:
				current_weather = Weather.CLOUDY
			elif roll < 0.7:
				current_weather = Weather.RAIN
			else:
				current_weather = Weather.STORM
	
	if old_weather != current_weather:
		weather_changed.emit(get_weather_name())
	
	_randomize_weather_duration()


func _randomize_weather_duration() -> void:
	weather_duration = randf_range(60.0, 180.0)


func get_period_name() -> String:
	match current_period:
		TimePeriod.DAWN: return "dawn"
		TimePeriod.MORNING: return "morning"
		TimePeriod.AFTERNOON: return "afternoon"
		TimePeriod.EVENING: return "evening"
		TimePeriod.NIGHT: return "night"
	return "morning"


func get_weather_name() -> String:
	match current_weather:
		Weather.CLEAR: return "clear"
		Weather.CLOUDY: return "cloudy"
		Weather.RAIN: return "rain"
		Weather.STORM: return "storm"
	return "clear"


func get_weather_display_name() -> String:
	match current_weather:
		Weather.CLEAR: return "Trời Quang"
		Weather.CLOUDY: return "Nhiều Mây"
		Weather.RAIN: return "Mưa"
		Weather.STORM: return "Bão"
	return "Trời Quang"


func get_period_display_name() -> String:
	match current_period:
		TimePeriod.DAWN: return "Bình Minh"
		TimePeriod.MORNING: return "Sáng"
		TimePeriod.AFTERNOON: return "Chiều"
		TimePeriod.EVENING: return "Hoàng Hôn"
		TimePeriod.NIGHT: return "Đêm"
	return "Sáng"


func is_full_moon() -> bool:
	return moon_cycle_day >= 14 and moon_cycle_day <= 15


func get_time_string() -> String:
	var h = int(game_hour)
	var m = int((game_hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func get_sky_top_color() -> Color:
	var t: float
	match current_period:
		TimePeriod.DAWN:
			t = (game_hour - 5.0) / 2.0
			return SKY_COLORS["dawn_top"].lerp(SKY_COLORS["morning_top"], t)
		TimePeriod.MORNING:
			return SKY_COLORS["morning_top"]
		TimePeriod.AFTERNOON:
			t = (game_hour - 12.0) / 5.0
			return SKY_COLORS["afternoon_top"].lerp(SKY_COLORS["evening_top"], t)
		TimePeriod.EVENING:
			t = (game_hour - 17.0) / 3.0
			return SKY_COLORS["evening_top"].lerp(SKY_COLORS["night_top"], t)
		TimePeriod.NIGHT:
			return SKY_COLORS["night_top"]
	return SKY_COLORS["morning_top"]


func get_sky_bottom_color() -> Color:
	var t: float
	match current_period:
		TimePeriod.DAWN:
			t = (game_hour - 5.0) / 2.0
			return SKY_COLORS["dawn_bottom"].lerp(SKY_COLORS["morning_bottom"], t)
		TimePeriod.MORNING:
			return SKY_COLORS["morning_bottom"]
		TimePeriod.AFTERNOON:
			t = (game_hour - 12.0) / 5.0
			return SKY_COLORS["afternoon_bottom"].lerp(SKY_COLORS["evening_bottom"], t)
		TimePeriod.EVENING:
			t = (game_hour - 17.0) / 3.0
			return SKY_COLORS["evening_bottom"].lerp(SKY_COLORS["night_bottom"], t)
		TimePeriod.NIGHT:
			return SKY_COLORS["night_bottom"]
	return SKY_COLORS["morning_bottom"]


func get_water_color() -> Color:
	return WATER_COLORS.get(get_period_name(), WATER_COLORS["morning"])


func get_sun_position_normalized() -> float:
	# Returns 0.0 (horizon) to 1.0 (zenith) for sun arc
	if game_hour >= 6.0 and game_hour <= 18.0:
		return sin((game_hour - 6.0) / 12.0 * PI)
	return 0.0


func get_ambient_light() -> float:
	# 0.0 = dark, 1.0 = fully lit
	match current_period:
		TimePeriod.DAWN:
			return lerp(0.2, 0.7, (game_hour - 5.0) / 2.0)
		TimePeriod.MORNING:
			return 0.9
		TimePeriod.AFTERNOON:
			return 1.0
		TimePeriod.EVENING:
			return lerp(0.7, 0.15, (game_hour - 17.0) / 3.0)
		TimePeriod.NIGHT:
			if is_full_moon():
				return 0.25
			return 0.1
	return 0.8
