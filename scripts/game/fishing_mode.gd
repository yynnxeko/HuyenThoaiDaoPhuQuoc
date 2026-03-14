extends Node2D

## Fishing mode — visual, exciting fishing with visible fish, splashes, and animations

signal fishing_ended
signal fish_caught(fish_id: String, size: float)

enum FishingState { IDLE, CASTING, LINE_SINKING, WAITING, FISH_BITE, MINIGAME, CAUGHT, ESCAPED }
var state: FishingState = FishingState.IDLE

# Setup data
var spot_data: Dictionary = {}
var zone_info = null

# Casting
var cast_power: float = 0.0
var cast_charging: bool = false
var cast_max_power: float = 1.0
var cast_speed: float = 1.5

# Line
var line_start: Vector2 = Vector2.ZERO
var hook_pos: Vector2 = Vector2.ZERO
var hook_target_depth: float = 200.0
var line_sink_speed: float = 80.0

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

# Minigame
var tension: float = 0.5
var catch_progress: float = 0.0
var sweet_zone_pos: float = 0.5
var sweet_zone_size: float = 0.25
var fish_pull_timer: float = 0.0
var fish_pull_direction: float = 0.0

# Visual
var wave_time: float = 0.0
var water_line_y: float = 540.0

# Boat reference
var boat_ref: Node2D = null

# === VISUAL FISH ===
var nearby_fish: Array = []  # Fish swimming near the hook
var biting_fish_pos: Vector2 = Vector2.ZERO  # Position of the fish that's biting
var biting_fish_target: Vector2 = Vector2.ZERO
var fish_fight_offset: Vector2 = Vector2.ZERO  # Offset during minigame fight
var caught_fish_anim: float = 0.0  # Animation for caught fish rising

# === PARTICLES ===
var bubbles: Array = []
var splashes: Array = []
var sparkles: Array = []


func setup(spot: Dictionary, zone, boat: Node2D = null) -> void:
	spot_data = spot
	zone_info = zone
	boat_ref = boat
	state = FishingState.IDLE
	if boat_ref:
		var rod_tip_offset = Vector2(100, -65) if boat_ref.facing_right else Vector2(-100, -65)
		line_start = boat_ref.position + rod_tip_offset
	else:
		line_start = Vector2(960, water_line_y - 60)
	hook_pos = line_start
	_spawn_nearby_fish()


func _ready() -> void:
	_calculate_bite_time()


