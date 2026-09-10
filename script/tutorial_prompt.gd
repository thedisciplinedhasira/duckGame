extends Area3D

@onready var label: Label3D = $Label3D

func _ready() -> void:
	if label:
		label.visible = false
		
	# Automatically connect the physics signals to our functions
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if label:
			label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if label:
			label.visible = false
