extends CharacterBody3D


const WALK_SPEED := 4
const RUN_SPEED := 9
#const JUMP_VELOCITY := 4.5
const ACCEL := 15
const ROTATION_SMOOTHING := 19 #def was 6
const CARRY_SPEED := 2.0 

@export var mouse_sensitivity := 0.002
@export var pull_strength := 15.0
@export var throw_strength := 25.0

@export_category("Telekinesis Settings")
@export_range(30.0, 120.0) var max_head_look_angle: float = 75.0

@export_category("Hover Settings")
@export var hover_target_height := 2.0 # The consistent height above the ground
@export var hover_spring_strength := 18.0 # How hard it pushes up to maintain height
@export var hover_damping := 5.0 # Prevents the duck from bouncing up and down infinitely

@onready var hover_audio: AudioStreamPlayer3D = $HoverAudio
@onready var ambient_sound: AudioStreamPlayer = $AmbientSound
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_mount: Node3D = $cameraMount
@onready var camera: Camera3D = $cameraMount/Camera3D
@onready var tele_ray: RayCast3D = $cameraMount/Camera3D/TelekinesisRay
@onready var hold_position: Marker3D = $cameraMount/Camera3D/HoldPosition
@onready var footstep_dust: GPUParticles3D = $FootStepsDust
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio

# Hover effect
@onready var tornado_vfx: Node3D = $tornadoVFX

# Telekinesis effects
@onready var telekinesis_vfx: GPUParticles3D = $cameraMount/Camera3D/HoldPosition/TelekinesisVFX
#@onready var tele_tornado: Node3D = $"tornado fire" # Stretching tornado replacing the old beam

@onready var head_look: LookAtModifier3D = %LookAtModifier3D  # survives model swaps

var current_blend_position := Vector2.ZERO
var grabbed_object: RigidBody3D = null
var hold_distance := 3.0
var hold_tween: Tween = null
var current_anim_state := "Movement"

# camera
var target_yaw := 0.0
var target_pitch := 0.0
var camera_offset := Vector3.ZERO

# input
var is_input_locked := false
var has_telekinesis_unlocked := false

# footsteps
var footstep_timer := 0.0
const WALK_STEP_TIME := 0.4
const RUN_STEP_TIME := 0.25

# abilities
var is_hover_toggled := false
var is_3d_mode := true

enum Ability { NONE, HOVER, PERSPECTIVE, TELEKINESIS }
var current_ability: Ability = Ability.NONE

#script
var potions_in_inventory := 0
var magic_feathers_collected := 0 # The reward

@export_group("Ability Icons")
@export var icon_hover: Texture2D
@export var icon_perspective: Texture2D
@export var icon_telekinesis: Texture2D

@onready var active_ability_icon: TextureRect = $HUD/ActiveAbilityIcon


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_yaw = rotation.y

	if camera:
		target_pitch = camera.rotation.x
	if animation_tree:
		animation_tree.active = true
	if head_look:
		head_look.active = false

	if tornado_vfx:
		tornado_vfx.visible = false
		
	#if tele_tornado:
		#tele_tornado.visible = false
		
	if telekinesis_vfx:
		telekinesis_vfx.emitting = false

	# top_level = true so the mount doesn't just follow the body's transform
	if camera_mount:
		camera_offset = camera_mount.position
		camera_mount.top_level = true


func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked:
		return

	_handle_look_input(event)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("telekinesis_throw") and grabbed_object:
		throw_object()


func _physics_process(delta: float) -> void:
	if ambient_sound and ambient_sound.playing and ambient_sound.get_playback_position() >= 6.99:
		ambient_sound.play()  # manual loop, restarts a hair before the clip ends

	if camera_mount:
		camera_mount.global_position = global_position + camera_offset

	RenderingServer.global_shader_parameter_set("player_position", global_position)

	if is_input_locked:
		_apply_gravity(delta)
		move_and_slide()
		return

	_handle_look_rotation(delta)
	_apply_gravity(delta)
#	_handle_jump()
	_handle_grab_input()
	_handle_hold_distance_input(delta)
	_handle_movement(delta)
	_handle_hover_state()
	_update_crosshair_state()
	process_telekinesis(delta)
	move_and_slide()


func _handle_look_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	target_yaw -= event.relative.x * mouse_sensitivity
	target_pitch -= event.relative.y * mouse_sensitivity
	target_pitch = clamp(target_pitch, deg_to_rad(-89), deg_to_rad(89))


func _handle_look_rotation(delta: float) -> void:
	if camera_mount:
		var yaw := camera_mount.rotation.y
		camera_mount.rotation.y = lerp_angle(yaw, target_yaw, ROTATION_SMOOTHING * delta)
	if camera:
		camera.rotation.x = clamp(target_pitch, deg_to_rad(-89), deg_to_rad(89))


func _is_hovering() -> bool:
	return current_ability == Ability.HOVER and Input.is_action_pressed("hover")


