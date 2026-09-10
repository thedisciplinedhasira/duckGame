extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Verifies the object touching the spikes is actually the player
	if body.is_in_group("player"):
		
		# Option A: If your player script has a specific death sequence/animation
		if body.has_method("die"):
			body.die()
			
		# Option B: The classic arcade approach - instantly restart the current scene
		# get_tree().reload_current_scene()
