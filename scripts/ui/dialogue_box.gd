extends CanvasLayer

## UI script to display dialogue lines
## Uses Tween and visible_ratio for robust, non-overlapping typing effect

@onready var panel = $Control/Panel
@onready var name_label = $Control/Panel/NameLabel
@onready var text_label = $Control/Panel/TextLabel

var typing_speed: float = 0.03
var typing_tween: Tween

func _ready() -> void:
	visible = false
	text_label.visible_ratio = 0.0
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	DialogueManager.line_changed.connect(_on_line_changed)

func _on_dialogue_started() -> void:
	visible = true

func _on_dialogue_finished() -> void:
	visible = false
	if typing_tween:
		typing_tween.kill()

func _on_line_changed(line: Resource) -> void:
	# Stop any current typing
	if typing_tween:
		typing_tween.kill()
	
	name_label.text = line.get("character_name") if line.has_method("get") else "NPC"
	text_label.text = line.get("text") if line.has_method("get") else ""
	
	# Reset and start new typing animation
	text_label.visible_ratio = 0.0
	var duration = text_label.text.length() * typing_speed
	
	typing_tween = create_tween()
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
