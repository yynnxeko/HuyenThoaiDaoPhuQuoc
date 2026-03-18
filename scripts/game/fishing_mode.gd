extends Node2D

## Fishing mode — visual, exciting fishing with visible fish, splashes, and animations

signal fishing_ended
signal fish_caught(fish_id: String, size: float)
signal bait_camera_update(x2d: float, depth_ratio: float)
signal bait_camera_end
signal visual_fish_update(pos: Vector2, fish_data: Object, is_visible: bool, is_fighting: bool)
signal nearby_fish_visual_update(fish_list: Array)

# THÊM MỚI: Trạng thái BAIT_FLYING để quản lý lúc mồi bay trên không
enum FishingState { IDLE, CASTING, BAIT_FLYING, LINE_SINKING, WAITING, FISH_BITE, MINIGAME, CAUGHT, ESCAPED }
var state: FishingState = FishingState.IDLE

# Setup data
var spot_data: Dictionary = {}
var zone_info = null

# Casting
var cast_power: float = 0.0
var cast_charging: bool = false
var cast_max_power: float = 1.0
var cast_speed: float = 1.5

# THÊM MỚI: Biến quản lý đường bay của mồi
var cast_start_pos: Vector2 = Vector2.ZERO
var cast_target_pos: Vector2 = Vector2.ZERO
var cast_flight_time: float = 0.0
var cast_flight_duration: float = 1.0

# Line
var line_start: Vector2 = Vector2.ZERO
var hook_pos: Vector2 = Vector2.ZERO
var hook_target_depth: float = 200.0
var line_sink_speed: float = 80.0
var bait_move_speed_x: float = 220.0
var bait_move_speed_y: float = 180.0
var bait_min_depth: float = 40.0
var bait_max_depth: float = 480.0
var bait_attract_strength: float = 0.0
var bait_movement_energy: float = 0.0
var bait_prev_pos: Vector2 = Vector2.ZERO
var bait_movement_speed: float = 0.0
var fish_spawn_cooldown: float = 6.0
var fish_spawn_timer: float = 0.0
var bite_ready_timer: float = 0.0
var initial_bait_x: float = 0.0 # Lưu vị trí mồi ban đầu để bù trừ camera

# Bobber
var bobber_pos: Vector2 = Vector2.ZERO
var bobber_bob_time: float = 0.0

# Waiting
var wait_timer: float = 0.0
var bite_time: float = 0.0
var bite_fish: Object = null

# Bite notification
var bite_alert_timer: float = 0.0
const BITE_ALERT_DURATION: float = 2.5
var hook_window_start: float = 0.25
var hook_window_length: float = 1.0
var hook_window_perfect: float = 0.3
var hook_quality: String = "none"
var hook_quality_timer: float = 0.0
var hook_shake_time: float = 0.0
var hook_shake_strength: float = 0.0

# Minigame
var tension: float = 0.5
var catch_progress: float = 0.0
var sweet_zone_pos: float = 0.5
var sweet_zone_size: float = 0.25
var fish_pull_timer: float = 0.0
var fish_pull_direction: float = 0.0
var fish_pull_vertical: float = 0.0
var fish_strength: float = 2.0
var fish_stamina: float = 3.0
var fish_aggression: float = 0.2
var fish_weight: float = 1.0
var fish_fatigue: float = 0.0
var fish_stun_time: float = 0.0

# Visual
var wave_time: float = 0.0
var water_line_y: float = 540.0
var surface_y: float = 540.0
var surface_shift: float = 520.0

# Boat/camera references
var boat_ref: Node = null
var camera_ref: Camera3D = null

# === VISUAL FISH ===
var nearby_fish: Array = [] 
var biting_fish_pos: Vector2 = Vector2.ZERO 
var biting_fish_target: Vector2 = Vector2.ZERO
var fish_fight_offset: Vector2 = Vector2.ZERO 
var caught_fish_anim: float = 0.0 

# === PARTICLES ===
var bubbles: Array = []
var splashes: Array = []
var sparkles: Array = []


func setup(spot: Dictionary, zone, boat: Node = null, camera: Camera3D = null) -> void:
	spot_data = spot
	zone_info = zone
	boat_ref = boat
	camera_ref = camera
	state = FishingState.IDLE
	_update_line_start()
	hook_pos = line_start
	bait_prev_pos = hook_pos
	_spawn_nearby_fish()

func start_fishing() -> void:
	if state == FishingState.IDLE:
		state = FishingState.CASTING
		cast_power = 0.0
		cast_charging = true

func _end_fishing() -> void:
	# Reset all states
	state = FishingState.IDLE
	bite_fish = null
	nearby_fish.clear()
	bubbles.clear()
	splashes.clear()
	sparkles.clear()
	bait_camera_end.emit()
	fishing_ended.emit()


func _ready() -> void:
	_calculate_bite_time()


func _update_line_start() -> void:
	if boat_ref and camera_ref and boat_ref is Node3D:
		var boat_3d := boat_ref as Node3D
		var forward = boat_3d.global_basis.x.normalized()
		var rod_tip_world = boat_3d.global_position + forward * 1.4 + Vector3(0, 1.6, 0)
		line_start = camera_ref.unproject_position(rod_tip_world)
		var viewport_size = get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
		line_start.x = clampf(line_start.x, 0.0, viewport_size.x)
		line_start.y = clampf(line_start.y, 0.0, viewport_size.y)
		return
	if boat_ref and boat_ref is Node2D:
		var boat_2d := boat_ref as Node2D
		var rod_tip_offset = Vector2(100, -65) if boat_2d.facing_right else Vector2(-100, -65)
		line_start = boat_2d.position + rod_tip_offset
		return
	line_start = Vector2(960, water_line_y - 60)


func _spawn_nearby_fish() -> void:
	nearby_fish.clear()
	var zone_id = spot_data.get("zone", "coastal")
	# Get available fish for this zone to make models match
	var avail = FishDatabase.get_all_fish().filter(func(f): return zone_id in f.zones)
	if avail.is_empty(): avail = FishDatabase.get_all_fish()

	for i in range(randi_range(2, 4)):
		var f_data = avail.pick_random()
		var behavior = "small"
		if f_data.rarity in ["rare", "epic"]: behavior = "predator"
		elif f_data.rarity == "legendary": behavior = "rare"
		
		var fish_x = randf_range(300, 1600)
		var fish_y = randf_range(water_line_y + 60, 900)
		nearby_fish.append({
			"fish_id": f_data.id,
			"fish_data": f_data,
			"x": fish_x,
			"y": fish_y,
			"base_y": fish_y,
			"speed": randf_range(30, 80),
			"dir": [-1.0, 1.0][randi() % 2],
			"size": randf_range(16, 28),
			"color": f_data.color,
			"wave_phase": randf() * TAU,
			"interested": false,
			"flee": false,
			"behavior": behavior,
			"interest": 0.0,
			"suspicion": 0.0,
			"fishCuriosity": randf_range(0.6, 1.3),
			"fishCaution": randf_range(0.6, 1.4),
			"bite_threshold": randf_range(45.0, 75.0),
			"suspicion_limit": randf_range(80.0, 120.0),
			"cue": "idle",
			"cue_timer": randf_range(0.0, 2.0),
			"circle_angle": randf() * TAU,
			"circle_radius": randf_range(28.0, 60.0),
			"doubt_phase": randf() * TAU,
			"tail_amp": 1.0,
			"alpha": 0.5
		})


