extends Node3D

## Khu dân cư 3D FPP — Người chơi có thể đi bộ đến bến phà

signal go_to_sea

@onready var player = $Player
@onready var camera = $Player/Camera3D
@onready var ferry_terminal = $FerryTerminal

var mouse_sensitivity = 0.002
var move_speed = 15.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ferry_terminal.body_entered.connect(_on_ferry_terminal_entered)
	print("[Village] Sẵn sàng ở chế độ FPP")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
		
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity = direction * move_speed
	else:
		player.velocity = Vector3.ZERO
		
	player.move_and_slide()

func _on_ferry_terminal_entered(body: Node3D) -> void:
	if body == player:
		print("[Village] Đã đến bến phà! Chuyển ra biển...")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		go_to_sea.emit()
