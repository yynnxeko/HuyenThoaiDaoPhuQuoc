extends Node2D

## Boss encounter — special legendary fish battle with phases
## Triggered when legendary fish is hooked during storms/full moon

signal boss_defeated(fish_id: String, size: float)
signal boss_escaped

enum BossPhase { APPEAR, PHASE_1, PHASE_2, PHASE_3, VICTORY, FAILED }
var phase: BossPhase = BossPhase.APPEAR

# Boss data
var boss_fish = null  # FishType
var boss_health: float = 1.0  # 1.0 = full, 0.0 = caught
var boss_rage: float = 0.0   # Builds up, causes harder pulls
var boss_size: float = 40.0  # Visual size

# Fight mechanics
var tension: float = 0.5
var sweet_zone_pos: float = 0.5
var sweet_zone_size: float = 0.2
var fish_pull_timer: float = 0.0
var fish_pull_strength: float = 0.0

# Boss position and animation
var boss_pos: Vector2 = Vector2(960, 650)
var boss_target: Vector2 = Vector2(960, 650)
var boss_shake: Vector2 = Vector2.ZERO
var charge_timer: float = 0.0
var charge_direction: float = 0.0

# Visual effects
var wave_time: float = 0.0
var appear_timer: float = 0.0
var screen_shake: float = 0.0
var phase_flash: float = 0.0
var particles: Array = []
var water_disturbance: Array = []

# Boat reference
var boat_ref: Node2D = null
var line_start: Vector2 = Vector2(960, 480)
var water_line_y: float = 540.0


func setup_boss(fish, boat: Node2D = null) -> void:
	boss_fish = fish
	boat_ref = boat
	phase = BossPhase.APPEAR
	appear_timer = 0.0
	boss_health = 1.0
	boss_rage = 0.0
	boss_size = fish.max_size * 6.0
	boss_pos = Vector2(960, 750)
	
	if boat_ref:
		var tip = Vector2(100, -65) if boat_ref.facing_right else Vector2(-100, -65)
		line_start = boat_ref.position + tip
	
	AudioManager.play_boss_appear()
	
	# Create initial disturbance
	for i in range(10):
		_spawn_water_disturbance(Vector2(randf_range(400, 1500), water_line_y))


func _process(delta: float) -> void:
	wave_time += delta
	
	if boat_ref:
		var tip = Vector2(100, -65) if boat_ref.facing_right else Vector2(-100, -65)
		line_start = boat_ref.position + tip
	
	# Screen shake decay
	screen_shake *= 0.92
	phase_flash = max(0, phase_flash - delta * 3.0)
	
	match phase:
		BossPhase.APPEAR:
			_process_appear(delta)
		BossPhase.PHASE_1:
			_process_fight(delta, 1)
		BossPhase.PHASE_2:
			_process_fight(delta, 2)
		BossPhase.PHASE_3:
			_process_fight(delta, 3)
		BossPhase.VICTORY:
			_process_victory(delta)
		BossPhase.FAILED:
			_process_failed(delta)
	
	_update_particles(delta)
	queue_redraw()


func _process_appear(delta: float) -> void:
	appear_timer += delta
	# Boss rises from deep
	boss_pos.y = lerp(900.0, 650.0, clampf(appear_timer / 2.5, 0.0, 1.0))
	boss_shake = Vector2(sin(appear_timer * 20) * 3, sin(appear_timer * 15) * 2)
	screen_shake = 3.0
	
	# Spawn bubbles / disturbance
	if randi() % 3 == 0:
		_spawn_boss_particle(boss_pos + Vector2(randf_range(-50, 50), randf_range(-30, 30)))
	if randi() % 5 == 0:
		_spawn_water_disturbance(Vector2(boss_pos.x + randf_range(-100, 100), water_line_y))
	
	if appear_timer >= 3.0:
		phase = BossPhase.PHASE_1
		tension = 0.5
		sweet_zone_pos = 0.5
		AudioManager.play_boss_phase()
		phase_flash = 1.0