func _spawn_nearby_fish() -> void:
	nearby_fish.clear()
	for i in range(randi_range(4, 8)):
		var fish_x = randf_range(300, 1600)
		var fish_y = randf_range(water_line_y + 60, 900)
		nearby_fish.append({
			"x": fish_x,
			"y": fish_y,
			"base_y": fish_y,
			"speed": randf_range(30, 80),
			"dir": [-1.0, 1.0][randi() % 2],
			"size": randf_range(10, 22),
			"color": Color(randf_range(0.3, 0.7), randf_range(0.5, 0.8), randf_range(0.6, 0.9), 0.5),
			"wave_phase": randf() * TAU,
			"interested": false,
			"flee": false,
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
	
	# Update line_start from boat
	if boat_ref:
		var rod_tip_offset = Vector2(100, -65) if boat_ref.facing_right else Vector2(-100, -65)
		line_start = boat_ref.position + rod_tip_offset
	
	match state:
		FishingState.IDLE:
			_process_idle(delta)
		FishingState.CASTING:
			_process_casting(delta)
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
	
	# Update nearby fish
	_update_nearby_fish(delta)
	# Update particles
	_update_particles(delta)
	
	queue_redraw()


func _process_idle(_delta: float) -> void:
	if Input.is_action_just_pressed("cast_line"):
		state = FishingState.CASTING
		cast_power = 0.0
		cast_charging = true


func _process_casting(delta: float) -> void:
	if cast_charging:
		cast_power = clampf(cast_power + cast_speed * delta, 0.0, cast_max_power)
		if Input.is_action_just_released("cast_line"):
			cast_charging = false
			hook_target_depth = water_line_y + 50.0 + cast_power * 300.0
			var cast_dir = 1.0 if (boat_ref and boat_ref.facing_right) else 1.0
			bobber_pos = Vector2(line_start.x + cast_power * 200.0 * cast_dir, water_line_y)
			hook_pos = bobber_pos
			_spawn_splash(bobber_pos, 8)
			AudioManager.play_cast()
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


func _process_waiting(delta: float) -> void:
	wait_timer += delta
	bobber_bob_time += delta
	bobber_pos.y = water_line_y + sin(bobber_bob_time * 2.0) * 3.0
	
	# Make some fish interested in the bait over time
	var interest_progress = clampf(wait_timer / bite_time, 0.0, 1.0)
	for fish in nearby_fish:
		if interest_progress > 0.4 and randf() < 0.002:
			fish["interested"] = true
	
	if wait_timer >= bite_time:
		if bite_fish != null:
			state = FishingState.FISH_BITE
			bite_alert_timer = 0.0
			AudioManager.play_bite_alert()
			# Position the biting fish
			biting_fish_pos = Vector2(hook_pos.x + randf_range(-150, 150), hook_pos.y + randf_range(-30, 30))
			biting_fish_target = hook_pos
			_spawn_bubble(hook_pos, 5)
		else:
			_calculate_bite_time()
			wait_timer = 0.0
	
	if Input.is_action_just_pressed("interact"):
		_end_fishing()


func _process_bite(delta: float) -> void:
	bite_alert_timer += delta
	
	# Fish rushes toward hook!
	biting_fish_pos = biting_fish_pos.lerp(biting_fish_target, delta * 3.0)
	
	# Vigorous bobber movement
	bobber_pos.y = water_line_y + sin(bite_alert_timer * 15.0) * 10.0
	
	# Bubbles from fish activity
	if randi() % 3 == 0:
		_spawn_bubble(hook_pos, 2)
	
	# Splash at bobber
	if int(bite_alert_timer * 10) % 3 == 0:
		_spawn_splash(bobber_pos, 2)
	
	if Input.is_action_just_pressed("reel_in") or Input.is_action_just_pressed("cast_line"):
		# Legendary fish = boss encounter!
		if bite_fish and bite_fish.rarity == "legendary":
			_launch_boss_encounter()
			return
		state = FishingState.MINIGAME
		tension = 0.5
		catch_progress = 0.0
		_setup_minigame_difficulty()
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
		return
	
	# Fish pulls randomly
	fish_pull_timer += delta
	if fish_pull_timer >= 0.3 + randf() * 0.5:
		fish_pull_timer = 0.0
		fish_pull_direction = randf_range(-1.0, 1.0) * bite_fish.fight_difficulty
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
		tension += delta * GameData.get_rod_reel_speed() * 0.8
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
		catch_progress += delta * 0.4 * GameData.get_rod_reel_speed()
		# Hook moves up toward surface as progress increases
		hook_pos.y = lerp(hook_target_depth, water_line_y + 20.0, catch_progress)
	else:
		catch_progress -= delta * 0.15
		# Fish pulls hook deeper
		hook_pos.y = move_toward(hook_pos.y, hook_target_depth, 20.0 * delta)
	catch_progress = clampf(catch_progress, 0.0, 1.0)
	
	# Fish position follows hook during fight
	biting_fish_pos = hook_pos + fish_fight_offset
	
	# Line break
	if tension >= 0.98:
		if randf() > GameData.get_line_strength() * 0.4:
			_spawn_splash(bobber_pos, 12)
			AudioManager.play_line_snap()
			state = FishingState.ESCAPED
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
			continue
		
		if fish["interested"] and state == FishingState.WAITING:
			# Swim toward hook
			var dir_to_hook = hook_pos.x - fish["x"]
			fish["x"] += sign(dir_to_hook) * fish["speed"] * 0.5 * delta
			fish["y"] = lerp(fish["y"], hook_pos.y + randf_range(-20, 20), delta * 0.5)
		else:
			# Normal swimming
			fish["x"] += fish["speed"] * fish["dir"] * delta
			fish["y"] = fish["base_y"] + sin(wave_time * 1.5 + fish["wave_phase"]) * 12.0
		
		# Wrap
		if fish["x"] > 2000:
			fish["x"] = -50.0
			fish["dir"] = 1.0
		elif fish["x"] < -50:
			fish["x"] = 2000.0
			fish["dir"] = -1.0


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
	for fish in available_fish:
		total_weight += FishDatabase.get_spawn_weight(fish.rarity) * GameData.get_bait_attract()
	
	var roll = randf() * total_weight
	var accumulated = 0.0
	bite_fish = available_fish[0]
	for fish in available_fish:
		accumulated += FishDatabase.get_spawn_weight(fish.rarity) * GameData.get_bait_attract()
		if roll <= accumulated:
			bite_fish = fish
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


func _end_fishing() -> void:
	fishing_ended.emit()


func _input(event: InputEvent) -> void:
	if state == FishingState.IDLE or state == FishingState.WAITING:
		if event.is_action_pressed("interact"):
			_end_fishing()


# ===================== DRAWING =====================

func _draw() -> void:
	var sw = 1920.0
	var sh = 1080.0
	
	# Subtle dark overlay
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.1))
	
	# === UNDERWATER NEARBY FISH ===
	for fish in nearby_fish:
		if fish["y"] > water_line_y:
			_draw_fish_body(Vector2(fish["x"], fish["y"]), fish["size"], fish["color"], fish["dir"])
	
	# === BUBBLES ===
	for b in bubbles:
		draw_circle(Vector2(b["x"], b["y"]), b["size"], Color(0.7, 0.85, 1.0, b["alpha"] * 0.6))
		draw_circle(Vector2(b["x"], b["y"]), b["size"] * 0.6, Color(1.0, 1.0, 1.0, b["alpha"] * 0.3))
	
	# === FISHING LINE ===
	if state != FishingState.IDLE:
		_draw_fishing_line()
	
	# === BITING / FIGHTING FISH ===
	if state == FishingState.FISH_BITE or state == FishingState.MINIGAME:
		if bite_fish:
			var fish_size = bite_fish.max_size * 18.0
			var fish_col = bite_fish.color
			fish_col.a = 0.85
			_draw_fish_body(biting_fish_pos, fish_size, fish_col, -1.0 if biting_fish_pos.x > hook_pos.x else 1.0)
			# Rarity glow
			var rarity_col = FishDatabase.get_rarity_color(bite_fish.rarity)
			if bite_fish.rarity in ["rare", "epic", "legendary"]:
				for r in range(3):
					draw_circle(biting_fish_pos, fish_size * (1.5 + float(r) * 0.3), Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.06))
	
	# === CAUGHT FISH (rising out of water) ===
	if state == FishingState.CAUGHT and bite_fish:
		var fish_size = bite_fish.max_size * 20.0
		_draw_fish_body(biting_fish_pos, fish_size, bite_fish.color, 1.0)
		# Victory glow
		var rarity_col = FishDatabase.get_rarity_color(bite_fish.rarity)
		for r in range(5):
			draw_circle(biting_fish_pos, fish_size * (1.2 + float(r) * 0.4), Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.04))
	
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
	
	# === CAUGHT MESSAGE ===
	if state == FishingState.CAUGHT:
		_draw_caught_message()
	
	# === ESCAPED MESSAGE ===
	if state == FishingState.ESCAPED:
		_draw_escaped_message()
	
	# === STATE HUD ===
	_draw_fishing_hud()


