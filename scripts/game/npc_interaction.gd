extends Area3D

## Script for NPC interaction trigger

@export var character_name: String = "NPC"
@export var dialogue_lines: Array[String] = []
@export var dialogue_audio: Array[AudioStream] = [] # Optional audio for each line

enum CustomAction { NONE, OPEN_MARKET }
@export var custom_action: CustomAction = CustomAction.NONE

var is_player_near: bool = false
var can_interact: bool = true
var is_dialogue_active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		is_player_near = true
		# Show interaction hint (optional)
		print("Press 'E' to talk to ", character_name)

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		is_player_near = false

func _input(event: InputEvent) -> void:
	if is_player_near and can_interact and event.is_action_pressed("interact"):
		# Using get_node_or_null to be safe or just standard global check
		if DialogueManager and not DialogueManager.is_active:
			_start_dialogue()
			get_viewport().set_input_as_handled() # Prevent double-triggering DialogueManager

func _start_dialogue() -> void:
	var lines: Array = []
	for i in range(dialogue_lines.size()):
		var line = DialogueLine.new()
		var raw_text = dialogue_lines[i]
		
		# Parse speaker name if formatted like "Name: Text"
		if ": " in raw_text:
			var parts = raw_text.split(": ", true, 1)
			if parts[0].length() <= 30: # Basic validation to check if it's actually a name
				line.character_name = parts[0]
				line.text = parts[1]
			else:
				line.character_name = character_name
				line.text = raw_text
		else:
			line.character_name = character_name
			line.text = raw_text
			
		if i < dialogue_audio.size():
			line.audio = dialogue_audio[i]
		lines.append(line)
	
	DialogueManager.start_dialogue(lines)
	is_dialogue_active = true
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_finished() -> void:
	if is_dialogue_active:
		is_dialogue_active = false
		DialogueManager.dialogue_finished.disconnect(_on_dialogue_finished)
		if custom_action == CustomAction.OPEN_MARKET:
			_open_market()

func _open_market() -> void:
	var market_scene = load("res://scenes/ui/market.tscn")
	if market_scene:
		var market_root = market_scene.instantiate()
		var market_ctrl = market_root.get_child(0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		market_ctrl.market_closed.connect(func():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			market_root.queue_free()
		)
		get_tree().current_scene.add_child(market_root)
