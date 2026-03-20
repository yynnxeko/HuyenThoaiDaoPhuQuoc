extends Node3D

## Khu dân cư 3D FPP — Người chơi có thể đi bộ đến bến phà

signal go_to_sea

@onready var player = $Player
@onready var camera = $Player/Camera3D
@onready var ferry_terminal = $FerryTerminal

var mouse_sensitivity = 0.002
var move_speed = 15.0

@onready var nha_van_hoa_old = $Architecture/NhaVanHoaOld_Body
@onready var nha_2 = $Architecture/Nha2_Body
@onready var tho_moc_interaction = $Architecture/Quay3_Body/ThoMoc/InteractionArea
@onready var black_screen = $UI/BlackScreen

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ferry_terminal.body_entered.connect(_on_ferry_terminal_entered)
	print("[Village] Sẵn sàng ở chế độ FPP")
	update_village_hall()
	
	if AudioManager != null and AudioManager.has_method("play_music"):
		AudioManager.play_music(load("res://assets/sound/nhac_nen/nhacnen.mp3"))

func update_village_hall() -> void:
	if not GameData: return
	
	if GameData.is_village_hall_upgraded:
		if nha_van_hoa_old:
			nha_van_hoa_old.hide()
			nha_van_hoa_old.process_mode = Node.PROCESS_MODE_DISABLED
		if nha_2:
			nha_2.show()
			nha_2.process_mode = Node.PROCESS_MODE_INHERIT
		if tho_moc_interaction:
			var lines: Array[String] = [
				"Thợ mộc: Nhà văn hóa mới khang trang quá cháu nhỉ!",
				"Cháu: Dạ, bác thợ mộc mát tay quá, làng mình đẹp hẳn lên!"
			]
			tho_moc_interaction.dialogue_lines = lines
			tho_moc_interaction.custom_action = 0 # CustomAction.NONE
	else:
		if nha_van_hoa_old:
			nha_van_hoa_old.show()
			nha_van_hoa_old.process_mode = Node.PROCESS_MODE_INHERIT
		if nha_2:
			nha_2.hide()
			nha_2.process_mode = Node.PROCESS_MODE_DISABLED

func play_build_transition() -> void:
	if not black_screen:
		update_village_hall()
		return
		
	# Chặn điều khiển người chơi
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var tween = create_tween()
	# Bước 1: Màn hình tối dần (1 giây)
	tween.tween_property(black_screen, "color:a", 1.0, 1.0)
	
	# Bước 2: Đổi model và chờ âm thanh xây dựng (2.5 giây)
	tween.tween_callback(func():
		update_village_hall()
		var build_sound = load("res://assets/sound/nhac_nen/xay_dung.mp3")
		if build_sound:
			AudioManager.play_sfx(build_sound)
	)
	tween.tween_interval(2.5)
	
	# Bước 3: Màn hình sáng lại (1 giây)
	tween.tween_property(black_screen, "color:a", 0.0, 1.0)
	
	# Kết thúc: Trả lại quyền điều khiển
	tween.tween_callback(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

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