func _spawn_bubble(pos: Vector2, count: int = 3) -> void:
	for i in range(count):
		bubbles.append({
			"x": pos.x + randf_range(-10, 10),
			"y": pos.y,
			"speed": randf_range(30, 60),
			"size": randf_range(2, 5),
			"alpha": 0.6,
			"wobble": randf() * TAU,
		})


func _spawn_splash(pos: Vector2, count: int = 5) -> void:
	for i in range(count):
		var angle = randf_range(-PI * 0.8, -PI * 0.2)
		splashes.append({
			"x": pos.x,
			"y": pos.y,
			"vx": cos(angle) * randf_range(40, 120),
			"vy": sin(angle) * randf_range(60, 150),
			"size": randf_range(2, 5),
			"alpha": 0.8,
			"gravity": 300.0,
		})


func _spawn_sparkle(pos: Vector2, color: Color, count: int = 8) -> void:
	for i in range(count):
		sparkles.append({
			"x": pos.x + randf_range(-30, 30),
			"y": pos.y + randf_range(-30, 30),
			"alpha": 1.0,
			"size": randf_range(3, 7),
			"color": color,
			"phase": randf() * TAU,
		})


func _process(delta: float) -> void:
	wave_time += delta
	if fish_spawn_timer > 0.0:
		fish_spawn_timer = max(0.0, fish_spawn_timer - delta)
	if state != FishingState.IDLE:
		bobber_bob_time += delta
	if state == FishingState.IDLE or state == FishingState.CASTING:
		surface_y = water_line_y
	bait_attract_strength = max(0.0, bait_attract_strength - delta * 1.2)
	bait_movement_energy = max(0.0, bait_movement_energy - delta * 1.5)
	
	_update_line_start()
	
	match state:
		FishingState.IDLE:
			_process_idle(delta)
		FishingState.CASTING:
			_process_casting(delta)
		FishingState.BAIT_FLYING:  # THÊM MỚI: Update logic mồi đang bay
			_process_bait_flying(delta)
		FishingState.LINE_SINKING:
			_process_sinking(delta)
		FishingState.WAITING:
			_process_waiting(delta)
		FishingState.FISH_BITE:
			_process_bite(delta)
		FishingState.MINIGAME:
			_process_minigame(delta)
		FishingState.CAUGHT:
			_process_caught(delta)
		FishingState.ESCAPED:
			_process_escaped(delta)
	
	_update_nearby_fish(delta)
	_update_particles(delta)
	_update_bait_camera()
	
	if hook_quality_timer > 0.0:
		hook_quality_timer = max(0.0, hook_quality_timer - delta)
	if hook_shake_time > 0.0:
		hook_shake_time = max(0.0, hook_shake_time - delta)
		
	_process_bait_control(delta)
	
	if state != FishingState.IDLE and state != FishingState.CASTING and state != FishingState.BAIT_FLYING: # Không bobber lúc đang bay
		bobber_pos.y = surface_y + sin(bobber_bob_time * 2.0) * 3.0
		bobber_pos.x = lerp(bobber_pos.x, hook_pos.x, 0.12)
	
	if bite_fish:
		var is_fighting = (state == FishingState.MINIGAME)
		var is_caught = (state == FishingState.CAUGHT)
		var vis = (state == FishingState.FISH_BITE or is_fighting or is_caught)
		# Bắn thẳng tọa độ thực tế, không bù trừ nữa
		visual_fish_update.emit(biting_fish_pos, bite_fish, vis, is_fighting)
	else:
		visual_fish_update.emit(Vector2.ZERO, null, false, false)
	
	# Bắn thẳng danh sách cá xung quanh
	nearby_fish_visual_update.emit(nearby_fish)
	
	queue_redraw()


func _update_bait_camera() -> void:
	if state == FishingState.LINE_SINKING or state == FishingState.WAITING or state == FishingState.FISH_BITE or state == FishingState.MINIGAME:
		var max_depth = max(1.0, hook_target_depth - water_line_y)
		var depth = max(0.0, hook_pos.y - water_line_y)
		var depth_ratio = clampf(depth / max_depth, 0.0, 1.0)
		surface_y = clampf(lerp(water_line_y, water_line_y - surface_shift, depth_ratio), 120.0, water_line_y)
		bait_camera_update.emit(hook_pos.x, depth_ratio)


func _process_idle(_delta: float) -> void:
	if Input.is_action_just_pressed("cast_line"):
		state = FishingState.CASTING
		cast_power = 0.0
		cast_charging = true


# ĐÃ SỬA: Thay vì rơi ngay xuống nước, tính toán vị trí đích và chuyển sang trạng thái bay
func _process_casting(delta: float) -> void:
	if cast_charging:
		cast_power = clampf(cast_power + cast_speed * delta, 0.0, cast_max_power)
		if Input.is_action_just_released("cast_line"):
			cast_charging = false
			hook_target_depth = water_line_y + 50.0 + cast_power * 300.0
			var cast_dir = 1.0
			if boat_ref and boat_ref is Node2D:
				cast_dir = 1.0 if (boat_ref as Node2D).get("facing_right") else -1.0
			elif boat_ref and boat_ref is Node3D:
				var boat_3d := boat_ref as Node3D
				cast_dir = 1.0 if boat_3d.global_basis.x.x >= 0.0 else -1.0
			
			cast_start_pos = line_start
			# Ném càng xa đường bay càng dài
			cast_target_pos = Vector2(line_start.x + cast_power * 400.0 * cast_dir, surface_y) 
			cast_flight_time = 0.0
			# Ném nhẹ bay nhanh, ném mạnh bay lâu hơn một chút
			cast_flight_duration = 0.5 + cast_power * 0.4 
			
			AudioManager.play_cast()
			state = FishingState.BAIT_FLYING


# THÊM MỚI: Hàm xử lý đường cong vút lên rồi rơi xuống nước
func _process_bait_flying(delta: float) -> void:
	cast_flight_time += delta
	var t = clampf(cast_flight_time / cast_flight_duration, 0.0, 1.0)
	
	# Tính toán x/y trên mặt phẳng tuyến tính
	var current_base = cast_start_pos.lerp(cast_target_pos, t)
	
	# Tính toán độ cao (Vòng cung) bằng hàm Sine
	var max_arc_height = 80.0 + cast_power * 150.0 # Ném mạnh bay càng cao
	var arc_height = sin(t * PI) * max_arc_height
	
	# Gộp lại tạo thành vị trí trên không trung
	bobber_pos = Vector2(current_base.x, current_base.y - arc_height)
	hook_pos = bobber_pos 
	
	# Khi hoàn thành đường bay (t=1.0) -> chạm mặt nước
	if t >= 1.0:
		bobber_pos = cast_target_pos
		hook_pos = bobber_pos
		initial_bait_x = hook_pos.x
		_spawn_splash(bobber_pos, 8)
		AudioManager.play_splash(cast_power)
		state = FishingState.LINE_SINKING