func _process_fight(delta: float, phase_num: int) -> void:
	var difficulty = 0.6 + float(phase_num) * 0.15 + boss_rage * 0.1
	sweet_zone_size = max(0.08, 0.22 - float(phase_num) * 0.04)
	
	# Fish pulls
	fish_pull_timer += delta
	var pull_interval = max(0.15, 0.5 - float(phase_num) * 0.1)
	if fish_pull_timer >= pull_interval:
		fish_pull_timer = 0.0
		fish_pull_strength = randf_range(-1.0, 1.0) * difficulty
		boss_shake = Vector2(randf_range(-8, 8), randf_range(-5, 5))
		if randi() % 3 == 0:
			_spawn_boss_particle(boss_pos)
	
	# Boss charges in phase 2+
	if phase_num >= 2:
		charge_timer += delta
		if charge_timer > 3.0 + randf() * 2.0:
			charge_timer = 0.0
			charge_direction = [-1.0, 1.0][randi() % 2]
			boss_target.x = clampf(boss_pos.x + charge_direction * 250.0, 300, 1600)
			screen_shake = 5.0
			AudioManager.play_splash(1.5)
			_spawn_water_disturbance(Vector2(boss_pos.x, water_line_y))
	
	# Boss movement
	sweet_zone_pos += fish_pull_strength * delta * 0.7
	sweet_zone_pos = clampf(sweet_zone_pos, sweet_zone_size / 2.0, 1.0 - sweet_zone_size / 2.0)
	
	boss_pos = boss_pos.lerp(boss_target, delta * 1.5)
	boss_shake = boss_shake.lerp(Vector2.ZERO, delta * 3.0)
	
	# Player reels
	if Input.is_action_pressed("reel_in"):
		tension += delta * GameData.get_rod_reel_speed() * 0.6
		if randi() % 8 == 0:
			AudioManager.play_reel_tick()
	else:
		tension -= delta * (0.3 + float(phase_num) * 0.1)
	tension = clampf(tension, 0.0, 1.0)
	
	var in_zone = abs(tension - sweet_zone_pos) < sweet_zone_size / 2.0
	if in_zone:
		boss_health -= delta * 0.08 * GameData.get_rod_reel_speed()
		boss_rage = max(0, boss_rage - delta * 0.1)
		boss_pos.y = lerp(boss_pos.y, water_line_y + 50.0, delta * 0.3)
	else:
		boss_health = min(1.0, boss_health + delta * 0.02)
		boss_rage = min(1.0, boss_rage + delta * 0.05)
		boss_pos.y = lerp(boss_pos.y, 750.0, delta * 0.2)
	
	# Line break
	if tension >= 0.99:
		if randf() > GameData.get_line_strength() * 0.3:
			phase = BossPhase.FAILED
			AudioManager.play_line_snap()
			screen_shake = 8.0
			return
	
	# Phase transitions
	if boss_health <= 0.66 and phase_num == 1:
		phase = BossPhase.PHASE_2
		phase_flash = 1.0
		AudioManager.play_boss_phase()
		screen_shake = 5.0
		boss_target = Vector2(boss_pos.x + 200 * charge_direction, 680)
	elif boss_health <= 0.33 and phase_num == 2:
		phase = BossPhase.PHASE_3
		phase_flash = 1.0
		AudioManager.play_boss_phase()
		screen_shake = 7.0
		boss_target = Vector2(960, 620)
	
	# Victory!
	if boss_health <= 0.0:
		phase = BossPhase.VICTORY
		appear_timer = 0.0
		AudioManager.play_catch_legendary()
		screen_shake = 10.0
		for i in range(20):
			_spawn_boss_particle(boss_pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
	
	# Total failure
	if tension <= 0.01 and boss_rage >= 0.8:
		phase = BossPhase.FAILED
		AudioManager.play_fish_escape()


func _process_victory(delta: float) -> void:
	appear_timer += delta
	boss_pos.y = lerp(boss_pos.y, water_line_y - 80, delta * 2.0)
	
	if appear_timer < 0.1 and boss_fish:
		var size = randf_range(boss_fish.min_size, boss_fish.max_size)
		boss_defeated.emit(boss_fish.id, size)
	
	if appear_timer >= 3.0:
		queue_free()


func _process_failed(delta: float) -> void:
	appear_timer += delta
	boss_pos.y += 80.0 * delta
	boss_pos.x += 100.0 * delta
	
	if appear_timer < 0.1:
		boss_escaped.emit()
	
	if appear_timer >= 2.0:
		queue_free()


func _spawn_boss_particle(pos: Vector2) -> void:
	particles.append({
		"x": pos.x, "y": pos.y,
		"vx": randf_range(-40, 40),
		"vy": randf_range(-60, -20),
		"size": randf_range(3, 8),
		"alpha": 0.8,
		"color": FishDatabase.get_rarity_color(boss_fish.rarity) if boss_fish else Color.GOLD,
	})


func _spawn_water_disturbance(pos: Vector2) -> void:
	water_disturbance.append({
		"x": pos.x, "y": pos.y,
		"radius": 5.0,
		"max_radius": randf_range(30, 80),
		"alpha": 0.6,
	})


func _update_particles(delta: float) -> void:
	var i = particles.size() - 1
	while i >= 0:
		var p = particles[i]
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["alpha"] -= delta * 0.8
		if p["alpha"] <= 0:
			particles.remove_at(i)
		i -= 1
	
	i = water_disturbance.size() - 1
	while i >= 0:
		var w = water_disturbance[i]
		w["radius"] = min(w["radius"] + 60.0 * delta, w["max_radius"])
		w["alpha"] -= delta * 0.5
		if w["alpha"] <= 0:
			water_disturbance.remove_at(i)
		i -= 1


# ===================== DRAWING =====================

func _draw() -> void:
	var sw = 1920.0
	var sh = 1080.0
	var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake
	
	# Dark atmosphere overlay
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0.05, 0.3))
	
	# Phase flash
	if phase_flash > 0:
		draw_rect(Rect2(0, 0, sw, sh), Color(1, 1, 1, phase_flash * 0.3))
	
	# Water disturbance rings
	for w in water_disturbance:
		draw_arc(Vector2(w["x"], w["y"]) + shake_offset, w["radius"], 0, TAU, 24, Color(0.5, 0.7, 0.9, w["alpha"] * 0.3), 2.0)
	
	# Fishing line to boss
	if phase != BossPhase.APPEAR and phase != BossPhase.FAILED:
		draw_line(line_start + shake_offset, boss_pos + boss_shake + shake_offset, Color(0.8, 0.8, 0.8, 0.7), 1.5)
	
	# === DRAW BOSS ===
	_draw_boss(shake_offset)
	
	# Particles
	for p in particles:
		draw_circle(Vector2(p["x"], p["y"]) + shake_offset, p["size"], Color(p["color"].r, p["color"].g, p["color"].b, p["alpha"]))
	
	# === UI ===
	if phase in [BossPhase.PHASE_1, BossPhase.PHASE_2, BossPhase.PHASE_3]:
		_draw_boss_ui()
	
	if phase == BossPhase.APPEAR:
		_draw_appear_ui()
	
	if phase == BossPhase.VICTORY:
		_draw_victory_ui()
	
	if phase == BossPhase.FAILED:
		_draw_failed_ui()