func _apply_gravity(delta: float) -> void:
	if _is_hovering():
		# Raycast straight down from the player to find the floor
		var space_state = get_world_3d().direct_space_state
		var origin = global_position + Vector3(0, 0.1, 0) # Start slightly above feet
		var end = origin + Vector3(0, -10.0, 0) # Look up to 10 meters down
		
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [self.get_rid()]
		var result = space_state.intersect_ray(query)

		if result:
			# Spring-damper system to hover consistently at the target height
			var current_height = origin.distance_to(result.position)
			var height_error = hover_target_height - current_height
			
			var spring_force = height_error * hover_spring_strength
			var damp_force = -velocity.y * hover_damping
			
			# Apply the smooth hover force
			velocity.y += (spring_force + damp_force) * delta
		else:
			# If there is no floor (like hovering over a pit), act as a parachute
			velocity.y = lerp(velocity.y, -2.0, 3.0 * delta)
			
	elif not is_on_floor():
		velocity += get_gravity() * 15.0 * delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, 20.0 * delta)


#func _handle_jump() -> void:
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_basis := camera_mount.global_transform.basis
	var direction := cam_basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	var target_blend := Vector2.ZERO

	if direction:
		var target_angle := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, ROTATION_SMOOTHING * delta)

		var is_running := Input.is_action_pressed("sprint") and not grabbed_object
		var current_speed := RUN_SPEED if is_running else WALK_SPEED
		
		if grabbed_object:
			current_speed = CARRY_SPEED
		
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		target_blend = Vector2(0, current_speed)
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		target_blend = Vector2.ZERO

	current_blend_position = current_blend_position.move_toward(target_blend, ACCEL * delta)
	if animation_tree:
		animation_tree.set("parameters/StateMachine/Movement/blend_position", current_blend_position)

	# footstep dust/audio, only when actually moving (not just holding sprint)
	var horizontal_speed := Vector3(velocity.x, 0, velocity.z).length()
	var is_moving_fast := Input.is_action_pressed("sprint") and horizontal_speed > WALK_SPEED + 1.0

	if footstep_dust:
		footstep_dust.emitting = is_moving_fast and is_on_floor() and not _is_hovering()

	if direction != Vector3.ZERO and is_on_floor() and not _is_hovering():
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			if footstep_audio:
				footstep_audio.play()
			footstep_timer = RUN_STEP_TIME if is_moving_fast else WALK_STEP_TIME
	else:
		footstep_timer = 0.0


func _handle_hover_state() -> void:
	if not animation_tree:
		return

	var hovering := _is_hovering()

	if tornado_vfx:
		tornado_vfx.visible = hovering

	if hover_audio:
		if hovering:
			if not hover_audio.playing or hover_audio.get_playback_position() >= 30.0:
				hover_audio.play(5.0)  # start partway in, not from 0
		elif hover_audio.playing:
			hover_audio.stop()

	var target_state := "hovering" if (not is_on_floor() or hovering) else "Movement"
	if current_anim_state != target_state:
		current_anim_state = target_state
		_travel_animation_state(target_state)


func _handle_grab_input() -> void:
	if Input.is_action_just_pressed("telekinesis_grab") and not grabbed_object:
		try_grab_object()
	if Input.is_action_just_released("telekinesis_grab") and grabbed_object:
		release_object()


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


func try_grab_object() -> void:
	if not (tele_ray and tele_ray.is_colliding()):
		return
	# Zoom the camera in slightly to create a feeling of intense focus
	if camera:
		var fov_tween = create_tween()
		fov_tween.tween_property(camera, "fov", 65.0, 0.2).set_trans(Tween.TRANS_SINE)

	var collider := tele_ray.get_collider()
	if not collider is RigidBody3D:
		return

	grabbed_object = collider
	grabbed_object.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
	grabbed_object.gravity_scale = 0.0
	#grabbed_object.linear_velocity = Vector3.ZERO
	#grabbed_object.angular_velocity = Vector3.ZERO

	#var beam_origin := global_position + Vector3(0, 0.6, 0)
	#hold_distance = clamp(beam_origin.distance_to(tele_ray.get_collision_point()), 1.5, 15.0)
	hold_distance = clamp(camera.global_position.distance_to(tele_ray.get_collision_point()), 1.5, 15.0)
	_set_hold_blend(1.0)

	if telekinesis_vfx:
		telekinesis_vfx.emitting = true
		telekinesis_vfx.restart()

	#if tele_tornado:
		#tele_tornado.visible = true

	if head_look:
		head_look.target_node = hold_position.get_path()

func release_object() -> void:
	# Reset camera FOV back to default (assuming default is 75)
	if camera:
		var fov_tween = create_tween()
		fov_tween.tween_property(camera, "fov", 75.0, 0.3).set_trans(Tween.TRANS_SINE)
		
	if grabbed_object:
		grabbed_object.gravity_scale = 1.0
		grabbed_object = null

	_set_hold_blend(0.0)

	if telekinesis_vfx:
		telekinesis_vfx.emitting = false

	#if tele_tornado:
		#tele_tornado.visible = false

	if head_look:
		head_look.target_node = NodePath("")
		head_look.active = false



