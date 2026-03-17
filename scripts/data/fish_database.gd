extends RefCounted
class_name FishDatabase

## Static database of all fish types in the game

class FishType:
	var id: String
	var name_vn: String
	var name_en: String
	var rarity: String  # common, uncommon, rare, epic, legendary
	var base_price: int
	var min_size: float
	var max_size: float
	var speed: float  # movement speed
	var fight_difficulty: float  # 0.0-1.0, how hard to reel in
	var zones: Array[String]
	var time_periods: Array[String]  # dawn, morning, afternoon, evening, night, any
	var weather: Array[String]  # clear, cloudy, rain, storm, any
	var special_condition: String  # "", "full_moon", "after_storm"
	var color: Color
	var description: String
	
	func _init(p_id: String, p_name_vn: String, p_name_en: String, p_rarity: String,
			p_price: int, p_min_size: float, p_max_size: float, p_speed: float,
			p_difficulty: float, p_zones: Array[String], p_times: Array[String],
			p_weather: Array[String], p_special: String, p_color: Color,
			p_desc: String) -> void:
		id = p_id
		name_vn = p_name_vn
		name_en = p_name_en
		rarity = p_rarity
		base_price = p_price
		min_size = p_min_size
		max_size = p_max_size
		speed = p_speed
		fight_difficulty = p_difficulty
		zones = p_zones
		time_periods = p_times
		weather = p_weather
		special_condition = p_special
		color = p_color
		description = p_desc


static var _fish_list: Array = []
static var _initialized: bool = false


static func _init_database() -> void:
	if _initialized:
		return
	_initialized = true
	
	_fish_list = [
		# === COMMON ===
		FishType.new(
			"ca_thu", "Cá Thu", "Mackerel", "common",
			10, 0.3, 0.8, 120.0, 0.15,
			["coastal", "reef", "open_sea"] as Array[String],
			["any"] as Array[String],
			["any"] as Array[String],
			"", Color(0.6, 0.7, 0.85),
			"Loài cá phổ biến ở vùng biển Phú Quốc, bơi thành đàn lớn."
		),
		FishType.new(
			"ca_mu", "Cá Mú", "Grouper", "common",
			15, 0.4, 1.2, 60.0, 0.2,
			["coastal", "reef"] as Array[String],
			["morning", "afternoon"] as Array[String],
			["any"] as Array[String],
			"", Color(0.45, 0.3, 0.2),
			"Cá mú thường ẩn nấp trong các rạn san hô, thịt rất ngon."
		),
		FishType.new(
			"ca_nuc", "Cá Nục", "Scad", "common",
			8, 0.15, 0.4, 140.0, 0.1,
			["coastal"] as Array[String],
			["any"] as Array[String],
			["any"] as Array[String],
			"", Color(0.5, 0.6, 0.7),
			"Cá nục nhỏ bé nhưng xuất hiện rất nhiều, thích hợp cho người mới."
		),
		
		# === UNCOMMON ===
		FishType.new(
			"ca_chim", "Cá Chim", "Pompano", "uncommon",
			30, 0.5, 1.5, 100.0, 0.3,
			["reef", "open_sea"] as Array[String],
			["morning", "afternoon"] as Array[String],
			["clear", "cloudy"] as Array[String],
			"", Color(0.75, 0.8, 0.85),
			"Cá chim trắng thường xuất hiện ở vùng rạn san hô khi trời đẹp."
		),
		FishType.new(
			"ca_hong", "Cá Hồng", "Red Snapper", "uncommon",
			40, 0.6, 2.0, 80.0, 0.35,
			["reef", "open_sea"] as Array[String],
			["evening", "night"] as Array[String],
			["any"] as Array[String],
			"", Color(0.9, 0.3, 0.3),
			"Cá hồng đỏ rực, thường hoạt động vào buổi chiều tối."
		),
		FishType.new(
			"ca_bop", "Cá Bớp", "Cobia", "uncommon",
			45, 0.8, 2.5, 90.0, 0.4,
			["open_sea"] as Array[String],
			["morning", "afternoon"] as Array[String],
			["clear"] as Array[String],
			"", Color(0.3, 0.25, 0.2),
			"Cá bớp có thân hình dài, thường bơi gần mặt nước."
		),
		
		# === RARE ===
		FishType.new(
			"ca_ngu", "Cá Ngừ", "Tuna", "rare",
			80, 1.0, 3.0, 150.0, 0.55,
			["open_sea", "deep_sea"] as Array[String],
			["morning", "dawn"] as Array[String],
			["clear", "cloudy"] as Array[String],
			"", Color(0.15, 0.2, 0.45),
			"Cá ngừ đại dương, bơi rất nhanh và mạnh mẽ."
		),
		FishType.new(
			"ca_kiem", "Cá Kiếm", "Swordfish", "rare",
			100, 1.5, 4.0, 180.0, 0.65,
			["open_sea", "deep_sea"] as Array[String],
			["any"] as Array[String],
			["storm", "rain"] as Array[String],
			"", Color(0.2, 0.25, 0.4),
			"Cá kiếm hung dữ, thường xuất hiện khi thời tiết xấu."
		),
		
		# === EPIC ===
		FishType.new(
			"ca_map", "Cá Mập Mako", "Mako Shark", "epic",
			250, 1.5, 4.0, 160.0, 0.8,
			["deep_sea"] as Array[String],
			["any"] as Array[String],
			["any"] as Array[String],
			"", Color(0.3, 0.4, 0.6),
			"Cá mập Mako cực kỳ nhanh nhẹn, chỉ xuất hiện ở những vùng biển sâu thẳm."
		),
		FishType.new(
			"muc_khong_lo", "Mực Khổng Lồ", "Giant Squid", "epic",
			250, 3.0, 6.0, 70.0, 0.85,
			["deep_sea", "abyss"] as Array[String],
			["night"] as Array[String],
			["storm"] as Array[String],
			"", Color(0.5, 0.15, 0.25),
			"Sinh vật bí ẩn từ vực sâu, chỉ xuất hiện trong đêm bão."
		),
		
		# === LEGENDARY ===
		FishType.new(
			"rong_bien", "Rồng Biển", "Sea Dragon", "legendary",
			1000, 5.0, 15.0, 100.0, 0.95,
			["abyss"] as Array[String],
			["night"] as Array[String],
			["storm"] as Array[String],
			"full_moon",
			Color(0.95, 0.85, 0.2),
			"Sinh vật huyền thoại của biển Phú Quốc. Chỉ xuất hiện vào đêm trăng tròn khi bão ập đến."
		),
		FishType.new(
			"rua_vang", "Rùa Vàng", "Golden Turtle", "legendary",
			800, 2.0, 5.0, 40.0, 0.9,
			["abyss"] as Array[String],
			["night"] as Array[String],
			["clear"] as Array[String],
			"full_moon",
			Color(1.0, 0.85, 0.3),
			"Rùa vàng linh thiêng, tương truyền mang lại may mắn cho ngư dân."
		),
	]


