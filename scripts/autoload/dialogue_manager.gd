extends Node

## Dialogue manager autoload
## Optimized for Godot 4 stability

signal dialogue_started
signal dialogue_finished
signal line_changed(line)

var current_lines = []
var current_index = -1
var is_active = false
var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	add_child(audio_player)

func start_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	
	current_lines = lines
	current_index = 0
	is_active = true
	dialogue_started.emit()
	line_changed.emit(current_lines[current_index])
	
	if current_lines[current_index].get("audio"):
		_play_line_audio(current_lines[current_index].audio)

func next_line() -> void:
	if not is_active:
		return
	
	current_index += 1
	if current_index >= current_lines.size():
		finish_dialogue()
		return
	
	line_changed.emit(current_lines[current_index])
	
	if current_lines[current_index].get("audio"):
		_play_line_audio(current_lines[current_index].audio)
	else:
		audio_player.stop()

func finish_dialogue() -> void:
	is_active = false
	current_lines = []
	current_index = -1
	audio_player.stop()
	dialogue_finished.emit()

func _play_line_audio(stream: AudioStream) -> void:
	audio_player.stop()
	audio_player.stream = stream
	audio_player.play()

func _input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interact"):
		next_line()
		get_viewport().set_input_as_handled()
