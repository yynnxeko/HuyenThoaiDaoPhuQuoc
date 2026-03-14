extends Node3D

## 3D Main Menu — Beautiful 3D background with native UI buttons

signal start_game
signal continue_game

@onready var ui_root: Control = $UI/Control
@onready var btn_start: Button = $UI/Control/CenterContainer/VBoxContainer/BtnStart
@onready var btn_continue: Button = $UI/Control/CenterContainer/VBoxContainer/BtnContinue
@onready var btn_quit: Button = $UI/Control/CenterContainer/VBoxContainer/BtnQuit

var time: float = 0.0
var title_glow: float = 0.0
var _prev_mouse_left: bool = false
var _prev_focus: bool = true
var _diag_timer: float = 0.0

func _ready() -> void:
	# Always release mouse on menu so UI is clickable.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process_input(true)
	set_process_unhandled_input(true)
	# Make sure GUI input is enabled and not swallowed by the root Control.
	get_viewport().gui_disable_input = false
	if ui_root:
		ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	print("[Menu] ready | ui_root=", ui_root, " gui_disable_input=", get_viewport().gui_disable_input, " mouse_mode=", Input.get_mouse_mode())

	if btn_start == null or btn_continue == null or btn_quit == null:
		push_error("Main menu buttons not found in scene tree. Check node paths in main_menu.gd.")
		return
	print("[Menu] buttons found | start=", btn_start, " continue=", btn_continue, " quit=", btn_quit)

	# Check for save data
	if FileAccess.file_exists("user://save_data.json"):
		btn_continue.show()
		btn_continue.grab_focus()
	else:
		btn_continue.hide()
		btn_start.grab_focus()
	
	# Ensure buttons are interactive
	btn_start.disabled = false
	btn_continue.disabled = false
	btn_quit.disabled = false
	btn_start.focus_mode = Control.FOCUS_ALL
	btn_continue.focus_mode = Control.FOCUS_ALL
	btn_quit.focus_mode = Control.FOCUS_ALL
	btn_start.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_continue.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_quit.mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect buttons
	btn_start.pressed.connect(_on_start_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_start.gui_input.connect(_on_btn_gui_input.bind("start"))
	btn_continue.gui_input.connect(_on_btn_gui_input.bind("continue"))
	btn_quit.gui_input.connect(_on_btn_gui_input.bind("quit"))
	print("[Menu] signals connected")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[Menu] mouse click btn=", event.button_index, " pos=", event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[Menu] unhandled mouse click btn=", event.button_index, " pos=", event.position)


func _on_btn_gui_input(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[Menu] gui_input on ", which, " btn=", event.button_index, " pos=", event.position)


func _on_start_pressed() -> void:
	print("[Menu] Start pressed")
	start_game.emit()
	# Fallback: if menu is run directly (F6) and no listener is connected,
	# switch to game scene here.
	if start_game.get_connections().is_empty():
		if GameData != null and GameData.has_method("reset_game"):
			GameData.reset_game()
		var err := get_tree().change_scene_to_file("res://scenes/game/game.tscn")
		if err != OK:
			push_error("Cannot change scene to game.tscn. Error: " + str(err))
	if AudioManager != null and AudioManager.has_method("play_ui_click"):
		AudioManager.play_ui_click()


func _on_continue_pressed() -> void:
	print("[Menu] Continue pressed")
	continue_game.emit()
	# Fallback: if menu is run directly (F6) and no listener is connected,
	# switch to game scene here.
	if continue_game.get_connections().is_empty():
		if GameData != null and GameData.has_method("load_game"):
			GameData.load_game()
		var err := get_tree().change_scene_to_file("res://scenes/game/game.tscn")
		if err != OK:
			push_error("Cannot change scene to game.tscn. Error: " + str(err))
	if AudioManager != null and AudioManager.has_method("play_ui_click"):
		AudioManager.play_ui_click()


func _on_quit_pressed() -> void:
	if AudioManager != null and AudioManager.has_method("play_ui_click"):
		AudioManager.play_ui_click()
	get_tree().quit()


func _process(delta: float) -> void:
	time += delta
	title_glow = 0.5 + 0.5 * sin(time * 1.5)

	# Diagnostics: focus/mouse state (prints on change, not every frame)
	_diag_timer += delta
	if _diag_timer >= 0.2:
		_diag_timer = 0.0
		var focused := DisplayServer.window_is_focused()
		if focused != _prev_focus:
			_prev_focus = focused
			print("[Menu] window focused=", focused)
		var mouse_left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if mouse_left != _prev_mouse_left:
			_prev_mouse_left = mouse_left
			print("[Menu] mouse_left_pressed=", mouse_left)
	
	# Slowly rotate camera
	$CameraPivot.rotation_degrees.y = sin(time * 0.1) * 15.0
	
	# Gentle glow on the title Label
	var title_lbl = $UI/Control/TitleShadow/Title
	var title_lbl2 = $UI/Control/TitleShadow/Title2
	var gold = Color(1.0, 0.88, 0.35 + title_glow * 0.15)
	
	title_lbl.add_theme_color_override("font_color", gold)
	title_lbl2.add_theme_color_override("font_color", gold)