func _process_sinking(delta: float) -> void:
	hook_pos.y = move_toward(hook_pos.y, hook_target_depth, line_sink_speed * delta)
	# Bubbles while sinking
	if randi() % 5 == 0:
		_spawn_bubble(hook_pos, 1)
	if abs(hook_pos.y - hook_target_depth) < 1.0:
		state = FishingState.WAITING
		wait_timer = 0.0
		_calculate_bite_time()
		bait_attract_strength = 0.2


func _process_bait_control(delta: float) -> void:
	if state != FishingState.WAITING and state != FishingState.FISH_BITE:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_x := input_vec.x
	var input_y := input_vec.y
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_y += 1.0
	if Input.is_action_pressed("move_left"):
		input_x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_x += 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_vel = Input.get_last_mouse_velocity()
		input_x += clampf(mouse_vel.x / 600.0, -1.0, 1.0)
		input_y += clampf(mouse_vel.y / 600.0, -1.0, 1.0)
	if input_x == 0.0 and input_y == 0.0:
		bait_movement_speed = max(0.0, bait_movement_speed - delta * 200.0)
		return
	var prev_hook = hook_pos
	hook_pos.x += input_x * bait_move_speed_x * delta
	hook_pos.y += input_y * bait_move_speed_y * delta
	var viewport_size = get_viewport_rect().size
	hook_pos.x = clampf(hook_pos.x, 40.0, viewport_size.x - 40.0)
	var min_y = water_line_y + bait_min_depth
	var max_y = water_line_y + bait_max_depth
	hook_pos.y = clampf(hook_pos.y, min_y, max_y)
	var move_dist = hook_pos.distance_to(prev_hook)
	if move_dist > 1.0:
		bait_attract_strength = clampf(bait_attract_strength + move_dist * 0.002, 0.0, 1.0)
		bait_movement_energy = clampf(bait_movement_energy + move_dist * 0.004, 0.0, 1.0)
		bait_movement_speed = lerpf(bait_movement_speed, move_dist / max(delta, 0.001), 0.35)
		if randi() % 3 == 0:
			_spawn_bubble(hook_pos, 1)


func _process_waiting(delta: float) -> void:
	wait_timer += delta
	bite_ready_timer += delta
	# Respawn fish if most have fled
	var active_count := 0
	for f in nearby_fish:
		if not f.get("flee", false):
			active_count += 1
	if active_count <= 2 and fish_spawn_timer <= 0.0:
		_spawn_nearby_fish()
		fish_spawn_timer = fish_spawn_cooldown
	
	# Make some fish interested in the bait over time
	var interest_progress = clampf(wait_timer / bite_time, 0.0, 1.0)
	for fish in nearby_fish:
		if interest_progress > 0.4 and randf() < 0.002:
			fish["interested"] = true
	
	if wait_timer >= bite_time:
		var candidate_index := -1
		for i in range(nearby_fish.size()):
			var f = nearby_fish[i]
			if f.get("flee", false):
				continue
			var interest_val: float = float(f.get("interest", 0.0))
			var bite_threshold: float = float(f.get("bite_threshold", 70.0))
			if interest_val >= bite_threshold:
				candidate_index = i
				break
		if bite_fish != null and (candidate_index != -1 or bite_ready_timer >= bite_time * 1.6):
			state = FishingState.FISH_BITE
			bite_alert_timer = 0.0
			hook_quality = "none"
			_setup_fish_stats()
			AudioManager.play_bite_alert()
			# Position the biting fish at the visible candidate
			var candidate = nearby_fish[candidate_index] if candidate_index != -1 else nearby_fish[randi() % nearby_fish.size()]
			biting_fish_pos = Vector2(candidate["x"], candidate["y"])
			biting_fish_target = hook_pos
			candidate["flee"] = true
			_spawn_bubble(hook_pos, 5)
			bite_ready_timer = 0.0
		else:
			# Keep waiting until a visible fish reaches bite threshold
			wait_timer = bite_time * 0.7
	
	if Input.is_action_just_pressed("fishing_toggle"):
		_end_fishing()


func _process_bite(delta: float) -> void:
	bite_alert_timer += delta
	
	# Fish rushes toward hook!
	biting_fish_pos = biting_fish_pos.lerp(biting_fish_target, delta * 3.0)
	
	# Vigorous bobber movement
	bobber_pos.y = surface_y + sin(bite_alert_timer * 15.0) * 10.0
	
	# Bubbles from fish activity
	if randi() % 3 == 0:
		_spawn_bubble(hook_pos, 2)
	
	# Splash at bobber
	if int(bite_alert_timer * 10) % 3 == 0:
		_spawn_splash(bobber_pos, 2)
	
	if Input.is_action_just_pressed("reel_in") or Input.is_action_just_pressed("cast_line"):
		if bite_alert_timer < hook_window_start:
			AudioManager.play_fish_escape()
			state = FishingState.ESCAPED
			wait_timer = 0.0 # SỬA LỖI: Reset timer để hiện chữ
			return
		var elapsed = bite_alert_timer - hook_window_start
		if elapsed <= hook_window_perfect:
			hook_quality = "perfect"
		elif elapsed <= hook_window_length:
			hook_quality = "good"
		else:
			AudioManager.play_fish_escape()
			state = FishingState.ESCAPED
			wait_timer = 0.0 # SỬA LỖI: Reset timer để hiện chữ
			return
		hook_quality_timer = 0.8
		if hook_quality == "perfect":
			hook_shake_time = 0.4
			hook_shake_strength = 4.0
			fish_stun_time = 1.0
			_spawn_splash(bobber_pos, 16)
		elif hook_quality == "good":
			hook_shake_time = 0.25
			hook_shake_strength = 2.5
			_spawn_splash(bobber_pos, 12)
		# Legendary fish = boss encounter!
		if bite_fish and bite_fish.rarity == "legendary":
			_launch_boss_encounter()
			return
		state = FishingState.MINIGAME
		tension = 0.5
		catch_progress = 0.0
		_setup_minigame_difficulty()
		if hook_quality == "perfect":
			fish_fatigue = min(1.0, fish_fatigue + 0.35)
		_spawn_splash(bobber_pos, 10)
		AudioManager.play_splash(1.2)
	
	if bite_alert_timer >= BITE_ALERT_DURATION:
		bite_fish = null
		state = FishingState.WAITING
		wait_timer = 0.0
		_calculate_bite_time()
		# Fish flee
		for fish in nearby_fish:
			fish["flee"] = true