static func get_all_fish() -> Array:
	_init_database()
	return _fish_list


static func get_fish_by_id(id: String) -> FishType:
	_init_database()
	for fish in _fish_list:
		if fish.id == id:
			return fish
	return null


static func get_fish_for_zone(zone: String, time_period: String, weather: String, is_full_moon: bool) -> Array:
	_init_database()
	var result: Array = []
	for fish: FishType in _fish_list:
		# Check zone
		if zone not in fish.zones:
			continue
		# Check time
		if "any" not in fish.time_periods and time_period not in fish.time_periods:
			continue
		# Check weather
		if "any" not in fish.weather and weather not in fish.weather:
			continue
		# Check special condition
		if fish.special_condition == "full_moon" and not is_full_moon:
			continue
		result.append(fish)
	return result


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.3, 0.85, 0.3)
		"rare": return Color(0.3, 0.5, 1.0)
		"epic": return Color(0.7, 0.3, 0.9)
		"legendary": return Color(1.0, 0.8, 0.1)
	return Color.WHITE


static func get_rarity_name_vn(rarity: String) -> String:
	match rarity:
		"common": return "Thường"
		"uncommon": return "Không phổ biến"
		"rare": return "Hiếm"
		"epic": return "Sử thi"
		"legendary": return "Huyền thoại"
	return "Thường"


static func get_spawn_weight(rarity: String) -> float:
	match rarity:
		"common": return 50.0
		"uncommon": return 25.0
		"rare": return 12.0
		"epic": return 5.0
		"legendary": return 1.0
	return 50.0