func _draw_boss(offset: Vector2) -> void:
	if boss_fish == null:
		return
	var pos = boss_pos + boss_shake + offset
	var s = boss_size
	var col = boss_fish.color
	var rarity_col = FishDatabase.get_rarity_color(boss_fish.rarity)
	
	# Aura glow
	var pulse = 0.5 + 0.5 * sin(wave_time * 3.0)
	for r in range(8):
		var glow_size = s * (1.5 + float(r) * 0.3) * (0.8 + pulse * 0.2)
		draw_circle(pos, glow_size, Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.015 * (8 - r)))
	
	# Body
	var dir = 1.0
	var body_pts = PackedVector2Array([
		pos + Vector2(-s * 1.0 * dir, 0),
		pos + Vector2(-s * 0.5 * dir, -s * 0.5),
		pos + Vector2(s * 0.3 * dir, -s * 0.4),
		pos + Vector2(s * 1.0 * dir, -s * 0.1),
		pos + Vector2(s * 1.0 * dir, s * 0.1),
		pos + Vector2(s * 0.3 * dir, s * 0.4),
		pos + Vector2(-s * 0.5 * dir, s * 0.5),
	])
	draw_colored_polygon(body_pts, col)
	
	# Belly
	var belly_pts = PackedVector2Array([
		pos + Vector2(-s * 0.7 * dir, s * 0.05),
		pos + Vector2(s * 0.6 * dir, s * 0.05),
		pos + Vector2(s * 0.3 * dir, s * 0.35),
		pos + Vector2(-s * 0.5 * dir, s * 0.4),
	])
	draw_colored_polygon(belly_pts, Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, 0.7))
	
	# Tail with wave
	var tail_wave = sin(wave_time * 5.0) * s * 0.15
	var tail_pts = PackedVector2Array([
		pos + Vector2(-s * 1.0, 0),
		pos + Vector2(-s * 1.5, -s * 0.5 + tail_wave),
		pos + Vector2(-s * 1.2, 0),
		pos + Vector2(-s * 1.5, s * 0.5 + tail_wave),
	])
	draw_colored_polygon(tail_pts, col.darkened(0.2))
	
	# Dorsal fin
	var fin_pts = PackedVector2Array([
		pos + Vector2(-s * 0.2, -s * 0.4),
		pos + Vector2(s * 0.1, -s * 0.7),
		pos + Vector2(s * 0.4, -s * 0.35),
	])
	draw_colored_polygon(fin_pts, col.lightened(0.1))
	
	# Eye (larger, menacing)
	var eye_pos = pos + Vector2(s * 0.6, -s * 0.12)
	draw_circle(eye_pos, s * 0.15, Color(1, 1, 1, 0.95))
	draw_circle(eye_pos + Vector2(s * 0.03, 0), s * 0.08, Color(0.9, 0.15, 0.1))
	draw_circle(eye_pos + Vector2(s * 0.04, 0), s * 0.04, Color(0.1, 0.05, 0.05))
	
	# Rage effect: red glow around boss
	if boss_rage > 0.3:
		var rage_alpha = (boss_rage - 0.3) * 0.3
		for r in range(4):
			draw_circle(pos, s * (1.2 + float(r) * 0.2), Color(1, 0.1, 0.05, rage_alpha * 0.05))


