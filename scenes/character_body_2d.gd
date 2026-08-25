extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const MAX_JUMPS = 2  

@onready var animated_sprite = $AnimatedSprite2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jumps_left = MAX_JUMPS

func _physics_process(delta):
	# Reset jumps when touching the floor
	if is_on_floor():
		jumps_left = MAX_JUMPS
	else:
		# Add gravity if in the air
		velocity.y += gravity * delta

	# Handle Jump and Double Jump
	if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

	# Get horizontal direction 
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = direction * SPEED
		# Only play walking animation while on the ground
		if is_on_floor():
			animated_sprite.play("walking")
		# Flip sprite based on movement direction
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			#idle animation:
			# animated_sprite.play("idle")
			animated_sprite.play("walking")
			animated_sprite.pause() # Pauses on frame 0 instead of stopping the render
			animated_sprite.frame = 0

	move_and_slide()
