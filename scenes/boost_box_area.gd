extends Area3D

@export var connected_gate: Area3D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("boost_box") and connected_gate:
		connected_gate.is_puzzle_solved = true
		if connected_gate.has_method("update_gate_state"):
			connected_gate.update_gate_state()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("boost_box") and connected_gate:
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager and manager.is_transitioning:
			return
			
		connected_gate.is_puzzle_solved = false
		if connected_gate.has_method("update_gate_state"):
			connected_gate.update_gate_state()