func _draw_boss_ui() -> void:
	var font = ThemeDB.fallback_font
	
	# Boss name + health bar
	var bar_w = 600.0
	var bar_x = 660.0
	var bar_y = 60.0
	
	draw_rect(Rect2(bar_x - 5, bar_y - 30, bar_w + 10, 75), Color(0, 0, 0, 0.6))
	
	if boss_fish:
		var rarity_col = FishDatabase.get_rarity_color(boss_fish.rarity)
		draw_string(font, Vector2(bar_x, bar_y - 5), boss_fish.name_vn, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, rarity_col)
	
	# Health bar
	draw_rect(Rect2(bar_x, bar_y + 5, bar_w, 20), Color(0.15, 0.15, 0.2))
	var health_col = Color(0.2, 0.8, 0.3).lerp(Color(1.0, 0.2, 0.1), 1.0 - boss_health)
	draw_rect(Rect2(bar_x, bar_y + 5, bar_w * boss_health, 20), health_col)
	draw_rect(Rect2(bar_x, bar_y + 5, bar_w, 20), Color(1, 1, 1, 0.3), false, 1.5)
	
	# Phase indicator
	var phase_num = 1
	match phase:
		BossPhase.PHASE_2: phase_num = 2
		BossPhase.PHASE_3: phase_num = 3
	draw_string(font, Vector2(bar_x + bar_w + 15, bar_y + 22), "Phase " + str(phase_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.8, 0.3))
	
	# Tension bar (vertical)
	var tbar_x = 1730.0
	var tbar_y = 160.0
	var tbar_w = 50.0
	var tbar_h = 550.0
	
	draw_rect(Rect2(tbar_x - 3, tbar_y - 3, tbar_w + 6, tbar_h + 6), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(tbar_x, tbar_y, tbar_w, tbar_h), Color(0.1, 0.1, 0.15, 0.85))
	
	var zone_y = tbar_y + (1.0 - sweet_zone_pos - sweet_zone_size / 2.0) * tbar_h
	var zone_h = sweet_zone_size * tbar_h
	draw_rect(Rect2(tbar_x, zone_y, tbar_w, zone_h), Color(0.15, 0.55, 0.2, 0.6))
	
	var tension_y = tbar_y + (1.0 - tension) * tbar_h
	var in_zone = abs(tension - sweet_zone_pos) < sweet_zone_size / 2.0
	var ind_col = Color(0.2, 1.0, 0.3) if in_zone else Color(1.0, 0.25, 0.2)
	draw_rect(Rect2(tbar_x - 8, tension_y - 6, tbar_w + 16, 12), ind_col)
	draw_rect(Rect2(tbar_x, tbar_y, tbar_w, tbar_h), Color(1, 1, 1, 0.3), false, 2.0)
	
	draw_string(font, Vector2(tbar_x - 60, tbar_y - 10), "Luc keo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(660, 1050), "Giu chuot trai de keo! Can than dung cho day dut!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))


