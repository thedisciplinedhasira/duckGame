extends CharacterBody3D
## Player controller: first-person movement + telekinesis grab/hold/throw system.

const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const ACCEL := 19.0  # How fast current_blend_position chases target_blend, per second.


@export var mouse_sensitivity := 0.002
@export var pull_strength := 15.0   # How aggressively a grabbed object is pulled toward hold_position.
@export var throw_strength := 25.0  # Launch speed applied to an object on throw.


@onready var camera: Camera3D = $cameraMount/Camera3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var tele_ray: RayCast3D = $cameraMount/Camera3D/TelekinesisRay
@onready var hold_position: Marker3D = $cameraMount/Camera3D/HoldPosition

# Scene Unique Name (%) is used here specifically so that if the character model
# is swapped or its internal node hierarchy changes, this reference doesn't break
# the way a normal $NodePath would.
@onready var head_look: LookAtModifier3D = %LookAtModifier3D


var current_blend_position := Vector2.ZERO  # Smoothed value fed into the AnimationTree blend space.
var grabbed_object: RigidBody3D = null       # Currently held object, or null if nothing is grabbed.
var hold_distance := 3.0                     # How far in front of the camera the held object sits.
var hold_tween: Tween = null                 # Tracks the active HoldBlend tween so we can cancel/replace it.

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if animation_tree:
		animation_tree.active = true


func _unhandled_input(event: InputEvent) -> void:
	_handle_look_input(event)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# NOTE: there is currently no input path that re-captures the mouse after this.
		# If you want to resume play (rather than treat this as a pause/quit trigger),
		# you'll need a click-to-recapture or menu-close handler elsewhere.

	if event.is_action_pressed("telekinesis_throw") and grabbed_object:
		throw_object()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_grab_input()
	_handle_hold_distance_input(delta)
	_handle_movement(delta)
	_update_crosshair_state()

	process_telekinesis(delta)
	move_and_slide()



# LOOK / CAMERA

## Applies mouse-motion look input: yaw on the body, pitch on the camera (clamped
## to avoid flipping past straight up/down).
func _handle_look_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	rotate_y(-event.relative.x * mouse_sensitivity)

	if camera:
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


# MOVEMENT

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY


## Reads movement input, smooths it into current_blend_position (for the AnimationTree),
## and applies the resulting velocity to the character. Run/walk speed is chosen here
## based on the sprint action.
func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_blend := Vector2.ZERO

	if input_dir != Vector2.ZERO:
		var is_running := Input.is_action_pressed("sprint")
		var current_speed := RUN_SPEED if is_running else WALK_SPEED

		# Y is flipped here because the blend space's forward axis and the raw input's
		# forward axis are opposite conventions -- this matches whatever direction your
		# AnimationTree blend space was authored in. If forward/backward animations look
		# swapped, this is the line to flip.
		var raw_move := Vector2(input_dir.x, -input_dir.y)
		target_blend = raw_move.normalized() * current_speed

	# Smoothly chase the target blend value rather than snapping to it, so animation
	# blending and velocity changes feel continuous instead of jerky on start/stop.
	current_blend_position = current_blend_position.move_toward(target_blend, ACCEL * delta)

	if direction:
		# NOTE: `if direction:` relies on GDScript's implicit truthiness check for Vector3,
		# which is true for any non-zero vector. It's equivalent to `if direction != Vector3.ZERO:`
		# but more compact -- kept as-is since it's valid, idiomatic GDScript.
		var speed_magnitude := current_blend_position.length()
		velocity.x = direction.x * speed_magnitude
		velocity.z = direction.z * speed_magnitude
	else:
		# No directional input: decelerate horizontal velocity to zero instead of
		# cutting it instantly, so stopping doesn't feel abrupt.
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	if animation_tree:
		animation_tree.set("parameters/StateMachine/Movement/blend_position", current_blend_position)



# TELEKINESIS: INPUT HANDLING

## Grab is a hold-style input: pressing the action attempts a grab, releasing it
## lets go. Actual throw is handled separately in _unhandled_input via a distinct action.
func _handle_grab_input() -> void:
	if Input.is_action_just_pressed("telekinesis_grab") and not grabbed_object:
		try_grab_object()

	if Input.is_action_just_released("telekinesis_grab") and grabbed_object:
		release_object()


