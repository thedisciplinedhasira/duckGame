extends Node3D

signal activated
signal deactivated

@export var sink_distance := 0.2
@export var move_speed := 0.3

@onready var platform: AnimatableBody3D = $PlatformMesh
@onready var detection_area: Area3D = $DetectionArea
@onready var original_y := platform.position.y

var overlapping_bodies := 0
var tween: Tween

func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Ignore the pressure plate's own platform
	if body == platform:
		return

	print("Something touched the plate: ", body.name)
	
	if body is CharacterBody3D or body is RigidBody3D:
		overlapping_bodies += 1
		print("Valid body entered. Total bodies: ", overlapping_bodies)
		if overlapping_bodies == 1:
			_set_plate_state(true)

func _on_body_exited(body: Node3D) -> void:
	if body == platform:
		return

	if body is CharacterBody3D or body is RigidBody3D:
		overlapping_bodies -= 1
		print("Valid body exited. Total bodies: ", overlapping_bodies)
		if overlapping_bodies <= 0:
			overlapping_bodies = 0
			_set_plate_state(false)
			
func _set_plate_state(is_pressed: bool) -> void:
	print("Plate is pressed: ", is_pressed)
	
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var target_y = original_y - sink_distance if is_pressed else original_y
	
	tween.tween_property(platform, "position:y", target_y, move_speed)

	if is_pressed:
		activated.emit()
	else:
		deactivated.emit()
