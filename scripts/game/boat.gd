extends Node2D

## Boat controller — handles movement and visual rendering

var facing_right: bool = true
var velocity_x: float = 0.0
var bob_time: float = 0.0

# Visual properties
var boat_width: float = 120.0
var boat_height: float = 35.0


func _process(delta: float) -> void:
	bob_time += delta
	queue_redraw()


func _draw() -> void:
	var flip = 1.0 if facing_right else -1.0
	
	# === BOAT HULL ===
	var hull_points = PackedVector2Array([
		Vector2(-60 * flip, 0),
		Vector2(-70 * flip, 15),
		Vector2(-55 * flip, 32),
		Vector2(55 * flip, 32),
		Vector2(70 * flip, 15),
		Vector2(60 * flip, 0),
	])
	# Main hull
	draw_colored_polygon(hull_points, Color(0.5, 0.3, 0.12))
	
	# Hull shadow/detail
	var hull_detail = PackedVector2Array([
		Vector2(-55 * flip, 15),
		Vector2(-50 * flip, 30),
		Vector2(50 * flip, 30),
		Vector2(55 * flip, 15),
	])
	draw_colored_polygon(hull_detail, Color(0.4, 0.22, 0.08))
	
	# Plank lines
	for i in range(3):
		var y = 5.0 + float(i) * 9.0
		draw_line(Vector2(-55 * flip, y), Vector2(55 * flip, y), Color(0.35, 0.18, 0.06, 0.5), 1.0)
	
	# Deck rail
	draw_line(Vector2(-55 * flip, 0), Vector2(55 * flip, 0), Color(0.6, 0.38, 0.18), 3.0)
	
	# === CHARACTER ===
	var char_x = 15.0 * flip
	
	# Legs
	draw_line(Vector2(char_x - 4, 0), Vector2(char_x - 6, -5), Color(0.25, 0.2, 0.15), 3.5)
	draw_line(Vector2(char_x + 4, 0), Vector2(char_x + 3, -5), Color(0.25, 0.2, 0.15), 3.5)
	
	# Body (traditional Vietnamese shirt)
	var body_points = PackedVector2Array([
		Vector2(char_x - 10, -5),
		Vector2(char_x - 8, -30),
		Vector2(char_x + 8, -30),
		Vector2(char_x + 10, -5),
	])
	draw_colored_polygon(body_points, Color(0.2, 0.4, 0.6))
	
	# Arms
	var arm_swing = sin(bob_time * 0.5) * 2.0
	# Back arm
	draw_line(Vector2(char_x - 6, -25), Vector2(char_x - 14, -15 + arm_swing), Color(0.75, 0.6, 0.45), 3.0)
	# Front arm (holding rod)
	draw_line(Vector2(char_x + 6, -25), Vector2(char_x + 12, -20), Color(0.75, 0.6, 0.45), 3.0)
	
	# Head
	draw_circle(Vector2(char_x, -38), 9.0, Color(0.85, 0.7, 0.5))
	
	# Nón lá (conical hat)
	var hat_points = PackedVector2Array([
		Vector2(char_x - 14, -44),
		Vector2(char_x, -58),
		Vector2(char_x + 14, -44),
	])
	draw_colored_polygon(hat_points, Color(0.78, 0.68, 0.42))
	# Hat brim
	draw_line(Vector2(char_x - 14, -44), Vector2(char_x + 14, -44), Color(0.65, 0.55, 0.35), 1.5)
	
	# === FISHING ROD ===
	var rod_base = Vector2(char_x + 12, -20)
	var rod_tip_angle = sin(bob_time * 1.0) * 0.05
	var rod_tip = rod_base + Vector2(70.0 * flip, -45.0 + rod_tip_angle * 10.0)
	
	# Rod body (bamboo)
	draw_line(rod_base, rod_tip, Color(0.55, 0.4, 0.15), 2.5)
	# Rod tip (thinner)
	var rod_end = rod_tip + Vector2(15.0 * flip, -8.0)
	draw_line(rod_tip, rod_end, Color(0.5, 0.35, 0.12), 1.5)
	
	# Small reel
	draw_circle(rod_base + Vector2(5 * flip, 3), 4.0, Color(0.4, 0.4, 0.45))
