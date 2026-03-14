extends Node

## Main scene — manages transitions: Menu → Game, and back

@onready var current_scene: Node = null
var menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
var game_scene_path: String = "res://scenes/game/game.tscn"


func _ready() -> void:
	_show_main_menu()


func _show_main_menu() -> void:
	_clear_current()
	var scene = load(menu_scene_path)
	if scene:
		current_scene = scene.instantiate()
		add_child(current_scene)
		if current_scene.has_signal("start_game"):
			current_scene.start_game.connect(_on_start_game)
		if current_scene.has_signal("continue_game"):
			current_scene.continue_game.connect(_on_continue_game)

		# Fallback: connect buttons directly in case menu script signal flow is broken.
		var btn_start = current_scene.get_node_or_null("UI/Control/CenterContainer/VBoxContainer/BtnStart")
		if btn_start and not btn_start.pressed.is_connected(_on_start_game):
			btn_start.pressed.connect(_on_start_game)
		var btn_continue = current_scene.get_node_or_null("UI/Control/CenterContainer/VBoxContainer/BtnContinue")
		if btn_continue and not btn_continue.pressed.is_connected(_on_continue_game):
			btn_continue.pressed.connect(_on_continue_game)
	else:
		OS.alert("Lỗi: Không thể tải được file main_menu.tscn! (" + menu_scene_path + ")", "Lỗi Load Menu")


func _on_start_game() -> void:
	print("[Main] _on_start_game")
	if GameData != null and GameData.has_method("reset_game"):
		GameData.reset_game()
	call_deferred("_load_game")


func _on_continue_game() -> void:
	print("[Main] _on_continue_game")
	if GameData != null and GameData.has_method("load_game"):
		GameData.load_game()
	call_deferred("_load_game")


func _load_game() -> void:
	print("[Main] _load_game -> " + game_scene_path)
	_clear_current()
	var scene = load(game_scene_path)
	if scene:
		current_scene = scene.instantiate()
		add_child(current_scene)
		print("[Main] game scene instantiated")
		if current_scene.has_signal("return_to_menu"):
			current_scene.return_to_menu.connect(_on_return_to_menu)
	else:
		OS.alert("Lỗi: Không thể tải được file game.tscn! Hãy nhấn F4 để xem tab Errors.", "Lỗi Load Game")


func _on_return_to_menu() -> void:
	_show_main_menu()


func _clear_current() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