func _process_minigame(delta: float) -> void:
	if bite_fish == null:
		state = FishingState.ESCAPED
		wait_timer = 0.0 # SỬA LỖI: Reset timer
		return
	if fish_stun_time > 0.0:
		fish_stun_time = max(0.0, fish_stun_time - delta)
	
	# Fish pulls randomly
	fish_pull_timer += delta
	if fish_pull_timer >= 0.3 + randf() * 0.5:
		fish_pull_timer = 0.0
		var aggression = 0.6 + fish_aggression * 0.8
		if fish_stun_time > 0.0:
			aggression *= 0.2
		fish_pull_direction = randf_range(-1.0, 1.0) * bite_fish.fight_difficulty * aggression
		fish_pull_vertical = randf_range(-1.0, 1.0) * bite_fish.fight_difficulty * aggression
		# Visual: fish jerks
		fish_fight_offset = Vector2(randf_range(-30, 30), randf_range(-15, 15))
		_spawn_bubble(hook_pos + fish_fight_offset, 3)
	
	# Smooth the fight offset back toward 0
	fish_fight_offset = fish_fight_offset.lerp(Vector2.ZERO, delta * 3.0)
	
	# Sweet zone moves
	sweet_zone_pos += fish_pull_direction * delta * 0.8
	sweet_zone_pos = clampf(sweet_zone_pos, sweet_zone_size / 2.0, 1.0 - sweet_zone_size / 2.0)
	
	# Player reels
	if Input.is_action_pressed("reel_in"):
		var reel_bonus = 1.0 + fish_fatigue * 0.8
		tension += delta * GameData.get_rod_reel_speed() * 0.8 * reel_bonus
		# Reel bubbles + sound
		if randi() % 4 == 0:
			AudioManager.play_reel_tick()
		if randi() % 6 == 0:
			_spawn_bubble(hook_pos, 1)
	else:
		tension -= delta * 0.4
	tension = clampf(tension, 0.0, 1.0)
	
	# Progress
	var in_zone = abs(tension - sweet_zone_pos) < sweet_zone_size / 2.0
	if in_zone:
		var hook_bonus = 1.0 if hook_quality == "normal" else 1.25
		if hook_quality == "perfect":
			hook_bonus = 1.6
		catch_progress += delta * 0.4 * GameData.get_rod_reel_speed() * hook_bonus
		fish_fatigue = clampf(fish_fatigue + delta * 0.15, 0.0, 1.0)
		# Hook moves up toward surface as progress increases
		hook_pos.y = lerp(hook_target_depth, water_line_y + 20.0, catch_progress)
	else:
		catch_progress -= delta * 0.15
		# Fish pulls hook deeper
		hook_pos.y = move_toward(hook_pos.y, hook_target_depth, 20.0 * delta)
	catch_progress = clampf(catch_progress, 0.0, 1.0)
	# Apply fish pull directions
	hook_pos.x += fish_pull_direction * 20.0 * delta
	hook_pos.y += fish_pull_vertical * 12.0 * delta
	var viewport_size = get_viewport_rect().size
	hook_pos.x = clampf(hook_pos.x, 40.0, viewport_size.x - 40.0)
	hook_pos.y = clampf(hook_pos.y, water_line_y + bait_min_depth, water_line_y + bait_max_depth)
	
	# Fish position follows hook during fight
	biting_fish_pos = hook_pos + fish_fight_offset
	
	# Line break
	if tension >= 0.98:
		var durability = max(0.1, GameData.get_line_strength())
		var break_chance = clampf(fish_strength / (durability * 8.0), 0.1, 0.9)
		if randf() < break_chance:
			_spawn_splash(bobber_pos, 12)
			AudioManager.play_line_snap()
			state = FishingState.ESCAPED
			wait_timer = 0.0 # SỬA LỖI: Đứt dây câu
			return
	
	# Caught!
	if catch_progress >= 1.0:
		state = FishingState.CAUGHT
		caught_fish_anim = 0.0
		_spawn_splash(bobber_pos, 15)
		if bite_fish:
			var rarity_col = FishDatabase.get_rarity_color(bite_fish.rarity)
			_spawn_sparkle(bobber_pos, rarity_col, 12)
			if bite_fish.rarity == "legendary":
				AudioManager.play_catch_legendary()
			else:
				AudioManager.play_catch_success()
		wait_timer = 0.0
	
	# Escape
	if tension <= 0.02:
		catch_progress -= delta * 0.5
		if catch_progress <= 0.0:
			AudioManager.play_fish_escape()
			state = FishingState.ESCAPED
			wait_timer = 0.0 # SỬA LỖI: Tuột mất cá do nhả dây


func _process_caught(delta: float) -> void:
	caught_fish_anim += delta
	# Fish rises out of water
	biting_fish_pos.y = lerp(water_line_y, water_line_y - 80.0, clampf(caught_fish_anim / 0.8, 0.0, 1.0))
	biting_fish_pos.x = lerp(biting_fish_pos.x, line_start.x, delta * 2.0)
	
	if bite_fish and caught_fish_anim < 0.1:
		var size = randf_range(bite_fish.min_size, bite_fish.max_size)
		fish_caught.emit(bite_fish.id, size)
		bite_fish = null
	
	wait_timer += delta
	if wait_timer >= 2.5:
		_end_fishing()


func _process_escaped(delta: float) -> void:
	wait_timer += delta
	# Fish swims away fast
	biting_fish_pos.x += 200.0 * delta
	biting_fish_pos.y += 50.0 * delta
	if wait_timer > 1.5:
		state = FishingState.WAITING
		wait_timer = 0.0
		_calculate_bite_time()
		_spawn_nearby_fish()


func _launch_boss_encounter() -> void:
	# Hide fishing UI, load boss scene
	visible = false
	var boss_scene = load("res://scenes/game/boss_encounter.tscn")
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.setup_boss(bite_fish, boat_ref)
		boss.boss_defeated.connect(_on_boss_defeated)
		boss.boss_escaped.connect(_on_boss_escaped)
		get_parent().add_child(boss)


func _on_boss_defeated(fish_id: String, size: float) -> void:
	fish_caught.emit(fish_id, size)
	visible = true
	state = FishingState.CAUGHT
	caught_fish_anim = 0.0
	wait_timer = 0.0


func _on_boss_escaped() -> void:
	visible = true
	state = FishingState.WAITING
	wait_timer = 0.0
	_calculate_bite_time()
	_spawn_nearby_fish()


