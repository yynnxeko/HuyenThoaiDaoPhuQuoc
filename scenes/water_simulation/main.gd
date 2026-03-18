extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var sim_cr = $Simulation/ColorRect
	var buf_cr = $SimulationBuffer/ColorRect
	var water = $Water
	var sim_tex = $Simulation.get_texture()
	var col_tex = $Collision.get_texture()

	# Pass collision texture to the simulation shader so it can detect
	# objects touching the water and create ripples
	sim_cr.material.set_shader_parameter('col_tex', col_tex)

	# Pass simulation texture to the water surface shader
	water.mesh.surface_get_material(0).set_shader_parameter('simulation', sim_tex)
	water.mesh.surface_get_material(0).set_shader_parameter('simulation2', sim_tex)
