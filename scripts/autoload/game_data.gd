extends Node

## Global game data singleton — manages player progress and save/load

signal money_changed(new_amount: int)
signal fish_caught_signal(fish_id: String)
signal zone_unlocked(zone_id: String)

# Player currency
var money: int = 0 :
	set(val):
		money = val
		money_changed.emit(money)

# Caught fish: { fish_id: { "count": int, "best_size": float } }
var caught_fish: Dictionary = {}

# Total fish caught count
var total_fish_caught: int = 0

# Current equipment levels (0-indexed)
var rod_level: int = 0
var boat_level: int = 0
var bait_level: int = 0
var line_level: int = 0

# Unlocked zones
var unlocked_zones: Array[String] = ["coastal"]

# Current zone
var current_zone: String = "coastal"

# Equipment definitions
const ROD_NAMES = ["Cần Tre", "Cần Carbon", "Cần Titan", "Cần Huyền Thoại"]
const ROD_REEL_SPEED = [1.0, 1.3, 1.6, 2.0]
const ROD_PRICES = [0, 200, 800, 3000]

const BOAT_NAMES = ["Thuyền Gỗ Nhỏ", "Thuyền Gỗ Lớn", "Thuyền Máy", "Tàu Cá"]
const BOAT_SPEED = [100.0, 150.0, 220.0, 300.0]
const BOAT_PRICES = [0, 300, 1200, 5000]

const BAIT_NAMES = ["Mồi Thường", "Mồi Tốt", "Mồi Hiếm", "Mồi Huyền Thoại"]
const BAIT_ATTRACT = [1.0, 1.5, 2.0, 3.0]
const BAIT_PRICES = [0, 100, 500, 2000]

const LINE_NAMES = ["Dây Mảnh", "Dây Trung", "Dây Dày", "Dây Mythril"]
const LINE_STRENGTH = [1.0, 1.4, 1.8, 2.5]
const LINE_PRICES = [0, 150, 600, 2500]


func _ready() -> void:
	load_game()


func get_rod_reel_speed() -> float:
	return ROD_REEL_SPEED[rod_level]


func get_boat_speed() -> float:
	return BOAT_SPEED[boat_level]


func get_bait_attract() -> float:
	return BAIT_ATTRACT[bait_level]


func get_line_strength() -> float:
	return LINE_STRENGTH[line_level]


func can_upgrade_rod() -> bool:
	return rod_level < ROD_NAMES.size() - 1 and money >= ROD_PRICES[rod_level + 1]


func can_upgrade_boat() -> bool:
	return boat_level < BOAT_NAMES.size() - 1 and money >= BOAT_PRICES[boat_level + 1]


func can_upgrade_bait() -> bool:
	return bait_level < BAIT_NAMES.size() - 1 and money >= BAIT_PRICES[bait_level + 1]


func can_upgrade_line() -> bool:
	return line_level < LINE_NAMES.size() - 1 and money >= LINE_PRICES[line_level + 1]


func upgrade_rod() -> bool:
	if can_upgrade_rod():
		money -= ROD_PRICES[rod_level + 1]
		rod_level += 1
		save_game()
		return true
	return false


func upgrade_boat() -> bool:
	if can_upgrade_boat():
		money -= BOAT_PRICES[boat_level + 1]
		boat_level += 1
		# Check zone unlocks based on boat level
		_check_zone_unlocks()
		save_game()
		return true
	return false


func upgrade_bait() -> bool:
	if can_upgrade_bait():
		money -= BAIT_PRICES[bait_level + 1]
		bait_level += 1
		save_game()
		return true
	return false


func upgrade_line() -> bool:
	if can_upgrade_line():
		money -= LINE_PRICES[line_level + 1]
		line_level += 1
		save_game()
		return true
	return false


func _check_zone_unlocks() -> void:
	if boat_level >= 1 and "reef" not in unlocked_zones:
		unlocked_zones.append("reef")
		zone_unlocked.emit("reef")
	if boat_level >= 2 and "open_sea" not in unlocked_zones:
		unlocked_zones.append("open_sea")
		zone_unlocked.emit("open_sea")
	if boat_level >= 3 and "deep_sea" not in unlocked_zones:
		unlocked_zones.append("deep_sea")
		zone_unlocked.emit("deep_sea")


func register_catch(fish_id: String, size: float, sell_price: int) -> void:
	total_fish_caught += 1
	if fish_id in caught_fish:
		caught_fish[fish_id]["count"] += 1
		if size > caught_fish[fish_id]["best_size"]:
			caught_fish[fish_id]["best_size"] = size
	else:
		caught_fish[fish_id] = {"count": 1, "best_size": size}
	fish_caught_signal.emit(fish_id)


func sell_fish(fish_id: String, count: int, price_per: int) -> void:
	if fish_id in caught_fish and caught_fish[fish_id]["count"] >= count:
		caught_fish[fish_id]["count"] -= count
		money += price_per * count
		save_game()


func is_zone_unlocked(zone_id: String) -> bool:
	return zone_id in unlocked_zones


func save_game() -> void:
	var save_data = {
		"money": money,
		"caught_fish": caught_fish,
		"total_fish_caught": total_fish_caught,
		"rod_level": rod_level,
		"boat_level": boat_level,
		"bait_level": bait_level,
		"line_level": line_level,
		"unlocked_zones": unlocked_zones,
		"current_zone": current_zone,
	}
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists("user://save_data.json"):
		return
	var file = FileAccess.open("user://save_data.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		file.close()
		if result == OK:
			var data = json.data
			money = data.get("money", 0)
			caught_fish = data.get("caught_fish", {})
			total_fish_caught = data.get("total_fish_caught", 0)
			rod_level = data.get("rod_level", 0)
			boat_level = data.get("boat_level", 0)
			bait_level = data.get("bait_level", 0)
			line_level = data.get("line_level", 0)
			var zones = data.get("unlocked_zones", ["coastal"])
			unlocked_zones.clear()
			for z in zones:
				unlocked_zones.append(z)
			current_zone = data.get("current_zone", "coastal")


func reset_game() -> void:
	money = 0
	caught_fish.clear()
	total_fish_caught = 0
	rod_level = 0
	boat_level = 0
	bait_level = 0
	line_level = 0
	unlocked_zones = ["coastal"]
	current_zone = "coastal"
	save_game()