## While holding an object, Q/E pull it closer or push it farther away.
## Distance is clamped so the object can't be dragged inside the camera or
## flung out to an unreasonable range.
func _handle_hold_distance_input(delta: float) -> void:
	if not grabbed_object:
		return

	const DISTANCE_ADJUST_SPEED := 6.0
	const MIN_HOLD_DISTANCE := 1.5
	const MAX_HOLD_DISTANCE := 15.0

	if Input.is_key_pressed(KEY_Q):
		hold_distance -= DISTANCE_ADJUST_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		hold_distance += DISTANCE_ADJUST_SPEED * delta

	hold_distance = clamp(hold_distance, MIN_HOLD_DISTANCE, MAX_HOLD_DISTANCE)

	if hold_position:
		hold_position.position.z = -hold_distance



# TELEKINESIS: CORE ACTIONS

## Attempts to grab whatever the telekinesis raycast is currently hitting.
## Only RigidBody3D objects are grabbable. On success, gravity is disabled on
## the object (so process_telekinesis has full control of its motion) and any
## existing momentum is zeroed out to prevent a "yank" on grab.
func try_grab_object() -> void:
	if not (tele_ray and tele_ray.is_colliding()):
		return

	var collider := tele_ray.get_collider()
	if not collider is RigidBody3D:
		return

	grabbed_object = collider
	grabbed_object.gravity_scale = 0.0
	grabbed_object.linear_velocity = Vector3.ZERO
	grabbed_object.angular_velocity = Vector3.ZERO

	# Start the hold distance at wherever the object actually was when grabbed,
	# rather than snapping it to a fixed default -- feels more natural.
	var hit_point := tele_ray.get_collision_point()
	hold_distance = camera.global_position.distance_to(hit_point)
	hold_distance = clamp(hold_distance, 1.5, 15.0)

	_set_hold_blend(1.0)

	if head_look:
		head_look.active = true


## Lets go of the grabbed object without throwing it: gravity is restored,
## the hold-pose animation blends out, and a "drop" animation state plays.
func release_object() -> void:
	if not grabbed_object:
		return

	grabbed_object.gravity_scale = 1.0
	grabbed_object = null

	_set_hold_blend(0.0)

	if head_look:
		head_look.active = false

	_travel_animation_state("telekinesisDrop")


## Releases the grabbed object with an impulse in the direction the camera is
## facing, restoring gravity so it falls/flies naturally afterward.
func throw_object() -> void:
	if not grabbed_object:
		return

	grabbed_object.gravity_scale = 1.0
	var throw_direction := -camera.global_transform.basis.z
	grabbed_object.linear_velocity = throw_direction * throw_strength
	grabbed_object = null

	_set_hold_blend(0.0)

	if head_look:
		head_look.active = false

	_travel_animation_state("Movement")


## Per-physics-frame update for a currently held object: drives it toward
## hold_position using a spring-like velocity (proportional to distance * pull_strength)
## and damps out any spin so it settles into a steady hold rather than tumbling.
##
## NOTE: this sets linear_velocity directly every frame rather than applying forces,
## which means it can visually clip through thin geometry if pull_strength is high
## or the object starts far from hold_position. That's an accepted tradeoff for the
## snappy, arcade-y feel here -- if clipping becomes a problem, consider raycasting
## from current_pos to target_pos and clamping the object short of any obstruction.
func process_telekinesis(delta: float) -> void:
	if not (grabbed_object and hold_position):
		return

	var target_pos := hold_position.global_position
	var current_pos := grabbed_object.global_position

	var velocity_vector := (target_pos - current_pos) * pull_strength
	grabbed_object.linear_velocity = velocity_vector
	grabbed_object.angular_velocity = grabbed_object.angular_velocity.lerp(Vector3.ZERO, 10.0 * delta)


# ANIMATION HELPERS
## Tweens the AnimationTree's HoldBlend parameter toward target_value (0 = not holding,
## 1 = holding), cancelling any in-progress blend tween first so rapid grab/release
## doesn't stack competing tweens.
func _set_hold_blend(target_value: float) -> void:
	if not animation_tree:
		return

	if hold_tween and hold_tween.is_running():
		hold_tween.kill()

	hold_tween = create_tween()
	hold_tween.tween_property(
		animation_tree,
		"parameters/HoldBlend/blend_amount",
		target_value,
		0.2
	)


## Small wrapper around the StateMachine playback travel() call, since it's
## used in two places (release and throw) with just a different target state.
func _travel_animation_state(state_name: String) -> void:
	if not animation_tree:
		return

	var state_machine = animation_tree.get("parameters/StateMachine/playback")
	if state_machine:
		state_machine.travel(state_name)


# UI / FEEDBACK

## Updates the crosshair to indicate whether the object currently under the
## telekinesis raycast can be interacted with.
func _update_crosshair_state() -> void:
	if tele_ray and tele_ray.is_colliding() and tele_ray.get_collider() is RigidBody3D:
		Crosshair.set_state_can_interact()
	else:
		Crosshair.set_state_default()
