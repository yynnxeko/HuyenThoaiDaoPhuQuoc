extends Resource
class_name DialogueLine

## A single line of dialogue with an optional audio stream

@export var character_name: String = "NPC"
@export_multiline var text: String = ""
@export var audio: AudioStream
