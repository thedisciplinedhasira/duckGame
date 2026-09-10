extends AnimatableBody3D

@export var open_offset := Vector3(0, 3.5, 0) # Moves up 3.5 meters
@export var open_speed := 1.0

@onready var original_position := position
var tween: Tween

# Connect the pressure plate's 'activated' signal to this method
func open_door() -> void:
	_animate_door(original_position + open_offset)

# Connect the pressure plate's 'deactivated' signal to this method
func close_door() -> void:
	_animate_door(original_position)

func _animate_door(target_pos: Vector3) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_pos, open_speed)
