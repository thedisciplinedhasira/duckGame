extends CharacterBody2D

# Movement Parameters
const MAX_SPEED = 150.0
const ACCELERATION = 1000.0
const FRICTION = 1200.0
const AIR_RESISTANCE = 800.0

# Jump Parameters
const JUMP_VELOCITY = -350.0
const MAX_JUMPS = 2 
var jumps_left = MAX_JUMPS

# Feel/Polish Parameters
const FALL_GRAVITY_MULTIPLIER = 1.5
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.1

@onready var animated_sprite = $AnimatedSprite2D
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var start_position: Vector2

func _ready() -> void:
	# Records the spawn location the moment the level loads
	start_position = global_position

func _physics_process(delta):
	# 1. Timers & State Updates
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jumps_left = MAX_JUMPS
	else:
		coyote_timer -= delta
		
	# CHANGED: Listen for custom "jump" action
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# 2. Gravity & Variable Jump Height
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta
			
		# CHANGED: Listen for custom "jump" action release
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= 0.5

	# 3. Handle Jump with Buffer and Coyote Time
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			jumps_left = MAX_JUMPS - 1
		elif jumps_left > 0:
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			jumps_left -= 1

	# 4. Horizontal Movement (Momentum)
	# CHANGED: Listen for custom "move_left" and "move_right" actions
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		
		if is_on_floor():
			animated_sprite.play("walking")
		animated_sprite.flip_h = direction < 0
	else:
		var current_friction = FRICTION if is_on_floor() else AIR_RESISTANCE
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)
		
		if is_on_floor():
			animated_sprite.play("walking")
			animated_sprite.pause()
			animated_sprite.frame = 0

	move_and_slide()

func _on_spike_thingy_body_entered(body: Node2D) -> void:
	if body == self:
		global_position = start_position
		velocity = Vector2.ZERO # Stops the player from carrying falling momentum into the respawn


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_spike_thingy_2_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_spike_thingy_3_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