func _update_nearby_fish(delta: float) -> void:
	for fish in nearby_fish:
		if fish["flee"]:
			fish["x"] += fish["speed"] * fish["dir"] * 3.0 * delta
			fish["alpha"] = max(0, fish.get("alpha", 0.5) - delta)
			if fish["alpha"] <= 0.0:
				fish["remove"] = true
			continue
		if state == FishingState.WAITING:
			var behavior = fish.get("behavior", "small")
			var lure_movement = clampf(bait_movement_energy, 0.0, 1.0)
			var movement_speed_norm = clampf(bait_movement_speed / 400.0, 0.0, 1.0)
			var curiosity = fish.get("fishCuriosity", 1.0)
			var caution = fish.get("fishCaution", 1.0)
			var interest = fish.get("interest", 0.0)
			var suspicion = fish.get("suspicion", 0.0)
			# Small fish like gentle movement, predators like faster movement, rare fish are patient
			var behavior_bonus = 1.0
			if behavior == "small":
				behavior_bonus = 1.0 - movement_speed_norm * 0.6
			elif behavior == "predator":
				behavior_bonus = 0.6 + movement_speed_norm * 0.9
			else:
				behavior_bonus = 0.5
			interest += (lure_movement * curiosity * behavior_bonus * 55.0 + bait_attract_strength * 10.0) * delta
			suspicion += movement_speed_norm * caution * 18.0 * delta
			suspicion = max(0.0, suspicion - (0.8 + curiosity * 0.3) * delta)
			fish["interest"] = clampf(interest, 0.0, 100.0)
			fish["suspicion"] = clampf(suspicion, 0.0, 120.0)
			if fish["suspicion"] > fish.get("suspicion_limit", 90.0):
				fish["flee"] = true
				fish["interested"] = false
				continue
			if fish["interest"] >= fish.get("bite_threshold", 70.0):
				fish["interested"] = true
		
		if fish["interested"] and state == FishingState.WAITING:
			var interest_val: float = float(fish.get("interest", 0.0))
			var bite_threshold: float = float(fish.get("bite_threshold", 70.0))
			var suspicion_val: float = float(fish.get("suspicion", 0.0))
			var suspicion_limit: float = float(fish.get("suspicion_limit", 90.0))
			var cue := "approach"
			if suspicion_val > suspicion_limit * 0.7:
				cue = "doubt"
			elif interest_val < bite_threshold * 0.6:
				cue = "approach"
			elif interest_val < bite_threshold * 0.9:
				cue = "circle"
			else:
				cue = "near_bite"
			fish["cue"] = cue
			fish["cue_timer"] = fish.get("cue_timer", 0.0) + delta
			if cue == "approach":
				var dir_to_hook = hook_pos.x - fish["x"]
				# Update direction based on target
				if abs(dir_to_hook) > 10:
					fish["dir"] = sign(dir_to_hook)
				
				var approach_speed = fish["speed"] * 0.7
				fish["x"] = move_toward(fish["x"], hook_pos.x - fish["dir"] * 30.0, approach_speed * delta)
				fish["y"] = lerp(fish["y"], hook_pos.y + sin(wave_time * 2.0) * 10.0, 0.8 * delta)
				fish["tail_amp"] = lerp(fish.get("tail_amp", 1.0), 1.25, 0.1)
			elif cue == "circle":
				fish["circle_angle"] = fish.get("circle_angle", 0.0) + delta * (1.2 + randf() * 0.4)
				var radius = fish.get("circle_radius", 40.0)
				var target = hook_pos + Vector2(cos(fish["circle_angle"]) * radius, sin(fish["circle_angle"]) * radius * 0.5)
				fish["x"] = lerp(fish["x"], target.x, 1.2 * delta)
				fish["y"] = lerp(fish["y"], target.y, 1.2 * delta)
				fish["dir"] = sign(cos(fish["circle_angle"] + 0.1)) # Face movement direction
				fish["tail_amp"] = lerp(fish.get("tail_amp", 1.0), 1.3, 0.1)
			elif cue == "doubt":
				fish["doubt_phase"] = fish.get("doubt_phase", 0.0) + delta * 2.5
				var wobble = sin(fish["doubt_phase"]) * 45.0
				var target = hook_pos + Vector2(wobble - fish["dir"] * 50.0, sin(wave_time) * 20.0)
				fish["x"] = lerp(fish["x"], target.x, 0.6 * delta)
				fish["y"] = lerp(fish["y"], target.y, 0.6 * delta)
				fish["tail_amp"] = lerp(fish.get("tail_amp", 1.0), 1.4, 0.1)
			elif cue == "near_bite":
				fish["circle_angle"] = fish.get("circle_angle", 0.0) + delta * 3.0
				var radius2 = max(15.0, fish.get("circle_radius", 40.0) * 0.5)
				var target2 = hook_pos + Vector2(cos(fish["circle_angle"]) * radius2, sin(fish["circle_angle"]) * radius2 * 0.3)
				fish["x"] = lerp(fish["x"], target2.x, 2.5 * delta)
				fish["y"] = lerp(fish["y"], target2.y, 2.5 * delta)
				fish["dir"] = sign(cos(fish["circle_angle"] + 0.1))
				fish["tail_amp"] = lerp(fish.get("tail_amp", 1.0), 1.8, 0.2)
		else:
			# Normal swimming with organic drift
			var drift = sin(wave_time * 0.4 + fish["wave_phase"]) * 15.0 * delta
			fish["x"] += (fish["speed"] * fish["dir"] * delta) + drift
			fish["y"] = fish["base_y"] + sin(wave_time * 1.2 + fish["wave_phase"]) * 18.0
			fish["tail_amp"] = lerp(fish.get("tail_amp", 1.0), 1.0, 0.1)
		
		# Bait movement attracts fish
		if state == FishingState.WAITING and bait_attract_strength > 0.0 and not fish["flee"]:
			if randf() < 0.015 + bait_attract_strength * 0.08:
				fish["interested"] = true
		
		# Wrap
		if fish["x"] > 2000:
			fish["x"] = -50.0
			fish["dir"] = 1.0
		elif fish["x"] < -50:
			fish["x"] = 2000.0
			fish["dir"] = -1.0

	# Remove fully fled fish
	var idx := nearby_fish.size() - 1
	while idx >= 0:
		if nearby_fish[idx].get("remove", false):
			nearby_fish.remove_at(idx)
		idx -= 1


func _update_particles(delta: float) -> void:
	# Bubbles
	var i = bubbles.size() - 1
	while i >= 0:
		var b = bubbles[i]
		b["y"] -= b["speed"] * delta
		b["x"] += sin(wave_time * 3.0 + b["wobble"]) * 0.5
		b["alpha"] -= delta * 0.4
		if b["alpha"] <= 0 or b["y"] < water_line_y - 10:
			bubbles.remove_at(i)
		i -= 1
	
	# Splashes
	i = splashes.size() - 1
	while i >= 0:
		var s = splashes[i]
		s["x"] += s["vx"] * delta
		s["y"] += s["vy"] * delta
		s["vy"] += s["gravity"] * delta
		s["alpha"] -= delta * 1.5
		if s["alpha"] <= 0:
			splashes.remove_at(i)
		i -= 1
	
	# Sparkles
	i = sparkles.size() - 1
	while i >= 0:
		var sp = sparkles[i]
		sp["alpha"] -= delta * 0.8
		sp["y"] -= 20.0 * delta
		if sp["alpha"] <= 0:
			sparkles.remove_at(i)
		i -= 1


