extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("boost_box"):
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.is_boost_box_placed = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("boost_box"):
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		
		
		# If the game is in the middle of a swap, ignore this exit
		if manager and manager.is_transitioning:
			return 
		
		if manager:
			manager.is_boost_box_placed = false
