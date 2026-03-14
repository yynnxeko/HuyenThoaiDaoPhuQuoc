extends Node2D

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
		current_scene.start_game.connect(_on_start_game)
		current_scene.continue_game.connect(_on_continue_game)


func _on_start_game() -> void:
	GameData.reset_game()
	_load_game()


func _on_continue_game() -> void:
	GameData.load_game()
	_load_game()


func _load_game() -> void:
	_clear_current()
	var scene = load(game_scene_path)
	if scene:
		current_scene = scene.instantiate()
		add_child(current_scene)
		if current_scene.has_signal("return_to_menu"):
			current_scene.return_to_menu.connect(_on_return_to_menu)


func _on_return_to_menu() -> void:
	_show_main_menu()


func _clear_current() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