func _calculate_bite_time() -> void:
	var zone_id = spot_data.get("zone", "coastal")
	var period = TimeWeather.get_period_name()
	var weather = TimeWeather.get_weather_name()
	var full_moon = TimeWeather.is_full_moon()
	
	var available_fish = FishDatabase.get_fish_for_zone(zone_id, period, weather, full_moon)
	
	if available_fish.size() == 0:
		bite_time = randf_range(8.0, 15.0)
		bite_fish = null
		return
	
	var total_weight = 0.0
	var weights = []
	for fish in available_fish:
		var w = FishDatabase.get_spawn_weight(fish.rarity) * GameData.get_bait_attract()
		# Giảm tỉ lệ cá to dựa trên độ gần bờ (càng gần x=0 càng ít cá to)
		if zone_id == "coastal" and fish.max_size > 1.0:
			var x_pos = spot_data.get("x", 1000.0)
			var proximity_to_shore = clampf(1.0 - (x_pos / 2000.0), 0.0, 1.0)
			var dynamic_penalty = lerpf(0.3, 0.02, proximity_to_shore)
			w *= dynamic_penalty
		weights.append(w)
		total_weight += w
	
	var roll = randf() * total_weight
	var accumulated = 0.0
	bite_fish = available_fish[0]
	for i in range(available_fish.size()):
		accumulated += weights[i]
		if roll <= accumulated:
			bite_fish = available_fish[i]
			break
	
	match bite_fish.rarity:
		"common": bite_time = randf_range(3.0, 8.0)
		"uncommon": bite_time = randf_range(5.0, 12.0)
		"rare": bite_time = randf_range(8.0, 18.0)
		"epic": bite_time = randf_range(12.0, 25.0)
		"legendary": bite_time = randf_range(20.0, 40.0)
	
	bite_time /= GameData.get_bait_attract()


func _setup_minigame_difficulty() -> void:
	if bite_fish:
		sweet_zone_size = 0.3 - bite_fish.fight_difficulty * 0.2
		sweet_zone_size = clampf(sweet_zone_size, 0.08, 0.3)


func _setup_fish_stats() -> void:
	if bite_fish == null:
		return
	var difficulty = clampf(bite_fish.fight_difficulty, 0.0, 1.0)
	var size_avg = (bite_fish.min_size + bite_fish.max_size) * 0.5
	fish_weight = size_avg
	fish_strength = lerpf(2.0, 10.0, difficulty)
	fish_stamina = lerpf(3.0, 12.0, clampf(size_avg / 6.0, 0.0, 1.0))
	fish_aggression = lerpf(0.2, 1.0, difficulty)
	fish_fatigue = 0.0


func _end_fishing() -> void:
	bait_camera_end.emit()
	fishing_ended.emit()


func _input(event: InputEvent) -> void:
	if state == FishingState.IDLE or state == FishingState.WAITING:
		if event.is_action_pressed("fishing_toggle"):
			_end_fishing()


# ===================== DRAWING =====================