func _draw_fishing_line() -> void:
	# Line: rod tip → bobber (above water)
	var line_color = Color(0.85, 0.85, 0.85, 0.7)
	
	# Curved line using multiple segments
	var mid1 = line_start.lerp(bobber_pos, 0.33) + Vector2(0, 15 + sin(wave_time * 2.0) * 3.0)
	var mid2 = line_start.lerp(bobber_pos, 0.66) + Vector2(0, 10 + sin(wave_time * 2.0 + 1.0) * 2.0)
	draw_line(line_start, mid1, line_color, 1.0)
	draw_line(mid1, mid2, line_color, 1.0)
	draw_line(mid2, bobber_pos, line_color, 1.0)
	
	# Bobber → hook (underwater)
	draw_line(bobber_pos, hook_pos, Color(0.7, 0.7, 0.7, 0.4), 1.0)
	
	# Bobber
	draw_circle(bobber_pos, 7.0, Color(1.0, 0.25, 0.05))
	draw_circle(bobber_pos, 4.0, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(bobber_pos, 3.0, Color(1.0, 0.3, 0.1, 0.5))
	
	# Hook with bait
	_draw_hook(hook_pos)


func _draw_hook(pos: Vector2) -> void:
	# Hook
	draw_line(pos, pos + Vector2(0, 10), Color(0.7, 0.7, 0.7), 1.5)
	draw_arc(pos + Vector2(5, 10), 5.0, PI * 0.5, PI * 1.5, 10, Color(0.7, 0.7, 0.7), 1.5)
	# Bait (small worm-like shape)
	draw_circle(pos + Vector2(5, 15), 3.0, Color(0.8, 0.4, 0.3, 0.8))
	draw_circle(pos + Vector2(3, 13), 2.0, Color(0.9, 0.5, 0.35, 0.7))


func _draw_fish_body(pos: Vector2, size: float, col: Color, direction: float) -> void:
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
	var tail_wave = sin(wave_time * 6.0) * size * 0.1
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
	
	# Exclamation mark above bobber
	var ex_pos = bobber_pos + Vector2(-15, -50)
	draw_string(font, ex_pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1.0, 0.2, 0.1, alert_alpha))
	
	# Alert text
	var text = "CA CAN MOI! Nhan chuot trai!"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	var text_pos = Vector2(960 - text_size.x / 2.0, 450)
	draw_rect(Rect2(text_pos.x - 15, text_pos.y - 28, text_size.x + 30, 42), Color(0, 0, 0, 0.6 * alert_alpha))
	draw_rect(Rect2(text_pos.x - 15, text_pos.y - 28, text_size.x + 30, 42), Color(1.0, 0.5, 0.1, 0.4 * alert_alpha), false, 2.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.9, 0.2, alert_alpha))


