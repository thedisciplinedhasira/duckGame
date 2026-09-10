extends Node2D

func _ready() -> void:
	var manager = get_tree().get_first_node_in_group("dimension_manager")
	
	if manager and manager.get("active_gate") != null:
		var gate = manager.active_gate
		
		# Check if the 3D gate says the puzzle is NOT solved
		if "is_puzzle_solved" in gate and gate.is_puzzle_solved == false:
			# Hide the box
			visible = false
			
			# Disable all physics/collisions so the player can't jump on an invisible box
			process_mode = Node.PROCESS_MODE_DISABLED
