extends Area2D

@onready var label: Label = get_node_or_null("Label") 
@export var is_tutorial_exit: bool = false 

func _ready() -> void:
	if label:
		label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Our backup check: Constantly scans for the player's class type
func _physics_process(_delta: float) -> void:
	if label and not label.visible:
		for body in get_overlapping_bodies():
			if body is CharacterBody2D: # <-- Bulletproof check!
				_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D: # (or body.is_in_group("player"))
		if label:
			label.visible = true
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_switch_to_3d = true
			
			# If we are in the exit area...
			if is_tutorial_exit:
				manager.use_tutorial_spawn = true
				manager.use_tutorial_gate_spawn = false
			# If we are in the start area...
			else:
				manager.use_tutorial_spawn = false
				manager.use_tutorial_gate_spawn = true
func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		if label:
			label.visible = false
			
		var manager = get_tree().get_first_node_in_group("dimension_manager")
		if manager:
			manager.can_switch_to_3d = false
			if is_tutorial_exit:
				manager.use_tutorial_spawn = false