func _draw_minigame_ui() -> void:
	var font = ThemeDB.fallback_font
	
	# === TENSION BAR (vertical, right side) ===
	var bar_x = 1720.0
	var bar_y = 180.0
	var bar_w = 45.0
	var bar_h = 520.0
	
	# Background with glow
	draw_rect(Rect2(bar_x - 3, bar_y - 3, bar_w + 6, bar_h + 6), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.15, 0.85))
	
	# Sweet zone (green area)
	var zone_y = bar_y + (1.0 - sweet_zone_pos - sweet_zone_size / 2.0) * bar_h
	var zone_h = sweet_zone_size * bar_h
	draw_rect(Rect2(bar_x, zone_y, bar_w, zone_h), Color(0.15, 0.55, 0.2, 0.6))
	draw_rect(Rect2(bar_x, zone_y, bar_w, zone_h), Color(0.2, 0.8, 0.3, 0.3), false, 1.5)
	
	# Tension indicator (marker)
	var tension_y = bar_y + (1.0 - tension) * bar_h
	var in_zone = abs(tension - sweet_zone_pos) < sweet_zone_size / 2.0
	var ind_col = Color(0.2, 1.0, 0.3) if in_zone else Color(1.0, 0.25, 0.2)
	draw_rect(Rect2(bar_x - 8, tension_y - 6, bar_w + 16, 12), ind_col)
	draw_rect(Rect2(bar_x - 8, tension_y - 6, bar_w + 16, 12), Color(1, 1, 1, 0.4), false, 1.0)
	
	# Fish icon on the marker
	_draw_fish_body(Vector2(bar_x - 20, tension_y), 8.0, ind_col, -1.0)
	
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 2.0)
	
	# === PROGRESS BAR (bottom) ===
	var prog_x = 560.0
	var prog_y = 870.0
	var prog_w = 800.0
	var prog_h = 28.0
	
	draw_rect(Rect2(prog_x - 2, prog_y - 2, prog_w + 4, prog_h + 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(prog_x, prog_y, prog_w, prog_h), Color(0.1, 0.1, 0.15, 0.85))
	# Progress fill with gradient
	var prog_col = Color(0.15, 0.6, 0.9).lerp(Color(0.2, 1.0, 0.4), catch_progress)
	draw_rect(Rect2(prog_x, prog_y, prog_w * catch_progress, prog_h), prog_col)
	draw_rect(Rect2(prog_x, prog_y, prog_w, prog_h), Color(1, 1, 1, 0.3), false, 1.5)
	
	# Labels
	draw_string(font, Vector2(bar_x - 70, bar_y - 10), "Luc keo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(prog_x, prog_y - 10), "Giu chuot trai de keo ca!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	
	# Fish name with rarity color
	if bite_fish:
		var rarity_color = FishDatabase.get_rarity_color(bite_fish.rarity)
		var fish_text = bite_fish.name_vn + " (" + FishDatabase.get_rarity_name_vn(bite_fish.rarity) + ")"
		draw_string(font, Vector2(prog_x, prog_y + 50), fish_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, rarity_color)


func _draw_caught_message() -> void:
	var font = ThemeDB.fallback_font
	var popup_alpha = clampf(caught_fish_anim / 0.5, 0.0, 1.0)
	
	draw_rect(Rect2(660, 350, 600, 140), Color(0, 0, 0, 0.7 * popup_alpha))
	draw_rect(Rect2(660, 350, 600, 140), Color(0.3, 0.9, 0.3, 0.5 * popup_alpha), false, 3.0)
	draw_string(font, Vector2(720, 400), "BAT DUOC CA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.3, 1.0, 0.4, popup_alpha))


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
		FishingState.LINE_SINKING: state_text = "Moi dang chim..."
		FishingState.WAITING: state_text = "Dang cho ca can... (E de huy)"
		FishingState.FISH_BITE: state_text = "CA CAN MOI!"
		FishingState.MINIGAME: state_text = "Dang keo ca!"
	
	if state_text != "":
		var bg_rect = Rect2(40, 1030, 400, 30)
		draw_rect(bg_rect, Color(0, 0, 0, 0.4))
		draw_string(font, Vector2(50, 1053), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