func _draw() -> void:
	var sw = 1920.0
	var sh = 1080.0
	var shake_offset = Vector2.ZERO
	if hook_shake_time > 0.0:
		shake_offset = Vector2(randf_range(-hook_shake_strength, hook_shake_strength), randf_range(-hook_shake_strength, hook_shake_strength))
		draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	
	# Subtle dark overlay
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.1))
	
	# === BUBBLES ===
	for b in bubbles:
		draw_circle(Vector2(b["x"], b["y"]), b["size"], Color(0.7, 0.85, 1.0, b["alpha"] * 0.6))
		draw_circle(Vector2(b["x"], b["y"]), b["size"] * 0.6, Color(1.0, 1.0, 1.0, b["alpha"] * 0.3))

	# === WATER RIPPLE (curiosity cue) ===
	if state == FishingState.WAITING:
		var ripple_amp = 0.0
		var ripple_speed = 1.2
		var ripple_size = 22.0
		for f in nearby_fish:
			if f.get("flee", false):
				continue
			if f.get("interested", false):
				var behavior = f.get("behavior", "small")
				if behavior == "predator":
					ripple_amp = max(ripple_amp, 0.9)
					ripple_speed = max(ripple_speed, 2.2)
					ripple_size = max(ripple_size, 38.0)
				elif behavior == "rare":
					ripple_amp = max(ripple_amp, 0.6)
					ripple_speed = max(ripple_speed, 1.0)
					ripple_size = max(ripple_size, 30.0)
				else:
					ripple_amp = max(ripple_amp, 0.4)
					ripple_speed = max(ripple_speed, 1.2)
					ripple_size = max(ripple_size, 26.0)
		if ripple_amp > 0.0:
			var t = wave_time * ripple_speed
			for i in range(2):
				var r = ripple_size + float(i) * 12.0 + sin(t + float(i)) * 4.0
				var alpha = 0.18 * ripple_amp - float(i) * 0.05
				if alpha > 0.01:
					draw_arc(Vector2(hook_pos.x, surface_y), r, 0, TAU, 48, Color(0.8, 0.9, 1.0, alpha), 1.2)
	
	# === FISHING LINE ===
	if state != FishingState.IDLE:
		_draw_fishing_line()
	
	# === BITING / FIGHTING FISH ===
	if (state == FishingState.FISH_BITE or state == FishingState.MINIGAME):
		if bite_fish:
			var fish_size = bite_fish.max_size * 18.0
			# Chỉ vẽ hiệu ứng hào quang theo độ hiếm
			var rarity_col = FishDatabase.get_rarity_color(bite_fish.rarity)
			if bite_fish.rarity in ["rare", "epic", "legendary"]:
				for r in range(3):
					draw_circle(biting_fish_pos, fish_size * (1.5 + float(r) * 0.3), Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.08))
	
	# === SPLASHES ===
	for s in splashes:
		draw_circle(Vector2(s["x"], s["y"]), s["size"], Color(0.8, 0.9, 1.0, s["alpha"]))
	
	# === SPARKLES ===
	for sp in sparkles:
		var pulse = 0.5 + 0.5 * sin(wave_time * 8.0 + sp["phase"])
		draw_circle(Vector2(sp["x"], sp["y"]), sp["size"] * pulse, Color(sp["color"].r, sp["color"].g, sp["color"].b, sp["alpha"]))
	
	# === CASTING POWER BAR ===
	if state == FishingState.CASTING:
		_draw_power_bar()
	
	# === BITE ALERT ===
	if state == FishingState.FISH_BITE:
		_draw_bite_alert()
	
	# === MINIGAME UI ===
	if state == FishingState.MINIGAME:
		_draw_minigame_ui()
	
	# === ESCAPED MESSAGE ===
	if state == FishingState.ESCAPED:
		_draw_escaped_message()
	
	# === STATE HUD ===
	_draw_fishing_hud()

	# === HOOK QUALITY TEXT ===
	if hook_quality_timer > 0.0 and hook_quality != "none":
		var font = ThemeDB.fallback_font
		var text = ""
		var col = Color(1, 1, 1, 0.9)
		match hook_quality:
			"perfect":
				text = "PERFECT HOOK!"
				col = Color(1.0, 0.9, 0.2, 0.95)
			"good":
				text = "GOOD HOOK!"
				col = Color(0.4, 1.0, 0.6, 0.95)
			"late":
				text = "LATE HOOK!"
				col = Color(1.0, 0.5, 0.3, 0.95)
		var tsize = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
		var pos = Vector2(960 - tsize.x / 2.0, 220)
		draw_rect(Rect2(pos.x - 20, pos.y - 35, tsize.x + 40, 50), Color(0, 0, 0, 0.35))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, col)

	if hook_shake_time > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fishing_line() -> void:
	var line_color = Color(0.85, 0.85, 0.85, 0.7)
	var is_struggling = (state == FishingState.FISH_BITE or state == FishingState.MINIGAME)
	var time_msec = Time.get_ticks_msec() * 0.001
	
	# === ĐIỂM MỚI: TÍNH TỌA ĐỘ LƯỠI CÂU VÀ GÓC LẮC ===
	var target_hook_pos = hook_pos
	var hook_angle = 0.0
	
	if is_struggling:
		# Gắn chặt lưỡi câu vào miệng cá (vị trí giãy)
		target_hook_pos = biting_fish_pos
		# Lưỡi câu bị cá giật nên quay loạn xạ (phụ thuộc độ căng dây)
		var shake_intensity = 0.5 + (tension * 2.0 if state == FishingState.MINIGAME else 0.0)
		hook_angle = sin(time_msec * 30.0) * shake_intensity
	
	# === 1. TÍNH TOÁN ĐỘ RUNG CHO DÂY TRÊN KHÔNG ===
	var air_shake = Vector2.ZERO
	if is_struggling:
		var shake_power = 2.0
		if state == FishingState.MINIGAME:
			shake_power = 1.0 + tension * 5.0 
		air_shake = Vector2(randf_range(-shake_power, shake_power), randf_range(-shake_power, shake_power))
	
	# === 2. VẼ DÂY TRÊN KHÔNG (TỪ CẦN TỚI PHAO) ===
	if state == FishingState.BAIT_FLYING:
		draw_line(line_start, bobber_pos, line_color, 1.5)
	else:
		var mid1 = line_start.lerp(bobber_pos, 0.33) + Vector2(0, 15 + sin(wave_time * 2.0) * 3.0) + air_shake
		var mid2 = line_start.lerp(bobber_pos, 0.66) + Vector2(0, 10 + sin(wave_time * 2.0 + 1.0) * 2.0) + air_shake
		
		if state == FishingState.MINIGAME:
			mid1 = line_start.lerp(bobber_pos, 0.33) + air_shake
			mid2 = line_start.lerp(bobber_pos, 0.66) + air_shake
			line_color = Color(1.0, 0.95, 0.9, 0.9) 
			
		draw_line(line_start, mid1, line_color, 1.0)
		draw_line(mid1, mid2, line_color, 1.0)
		draw_line(mid2, bobber_pos, line_color, 1.0)
	
	# === 3. VẼ DÂY DƯỚI NƯỚC (TỪ PHAO TỚI MỒI) ===
	if state != FishingState.BAIT_FLYING:
		var under_color = Color(0.7, 0.7, 0.7, 0.4)
		if is_struggling:
			var segments = 5
			var prev_pt = bobber_pos
			var line_thickness = 1.0 + (tension * 1.5 if state == FishingState.MINIGAME else 0.0) 
			
			for i in range(1, segments + 1):
				var t = float(i) / segments
				# ĐIỂM MỚI: Nối dây vào target_hook_pos (miệng cá) thay vì hook_pos
				var base_pt = bobber_pos.lerp(target_hook_pos, t) 
				
				var offset = Vector2.ZERO
				if i < segments: 
					var wave = sin(time_msec * 35.0 + t * 15.0) * 6.0 
					var rand_shake = randf_range(-4.0, 4.0)
					if state == FishingState.MINIGAME:
						wave *= (0.5 + tension)
						rand_shake *= (0.5 + tension)
					offset = Vector2(wave + rand_shake, 0) 
					
				var next_pt = base_pt + offset
				draw_line(prev_pt, next_pt, under_color, line_thickness)
				prev_pt = next_pt
		else:
			draw_line(bobber_pos, target_hook_pos, under_color, 1.0)
	
	# === 4. VẼ PHAO VÀ MỒI ===
	draw_circle(bobber_pos, 7.0, Color(1.0, 0.25, 0.05))
	draw_circle(bobber_pos, 4.0, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(bobber_pos, 3.0, Color(1.0, 0.3, 0.1, 0.5))
	
	# Gọi hàm vẽ lưỡi câu được truyền thêm góc xoay
	_draw_hook(target_hook_pos, hook_angle)


func _draw_hook(pos: Vector2, angle: float = 0.0) -> void:
	# Hàm tính toán phép xoay Vector2 để lưỡi câu lắc theo miệng cá
	var rot = func(v: Vector2) -> Vector2:
		return Vector2(
			v.x * cos(angle) - v.y * sin(angle),
			v.x * sin(angle) + v.y * cos(angle)
		)
	
	# Lưỡi câu (Cán)
	draw_line(pos, pos + rot.call(Vector2(0, 10)), Color(0.7, 0.7, 0.7), 1.5)
	
	# Lưỡi câu (Móc câu - Vẽ bằng mảng điểm thay vì draw_arc để có thể xoay)
	var arc_pts = PackedVector2Array()
	var start_angle = PI * 0.5
	var end_angle = PI * 1.5
	var arc_points = 10
	var radius = 5.0
	var center = Vector2(5, 10)
	
	for i in range(arc_points + 1):
		var a = lerp(start_angle, end_angle, float(i) / arc_points)
		var pt = center + Vector2(cos(a), sin(a)) * radius
		arc_pts.append(pos + rot.call(pt))
		
	draw_polyline(arc_pts, Color(0.7, 0.7, 0.7), 1.5)
	
	# Mồi
	draw_circle(pos + rot.call(Vector2(5, 15)), 3.0, Color(0.8, 0.4, 0.3, 0.8))
	draw_circle(pos + rot.call(Vector2(3, 13)), 2.0, Color(0.9, 0.5, 0.35, 0.7))

func _draw_fish_body(pos: Vector2, size: float, col: Color, direction: float, tail_amp: float = 1.0) -> void:
	var dir = sign(direction)
	if dir == 0: dir = 1.0
	
	# Body (elliptical)
	var body_pts = PackedVector2Array([
		pos + Vector2(-size * 0.9 * dir, 0),
		pos + Vector2(-size * 0.4 * dir, -size * 0.45),
		pos + Vector2(size * 0.3 * dir, -size * 0.35),
		pos + Vector2(size * 0.9 * dir, -size * 0.08),
		pos + Vector2(size * 0.9 * dir, size * 0.08),
		pos + Vector2(size * 0.3 * dir, size * 0.35),
		pos + Vector2(-size * 0.4 * dir, size * 0.45),
	])
	draw_colored_polygon(body_pts, col)
	
	# Belly (lighter)
	var belly_pts = PackedVector2Array([
		pos + Vector2(-size * 0.6 * dir, size * 0.05),
		pos + Vector2(size * 0.5 * dir, size * 0.05),
		pos + Vector2(size * 0.3 * dir, size * 0.3),
		pos + Vector2(-size * 0.4 * dir, size * 0.35),
	])
	draw_colored_polygon(belly_pts, Color(col.r + 0.15, col.g + 0.15, col.b + 0.1, col.a * 0.7))
	
	# Tail
	var tail_wave = sin(wave_time * 6.0) * size * 0.1 * tail_amp
	var tail_pts = PackedVector2Array([
		pos + Vector2(-size * 0.9 * dir, 0),
		pos + Vector2(-size * 1.35 * dir, -size * 0.4 + tail_wave),
		pos + Vector2(-size * 1.1 * dir, 0),
		pos + Vector2(-size * 1.35 * dir, size * 0.4 + tail_wave),
	])
	draw_colored_polygon(tail_pts, col.darkened(0.15))
	
	# Top fin
	var fin_pts = PackedVector2Array([
		pos + Vector2(-size * 0.1 * dir, -size * 0.35),
		pos + Vector2(size * 0.1 * dir, -size * 0.55),
		pos + Vector2(size * 0.35 * dir, -size * 0.3),
	])
	draw_colored_polygon(fin_pts, col.lightened(0.1))
	
	# Eye
	var eye_pos = pos + Vector2(size * 0.55 * dir, -size * 0.1)
	draw_circle(eye_pos, size * 0.12, Color(1, 1, 1, col.a))
	draw_circle(eye_pos + Vector2(size * 0.02 * dir, 0), size * 0.06, Color(0.1, 0.1, 0.1, col.a))
	
	# Mouth
	var mouth_x = pos.x + size * 0.85 * dir
	draw_line(Vector2(mouth_x, pos.y - size * 0.02), Vector2(mouth_x - size * 0.1 * dir, pos.y + size * 0.05), Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, col.a), 1.0)


