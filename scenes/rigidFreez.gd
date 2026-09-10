extends RigidBody3D

@export var activation_distance := 25.0
var player: Node3D = null

func _ready() -> void:
	freeze = true # Holds the object suspended in space
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if freeze and player:
		if global_position.distance_to(player.global_position) <= activation_distance:
			freeze = false
			set_process(false) # Stops checking distance once unfrozen
