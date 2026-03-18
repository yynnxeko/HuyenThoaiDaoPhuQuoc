extends Node3D

@export var boat: RigidBody3D

func _process(delta: float) -> void:
	# Boat movement handles throttling/steering
	if Input.is_action_just_pressed("fishing_toggle"): # "E"
		toggle_fishing()

func toggle_fishing() -> void:
	# This should interface with the existing fishing_mode.gd
	var fishing_ui = get_tree().root.find_child("FishingMode", true, false)
	if fishing_ui:
		if fishing_ui.state == 0: # IDLE
			fishing_ui.start_fishing()
		else:
			fishing_ui._end_fishing()
