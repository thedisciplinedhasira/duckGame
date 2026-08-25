extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Assuming your 2D duck is named "Player2D"
	if body.name == "Player2D":
		print("Player reached the transformation spot!")
		
		# Trigger your transformation animation/logic here:
		# body.play_transformation_animation()
		
		# Optional: To disable the trigger after it happens once
		set_deferred("monitoring", false)
