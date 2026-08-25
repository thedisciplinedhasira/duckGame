extends Area3D

@onready var label: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	if label:
		label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("Terminal Area3D Ready! My name is: ", name)

func _on_body_entered(body: Node3D) -> void:
	print(">>> SOMETHING ENTERED THE TERMINAL AREA: ", body.name)
	if body.name == "Player":
		print(">>> IT IS THE PLAYER! Turning on swap access...")
		if label:
			label.visible = true
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_swap_to_2d = true
			manager.use_tutorial_spawn = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		print(">>> PLAYER EXITED THE TERMINAL AREA. Revoking swap access...")
		if label:
			label.visible = false
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_swap_to_2d = false
