extends Area2D

@export var return_marker_group: String = "" 
@onready var label: Label = get_node_or_null("Label")

func _ready() -> void:
	if label:
		label.visible = false
		
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player_2d"):
		if label:
			label.visible = true
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			# Optional: ensure player can swap back
			if "can_switch_to_3d" in manager:
				manager.can_switch_to_3d = true
				
			if manager.get("active_gate") != null:
				# If there is a custom group (like exitArea), change the gate's destination
				if return_marker_group != "":
					var target = get_tree().get_first_node_in_group(return_marker_group) as Node3D
					if target:
						manager.active_gate.return_3d_marker = target
				# If blank (like startArea), reset to the gate's default original marker
				else:
					var original = manager.active_gate.get("original_marker")
					if original:
						manager.active_gate.return_3d_marker = original

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player_2d"):
		if label:
			label.visible = false
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager and "can_switch_to_3d" in manager:
			manager.can_switch_to_3d = false
