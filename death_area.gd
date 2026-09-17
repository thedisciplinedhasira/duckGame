extends Area3D

@export var respawn_marker: Marker3D

func _ready() -> void:
	# Connect the signal through code so you don't have to do it manually every time
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if the body that fell in is the player
	if body.name == "player" or body.has_method("die"):
		if respawn_marker:
			body.die(respawn_marker.global_position)
		else:
			push_warning("No respawn marker assigned to this death area!")
