extends Area3D

@onready var prompt_label = $Label3D

func _ready() -> void:
	# Hide the text when the game starts
	if prompt_label:
		prompt_label.visible = false

func _on_body_entered(body: Node3D) -> void:
	# Make sure this perfectly matches your player node's name!
	if body.name == "Player": 
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_swap_to_2d = true
			manager.use_tutorial_spawn = true 
			
		# Show the text!
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_swap_to_2d = false
			
		# Hide the text!
		if prompt_label:
			prompt_label.visible = false