func throw_object() -> void:
	# Reset camera FOV back to default (assuming default is 75)
	if camera:
		var fov_tween = create_tween()
		fov_tween.tween_property(camera, "fov", 75.0, 0.3).set_trans(Tween.TRANS_SINE)
	if not grabbed_object:
		return

	grabbed_object.gravity_scale = 1.0

	var throw_direction := -camera.global_transform.basis.z
	grabbed_object.linear_velocity = throw_direction * throw_strength
	grabbed_object = null

	_set_hold_blend(0.0)

	if telekinesis_vfx:
		telekinesis_vfx.emitting = false

	#if tele_tornado:
		#tele_tornado.visible = false

	if head_look:
		head_look.active = false
		head_look.target_node = NodePath("")
	

	current_anim_state = "Movement"
	_travel_animation_state("Movement")


func process_telekinesis(delta: float) -> void:
	if not grabbed_object:
		return

	var beam_origin := global_position + Vector3(0, 0.6, 0)

	if hold_position and camera:
		var cam_forward := -camera.global_transform.basis.z
		# Project directly from the camera so it perfectly matches your crosshair
		hold_position.global_position = camera.global_position + cam_forward * hold_distance
		
	if hold_position:
		var target_pos := hold_position.global_position
		var current_pos := grabbed_object.global_position
		var distance_vec := target_pos - current_pos
		
		# Tweak these two variables to change the "weight" of the telekinesis
		var spring_strength := 15.0 # How aggressively it pulls to the center
		var damping := 8.0 # How much it resists swinging (prevents infinite oscillation)

		# Calculate the ideal velocity to reach the target
		var desired_vel := distance_vec * spring_strength

		# Smoothly lerp the actual velocity toward the desired velocity.
		# This respects collisions much better and creates a natural "lag" when moving the camera fast.
		grabbed_object.linear_velocity = grabbed_object.linear_velocity.lerp(desired_vel, damping * delta)
		
		# Smoothly dampen rotation so it stabilizes naturally instead of instantly freezing
		grabbed_object.angular_velocity = grabbed_object.angular_velocity.lerp(Vector3.ZERO, 6.0 * delta)

	# --- Head Look Logic ---
	if head_look and hold_position:
		var char_forward := -global_transform.basis.z
		var to_target := hold_position.global_position - global_position
		char_forward.y = 0
		to_target.y = 0
		char_forward = char_forward.normalized()
		to_target = to_target.normalized()

		var angle_to_target := rad_to_deg(char_forward.angle_to(to_target))
		head_look.active = angle_to_target <= max_head_look_angle


func _set_hold_blend(target_value: float) -> void:
	if not animation_tree:
		return

	if hold_tween and hold_tween.is_running():
		hold_tween.kill()

	hold_tween = create_tween()
	hold_tween.tween_property(animation_tree, "parameters/HoldBlend/blend_amount", target_value, 0.2)


func _travel_animation_state(state_name: String) -> void:
	if not animation_tree:
		return

	var state_machine = animation_tree.get("parameters/StateMachine/playback")
	if state_machine:
		state_machine.travel(state_name)


func _update_crosshair_state() -> void:
	if tele_ray and tele_ray.is_colliding() and tele_ray.get_collider() is RigidBody3D:
		Crosshair.set_state_can_interact()
	else:
		Crosshair.set_state_default()


func set_input_locked(locked: bool) -> void:
	is_input_locked = locked

	if locked:
		velocity.x = 0
		velocity.z = 0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func unlock_ability(ability_name: String) -> void:
	match ability_name.to_lower():
		"telekinesis":
			has_telekinesis_unlocked = true
			print("Telekinesis skill permanently unlocked!")


func _on_weapon_wheel_weapon_selected(ability_index: int) -> void:
	if not is_input_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	match ability_index:
		0:
			equip_ability(Ability.HOVER, icon_hover, "Hovering")
		1:
			equip_ability(Ability.TELEKINESIS, icon_telekinesis, "Telekinesis")
		2:
			equip_ability(Ability.PERSPECTIVE, icon_perspective, "2D / 3D Perspective")
		_:
			print("No ability selected (cursor was in the deadzone).")


func equip_ability(ability: Ability, icon: Texture2D, ability_name: String) -> void:
	current_ability = ability
	print("Equipped: " + ability_name)

	if active_ability_icon:
		active_ability_icon.texture = icon
		active_ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		active_ability_icon.custom_minimum_size = Vector2(64, 64)
		active_ability_icon.size = Vector2(64, 64)


func toggle_hover() -> void:
	is_hover_toggled = !is_hover_toggled
	print("Hover Mode: ON" if is_hover_toggled else "Hover Mode: OFF")


func toggle_perspective() -> void:
	is_3d_mode = !is_3d_mode
	
	if not is_3d_mode:
		print("Perspective: Switched to 2D")
		set_input_locked(true) # Lock 3D movement/camera while in 2D
	else:
		print("Perspective: Switched to 3D")
		set_input_locked(false)



#func _on_golem_talk_body_entered(body: Node3D) -> void:
	#pass # Replace with function body.
#
#
#func _on_golem_talk_body_exited(body: Node3D) -> void:
	#pass # Replace with function body.