func _draw_appear_ui() -> void:
	var font = ThemeDB.fallback_font
	
	if boss_fish and appear_timer > 1.0:
		var alpha = clampf((appear_timer - 1.0) / 1.0, 0.0, 1.0)
		var rarity_col = FishDatabase.get_rarity_color(boss_fish.rarity)
		
		draw_rect(Rect2(510, 230, 900, 100), Color(0, 0, 0, 0.7 * alpha))
		draw_rect(Rect2(510, 230, 900, 100), Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.4 * alpha), false, 3.0)
		draw_string(font, Vector2(560, 280), "BOSS XUAT HIEN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.3, 0.2, alpha))
		draw_string(font, Vector2(560, 315), boss_fish.name_vn + " - " + boss_fish.description.substr(0, 50), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(rarity_col.r, rarity_col.g, rarity_col.b, alpha * 0.8))


func _draw_victory_ui() -> void:
	var font = ThemeDB.fallback_font
	var alpha = clampf(appear_timer / 1.0, 0.0, 1.0)
	
	if boss_fish:
		var rarity_col = FishDatabase.get_rarity_color(boss_fish.rarity)
		draw_rect(Rect2(510, 300, 900, 130), Color(0, 0, 0, 0.7 * alpha))
		draw_rect(Rect2(510, 300, 900, 130), Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.5 * alpha), false, 3.0)
		draw_string(font, Vector2(560, 360), "CHIEN THANG!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1.0, 0.85, 0.2, alpha))
		draw_string(font, Vector2(560, 405), "Da bat duoc " + boss_fish.name_vn + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(rarity_col.r, rarity_col.g, rarity_col.b, alpha))


func _draw_failed_ui() -> void:
	var font = ThemeDB.fallback_font
	var alpha = clampf(appear_timer / 0.5, 0.0, 1.0)
	draw_rect(Rect2(610, 400, 700, 70), Color(0, 0, 0, 0.6 * alpha))
	draw_string(font, Vector2(660, 445), "Boss da thoat... Thu lai sau!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.4, 0.3, alpha))