func _draw_power_bar() -> void:
	var bar_x = 860.0
	var bar_y = 900.0
	var bar_w = 200.0
	var bar_h = 22.0
	
	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.2, 0.8))
	var power_color = Color(0.2, 0.8, 0.3).lerp(Color(1.0, 0.3, 0.1), cast_power)
	draw_rect(Rect2(bar_x, bar_y, bar_w * cast_power, bar_h), power_color)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 1.5)
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(bar_x, bar_y - 10), "Giu SPACE de nap luc...", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))


func _draw_bite_alert() -> void:
	var font = ThemeDB.fallback_font
	var alert_alpha = 0.5 + 0.5 * sin(bite_alert_timer * 10.0)
	
	var ex_pos = bobber_pos + Vector2(-15, -50)
	draw_string(font, ex_pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1.0, 0.2, 0.1, alert_alpha))
	
	var text = "CA CAN MOI! Nhan chuot trai!"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	var text_pos = Vector2(960 - text_size.x / 2.0, 450)
	draw_rect(Rect2(text_pos.x - 15, text_pos.y - 28, text_size.x + 30, 42), Color(0, 0, 0, 0.6 * alert_alpha))
	draw_rect(Rect2(text_pos.x - 15, text_pos.y - 28, text_size.x + 30, 42), Color(1.0, 0.5, 0.1, 0.4 * alert_alpha), false, 2.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.9, 0.2, alert_alpha))


func _draw_minigame_ui() -> void:
	var font = ThemeDB.fallback_font
	var bar_x = 1720.0
	var bar_y = 180.0
	var bar_w = 45.0
	var bar_h = 520.0
	
	draw_rect(Rect2(bar_x - 3, bar_y - 3, bar_w + 6, bar_h + 6), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.15, 0.85))
	
	var zone_y = bar_y + (1.0 - sweet_zone_pos - sweet_zone_size / 2.0) * bar_h
	var zone_h = sweet_zone_size * bar_h
	draw_rect(Rect2(bar_x, zone_y, bar_w, zone_h), Color(0.15, 0.55, 0.2, 0.6))
	draw_rect(Rect2(bar_x, zone_y, bar_w, zone_h), Color(0.2, 0.8, 0.3, 0.3), false, 1.5)
	
	var tension_y = bar_y + (1.0 - tension) * bar_h
	var in_zone = abs(tension - sweet_zone_pos) < sweet_zone_size / 2.0
	var ind_col = Color(0.2, 1.0, 0.3) if in_zone else Color(1.0, 0.25, 0.2)
	draw_rect(Rect2(bar_x - 8, tension_y - 6, bar_w + 16, 12), ind_col)
	draw_rect(Rect2(bar_x - 8, tension_y - 6, bar_w + 16, 12), Color(1, 1, 1, 0.4), false, 1.0)
	
	_draw_fish_body(Vector2(bar_x - 20, tension_y), 8.0, ind_col, -1.0)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 2.0)
	
	var prog_x = 560.0
	var prog_y = 870.0
	var prog_w = 800.0
	var prog_h = 28.0
	
	draw_rect(Rect2(prog_x - 2, prog_y - 2, prog_w + 4, prog_h + 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(prog_x, prog_y, prog_w, prog_h), Color(0.1, 0.1, 0.15, 0.85))
	var prog_col = Color(0.15, 0.6, 0.9).lerp(Color(0.2, 1.0, 0.4), catch_progress)
	draw_rect(Rect2(prog_x, prog_y, prog_w * catch_progress, prog_h), prog_col)
	draw_rect(Rect2(prog_x, prog_y, prog_w, prog_h), Color(1, 1, 1, 0.3), false, 1.5)
	
	draw_string(font, Vector2(bar_x - 70, bar_y - 10), "Luc keo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(prog_x, prog_y - 10), "Giu chuot trai de keo ca!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	
	if bite_fish:
		var rarity_color = FishDatabase.get_rarity_color(bite_fish.rarity)
		var fish_text = bite_fish.name_vn + " (" + FishDatabase.get_rarity_name_vn(bite_fish.rarity) + ")"
		draw_string(font, Vector2(prog_x, prog_y + 50), fish_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, rarity_color)


func _draw_escaped_message() -> void:
	var font = ThemeDB.fallback_font
	var alpha = clampf(1.5 - wait_timer, 0.0, 1.0)
	draw_rect(Rect2(720, 420, 480, 50), Color(0, 0, 0, 0.5 * alpha))
	draw_string(font, Vector2(740, 460), "Ca da thoat mat...", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.5, 0.3, alpha))


func _draw_fishing_hud() -> void:
	var font = ThemeDB.fallback_font
	var state_text = ""
	match state:
		FishingState.IDLE: state_text = "Nhan SPACE de tha cau"
		FishingState.CASTING: state_text = "Dang nap luc..."
		FishingState.BAIT_FLYING: state_text = "Moi dang bay..." # THÊM MỚI CHỖ NÀY
		FishingState.LINE_SINKING: state_text = "Moi dang chim..."
		FishingState.WAITING: state_text = "Dang cho ca can... (E de huy)"
		FishingState.FISH_BITE: state_text = "CA CAN MOI!"
		FishingState.MINIGAME: state_text = "Dang keo ca!"
	
	if state_text != "":
		var bg_rect = Rect2(40, 1030, 400, 30)
		draw_rect(bg_rect, Color(0, 0, 0, 0.4))
		draw_string(font, Vector2(50, 1053), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
		
		
