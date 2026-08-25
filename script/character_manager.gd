extends Node

@export var grass_material: ShaderMaterial
var update_timer: float = 0.0
var fps_limit: float = 12.0 # The low frame-rate style

func _process(delta):
	update_timer += delta
	if update_timer >= (1.0 / fps_limit):
		update_timer = 0.0
		update_shader_positions()

func update_shader_positions():
	var characters = get_tree().get_nodes_in_group("character")
	var positions_array: Array[Vector4] = []
	
	# We must fill exactly 64 slots because shaders require fixed array sizes
	for i in range(64):
		if i < characters.size():
			var char_pos = characters[i].global_position
			# Vector4(X, Y, Z, Radius of displacement)
			positions_array.append(Vector4(char_pos.x, char_pos.y, char_pos.z, 1.5))
		else:
			# Fill the rest with zeros so they don't affect the grass
			positions_array.append(Vector4.ZERO)
			
	# Send the array to the shader
	if grass_material:
		grass_material.set_shader_parameter("character_positions", positions_array)
