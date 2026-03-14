extends RefCounted
class_name ZoneDatabase

## Static database of all fishing zones

class ZoneInfo:
	var id: String
	var name_vn: String
	var name_en: String
	var description: String
	var unlock_boat_level: int  # required boat level (0 = start)
	var water_depth: float  # visual depth hint
	var bg_color_tint: Color  # zone-specific water tint
	var world_x_start: float  # X position range in the world
	var world_x_end: float
	
	func _init(p_id: String, p_name_vn: String, p_name_en: String, p_desc: String,
			p_boat_level: int, p_depth: float, p_tint: Color,
			p_x_start: float, p_x_end: float) -> void:
		id = p_id
		name_vn = p_name_vn
		name_en = p_name_en
		description = p_desc
		unlock_boat_level = p_boat_level
		water_depth = p_depth
		bg_color_tint = p_tint
		world_x_start = p_x_start
		world_x_end = p_x_end


static var _zones: Array = []
static var _initialized: bool = false


static func _init_database() -> void:
	if _initialized:
		return
	_initialized = true
	
	_zones = [
		ZoneInfo.new(
			"coastal", "Ven Bờ", "Coastal",
			"Vùng nước nông gần bờ đảo Phú Quốc, nơi lý tưởng cho ngư dân mới.",
			0, 50.0, Color(0.2, 0.6, 0.7),
			0.0, 2000.0
		),
		ZoneInfo.new(
			"reef", "Rạn San Hô", "Coral Reef",
			"Rạn san hô đầy màu sắc với nhiều loài cá đa dạng.",
			1, 100.0, Color(0.1, 0.5, 0.6),
			2000.0, 4000.0
		),
		ZoneInfo.new(
			"open_sea", "Ngoài Khơi", "Open Sea",
			"Vùng biển rộng mở, nơi các loài cá lớn săn mồi.",
			2, 200.0, Color(0.05, 0.3, 0.55),
			4000.0, 6500.0
		),
		ZoneInfo.new(
			"deep_sea", "Biển Sâu", "Deep Sea",
			"Vùng biển sâu thẳm và tối tăm, đầy rẫy nguy hiểm.",
			3, 400.0, Color(0.02, 0.15, 0.35),
			6500.0, 9000.0
		),
		ZoneInfo.new(
			"abyss", "Vực Thẳm", "The Abyss",
			"Nơi sâu nhất của biển, tương truyền là lãnh địa của Rồng Biển.",
			3, 800.0, Color(0.01, 0.05, 0.2),
			9000.0, 12000.0
		),
	]


static func get_all_zones() -> Array:
	_init_database()
	return _zones


static func get_zone_by_id(id: String) -> ZoneInfo:
	_init_database()
	for zone in _zones:
		if zone.id == id:
			return zone
	return null


static func get_zone_at_position(world_x: float) -> ZoneInfo:
	_init_database()
	for zone in _zones:
		if world_x >= zone.world_x_start and world_x < zone.world_x_end:
			return zone
	return _zones[0]


static func get_unlockable_zones(boat_level: int) -> Array:
	_init_database()
	var result: Array = []
	for zone in _zones:
		if zone.unlock_boat_level <= boat_level:
			result.append(zone)
	return result
