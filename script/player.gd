extends CharacterBody3D

# input names live here so a typo is one fix, not a hunt
const ACT_SPRINT := &"sprint"
const ACT_HOVER := &"hover"
const ACT_GRAB := &"telekinesis_grab"
const ACT_THROW := &"telekinesis_throw"
const ACT_LEFT := &"move_left"
const ACT_RIGHT := &"move_right"
const ACT_FORWARD := &"move_forward"
const ACT_BACK := &"move_backward"

# paths and names used every frame
const SHADER_PLAYER_POS := &"player_position"
const BLEND_PATH := &"parameters/StateMachine/Movement/blend_position"
const STATE_MACHINE_PATH := &"parameters/StateMachine/playback"
const STATE_MOVEMENT := &"Movement"
const STATE_HOVERING := &"hovering"

# movement
const WALK_SPEED := 4.0
const RUN_SPEED := 9.0
const CARRY_SPEED := 4.0
const ACCEL := 15.0
const STOP_DECEL := 240.0
const ROTATION_SMOOTHING := 23.0

# gravity / hover
const GRAVITY_SCALE := 15.0
const FLOOR_SETTLE_RATE := 20.0
const HOVER_RAY_LIFT := 0.1
const HOVER_RAY_LENGTH := 10.0
const HOVER_SINK_SPEED := -2.0
const HOVER_SINK_RATE := 3.0

# hover audio loops on a timer so we never ask the audio server where it is
const HOVER_AUDIO_START := 5.0
const HOVER_AUDIO_LOOP_TIME := 25.0

# camera
const MAX_PITCH := deg_to_rad(89.0)
const FOV_HOVER := 85.0
const FOV_GRAB := 65.0
# skip camera rotation updates smaller than this (radians, about 0.006 degrees)
const ANGLE_EPSILON := 0.0001

# ui meters only get pushed once the value moved this fraction of the bar
const METER_UI_STEP := 0.01

# footsteps
const WALK_STEP_TIME := 0.4
const RUN_STEP_TIME := 0.25
const SUPER_RUN_STEP_TIME := 0.15

# telekinesis
const HOLD_ADJUST_SPEED := 6.0
const MIN_HOLD_DISTANCE := 1.5
const MAX_HOLD_DISTANCE := 25.0
const GRAB_MAX_DISTANCE := 15.0
const ANGULAR_DAMP_RATE := 6.0

# micro duck settings
const NORMAL_SCALE := Vector3(1.0, 1.0, 1.0)
const MICRO_SPEED_MULT := 0.4
const MICRO_CEILING_CHECK := 1.5
# near plane never goes below this, smaller than this costs depth precision
const MICRO_NEAR_MIN := 0.01

# death
const DEATH_FADE_IN := 1.0
const DEATH_FADE_OUT := 0.5

@export var mouse_sensitivity := 0.002
@export var pull_strength := 15.0
@export var pull_damping := 8.0
@export var throw_strength: float = 20.0

@export_category("Sprint Settings")
@export var super_run_speed := 9.0
@export var super_sprint_delay := 0.5
@export var super_sprint_fov := 90.0

@export_category("Stamina Settings")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0
@export var stamina_regen_rate: float = 30.0
@export var stamina_regen_delay: float = 1.5

@export_category("Ability Settings")
@export var max_ability_charges: float = 6.0
@export var ability_drain_rate: float = 1.5 # Dots drained per second of active use
@export var ability_regen_rate: float = 1.0 # Dots recovered per second
@export var ability_regen_delay: float = 1.0 # Delay before dots start refilling

@export_category("Micro Settings")
# how small the duck gets, 0.2 is a fifth of normal size
@export_range(0.05, 1.0, 0.01) var micro_size: float = 0.2
# 1.0 is true to scale, lower it to drop the camera even further
@export_range(0.1, 1.0, 0.05) var micro_camera_height_mult: float = 1.0
# wide lens while tiny so the world feels huge
@export_range(60.0, 120.0, 1.0) var micro_fov: float = 100.0

@export_category("Telekinesis Settings")
# cosine is cached in the setter so we dont call cos() every frame while holding
@export_range(30.0, 120.0) var max_head_look_angle: float = 75.0:
	set(value):
		max_head_look_angle = value
		head_look_cos = cos(deg_to_rad(value))

@export_category("Hover Settings")
@export var hover_target_height := 1.1
@export var hover_spring_strength := 18.0
@export var hover_damping := 5.0
# narrow this to just your ground layers, the ray then skips everything else
@export_flags_3d_physics var hover_ray_mask: int = 0xFFFFFFFF

@export_group("Ability Icons")
@export var icon_hover: Texture2D
@export var icon_perspective: Texture2D
@export var icon_telekinesis: Texture2D
@export var icon_micro: Texture2D

@export_category("Death Settings")
@export var death_images: Array[Texture2D]
@export var death_layer: CanvasLayer
@export var death_background: ColorRect
@export var death_texture: TextureRect
@export var respawn_button: Button
@export var quit_button: Button
@export var death_sound: AudioStreamPlayer

@onready var hover_audio: AudioStreamPlayer3D = $HoverAudio
@onready var ambient_sound: AudioStreamPlayer = $AmbientSound
@onready var theme_song: AudioStreamPlayer = $ThemeSong
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_mount: Node3D = $cameraMount
@onready var camera: Camera3D = $cameraMount/Camera3D
@onready var tele_ray: RayCast3D = $cameraMount/Camera3D/TelekinesisRay
@onready var hold_position: Marker3D = $cameraMount/Camera3D/HoldPosition
@onready var footstep_dust: GPUParticles3D = $FootStepsDust
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var tornado_vfx: Node3D = $tornadoVFX
@onready var telekinesis_vfx: GPUParticles3D = $cameraMount/Camera3D/HoldPosition/TelekinesisVFX
@onready var head_look: LookAtModifier3D = %LookAtModifier3D
@onready var active_ability_icon: TextureRect = $HUD/ActiveAbilityIcon
@onready var ability_meter: AbilityMeter = $WeaponWheel/AbilityMeter

# lives outside the player scene so this one stays optional
@onready var speedline: ColorRect = $"../speedline"

enum Ability { NONE, HOVER, PERSPECTIVE, TELEKINESIS, MICRO }
var current_ability: Ability = Ability.NONE

# camera
var target_yaw := 0.0
var target_pitch := 0.0
var applied_pitch := INF
var camera_offset := Vector3.ZERO
var base_camera_offset := Vector3.ZERO
var last_camera_pos := Vector3.INF
var default_fov := 75.0
var target_fov := 75.0
var fov_tween: Tween

# input and unlock flags
var is_input_locked := false
var has_telekinesis_unlocked := false

# movement and animation
var current_blend_position := Vector2.ZERO
var current_anim_state: StringName = STATE_MOVEMENT
var state_machine: AnimationNodeStateMachinePlayback
var footstep_timer := 0.0

# sprint and stamina
var sprint_timer := 0.0
var is_super_sprinting := false
var current_sprint_speed := RUN_SPEED
var current_stamina: float = 100.0
var regen_delay_timer := 0.0
var last_stamina_sent := -1.0

# ability charges
var current_ability_charges: float = max_ability_charges
var ability_regen_timer := 0.0
var last_ability_sent := -1.0
var is_ability_exhausted := false

# hover
var is_hovering := false
var was_hovering := false
var is_hover_toggled := false
var is_3d_mode := true
var hover_ray: RayCast3D
var hover_audio_timer := 0.0

# telekinesis
var grabbed_object: RigidBody3D = null
var hold_distance := 3.0
var hold_tween: Tween
var crosshair_interactable := false
var head_look_cos := 0.0

# micro duck
var is_micro := false
var micro_tween: Tween
var ceiling_ray: RayCast3D
var base_camera_local := Vector3.ZERO
var base_camera_near := 0.05

# one number drives the mount offset, the camera's own offset and the near plane
# the mount is top_level so it ignores our scale, the camera inside it needs shrinking too
var camera_scale := 1.0:
	set(value):
		camera_scale = value
		camera_offset = base_camera_offset * value
		camera.position = base_camera_local * value
		camera.near = maxf(base_camera_near * value, minf(base_camera_near, MICRO_NEAR_MIN))

# shader param cache
var last_shader_pos := Vector3.INF

# collectibles
var potions_in_inventory := 0
var magic_feathers_collected := 0

# death
var death_count: int = 0
var is_dead := false
var current_respawn_pos: Vector3 = Vector3.ZERO
var death_tween: Tween


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_yaw = rotation.y
	target_pitch = camera.rotation.x
	default_fov = camera.fov
	target_fov = default_fov

	current_ability_charges = max_ability_charges
	head_look_cos = cos(deg_to_rad(max_head_look_angle))

	animation_tree.active = true
	head_look.active = false
	tornado_vfx.visible = false
	telekinesis_vfx.emitting = false
	if speedline:
		speedline.visible = false

	camera_offset = camera_mount.position
	base_camera_offset = camera_offset
	# remember the camera's own local values so micro can scale them
	base_camera_local = camera.position
	base_camera_near = camera.near
	camera_mount.top_level = true

	# ray is built here in code so the scene doesnt need a new node
	# it stays disabled and only fires when we force it while hovering
	hover_ray = RayCast3D.new()
	hover_ray.enabled = false
	hover_ray.position = Vector3(0.0, HOVER_RAY_LIFT, 0.0)
	hover_ray.target_position = Vector3(0.0, -HOVER_RAY_LENGTH, 0.0)
	hover_ray.collision_mask = hover_ray_mask
	add_child(hover_ray)

	# micro-duck ceiling check ray
	ceiling_ray = RayCast3D.new()
	ceiling_ray.enabled = false
	ceiling_ray.position = Vector3(0.0, 0.1, 0.0)
	ceiling_ray.collision_mask = hover_ray_mask
	add_child(ceiling_ray)

	# telekinesis ray only casts while that ability is equipped
	tele_ray.enabled = false
	# icon setup only needs to happen once,
	active_ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_ability_icon.custom_minimum_size = Vector2(64, 64)
	active_ability_icon.size = Vector2(64, 64)

	if not ambient_sound.playing:
		ambient_sound.play()
	if not theme_song.playing:
		theme_song.play()

	if death_layer and death_background:
		death_layer.visible = false
		death_background.modulate.a = 0.0
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	_follow_camera()


func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked:
		return

	var motion := event as InputEventMouseMotion
	if motion:
		_handle_look_input(motion)
		return

	if event.is_action_pressed(&"ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed(ACT_THROW) and grabbed_object and current_ability == Ability.TELEKINESIS:
		throw_object()

	if event.is_action_pressed(ACT_GRAB) and current_ability == Ability.MICRO:
		toggle_micro_size()


# gameplay and physics only, this can run several times per frame when fps drops
func _physics_process(delta: float) -> void:
	# check for exhaustion before allowing hover
	is_hovering = current_ability == Ability.HOVER and Input.is_action_pressed(ACT_HOVER) and not is_ability_exhausted

	_update_ability_charges(delta)

	if is_input_locked:
		_apply_gravity(delta)
		move_and_slide()
		return

	_validate_grab()
	_apply_gravity(delta)
	_handle_grab_input()
	_handle_hold_distance_input(delta)
	_handle_movement(delta)
	_handle_hover_state(delta)
	process_telekinesis(delta)
	move_and_slide()


# visuals and ui, this runs exactly once per drawn frame
func _process(delta: float) -> void:
	_follow_camera()
	_push_player_position()
	_sync_meters()
	
	if is_input_locked:
		return

	_handle_look_rotation(delta)
	_update_fov()
	_update_crosshair()
	if grabbed_object:
		_update_head_look()


# ---------- helpers ----------

func _smooth(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)

func _fresh_tween(old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	return create_tween()

func _push_player_position() -> void:
	if global_position == last_shader_pos:
		return
	last_shader_pos = global_position
	RenderingServer.global_shader_parameter_set(SHADER_PLAYER_POS, global_position)

# setting a transform wakes up every child (camera, rays, vfx) so only do it on change
func _follow_camera() -> void:
	var target := global_position + camera_offset
	if target == last_camera_pos:
		return
	last_camera_pos = target
	camera_mount.global_position = target


# ---------- look ----------

func _handle_look_input(event: InputEventMouseMotion) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	target_yaw -= event.relative.x * mouse_sensitivity
	target_pitch = clampf(target_pitch - event.relative.y * mouse_sensitivity, -MAX_PITCH, MAX_PITCH)

func _handle_look_rotation(delta: float) -> void:
	var yaw := camera_mount.rotation.y
	if absf(angle_difference(yaw, target_yaw)) > ANGLE_EPSILON:
		camera_mount.rotation.y = lerp_angle(yaw, target_yaw, _smooth(ROTATION_SMOOTHING, delta))

	# compare against our own float, reading rotation.x back is never exactly equal
	if target_pitch != applied_pitch:
		applied_pitch = target_pitch
		camera.rotation.x = target_pitch

func _update_fov() -> void:
	if grabbed_object:
		_set_target_fov(FOV_GRAB, 0.2)
	elif is_hovering:
		_set_target_fov(FOV_HOVER, 0.3)
	elif is_micro:
		_set_target_fov(micro_fov, 0.3)
	elif is_super_sprinting:
		_set_target_fov(super_sprint_fov, 0.4)
	else:
		_set_target_fov(default_fov, 0.3)

func _set_target_fov(fov: float, duration: float) -> void:
	if is_equal_approx(fov, target_fov):
		return
	target_fov = fov
	fov_tween = _fresh_tween(fov_tween)
	fov_tween.tween_property(camera, "fov", fov, duration).set_trans(Tween.TRANS_SINE)


# ---------- gravity and hover ----------

func _apply_gravity(delta: float) -> void:
	if is_hovering:
		_apply_hover_spring(delta)
	elif not is_on_floor():
		velocity += get_gravity() * GRAVITY_SCALE * delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, FLOOR_SETTLE_RATE * delta)

func _apply_hover_spring(delta: float) -> void:
	# forced cast on a disabled ray gives fresh results without building a dictionary
	hover_ray.force_raycast_update()

	if not hover_ray.is_colliding():
		velocity.y = lerpf(velocity.y, HOVER_SINK_SPEED, _smooth(HOVER_SINK_RATE, delta))
		return
	# read the ray's real position, its lift shrinks with us while micro
	var ray_origin_y := hover_ray.global_position.y
	var height_error := hover_target_height - (ray_origin_y - hover_ray.get_collision_point().y)
	var spring_force := height_error * hover_spring_strength
	var damp_force := -velocity.y * hover_damping
	velocity.y += (spring_force + damp_force) * delta
	
func _handle_hover_state(delta: float) -> void:
	if is_hovering != was_hovering:
		was_hovering = is_hovering
		tornado_vfx.visible = is_hovering
		if not is_hovering:
			hover_audio.stop()

	if is_hovering:
		hover_audio_timer += delta
		if not hover_audio.playing or hover_audio_timer >= HOVER_AUDIO_LOOP_TIME:
			hover_audio_timer = 0.0
			hover_audio.play(HOVER_AUDIO_START)

	var target_state := STATE_HOVERING if (not is_on_floor() or is_hovering) else STATE_MOVEMENT
	if current_anim_state != target_state:
		current_anim_state = target_state
		_travel_animation_state(target_state)


# ---------- abilities and stamina ----------

func _update_ability_charges(delta: float) -> void:
	var is_using_ability := is_hovering or grabbed_object != null

	if is_using_ability:
		current_ability_charges -= ability_drain_rate * delta
		ability_regen_timer = ability_regen_delay

		# force drop if energy runs out and trigger exhaustion
		if current_ability_charges <= 0.0:
			current_ability_charges = 0.0
			is_ability_exhausted = true
			is_hovering = false
			if grabbed_object:
				release_object()
	else:
		if ability_regen_timer > 0.0:
			ability_regen_timer -= delta
		elif current_ability_charges < max_ability_charges:
			current_ability_charges = minf(max_ability_charges, current_ability_charges + ability_regen_rate * delta)

			# require at least 1 full dot before abilities can be used again
			if current_ability_charges >= 1.0:
				is_ability_exhausted = false

# meters are pushed from _process, and only when the bar would visibly change
func _sync_meters() -> void:
	if ability_meter == null:
		return

	if _meter_changed(current_stamina, last_stamina_sent, max_stamina):
		last_stamina_sent = current_stamina
		ability_meter.update_stamina(current_stamina, max_stamina)

	if _meter_changed(current_ability_charges, last_ability_sent, max_ability_charges):
		last_ability_sent = current_ability_charges
		ability_meter.update_ability(current_ability_charges, max_ability_charges)
		

func _meter_changed(value: float, last: float, max_value: float) -> bool:
	if value == last:
		return false
	# always send the end points so a bar never stops just short of full or empty
	if value <= 0.0 or value >= max_value:
		return true
	return absf(value - last) >= max_value * METER_UI_STEP

func _handle_movement(delta: float) -> void:
	var direction := _get_move_direction()
	var is_moving := direction != Vector3.ZERO
	var wants_sprint := (
		Input.is_action_pressed(ACT_SPRINT)
		and is_moving
		and not grabbed_object
		and not is_micro
		and is_on_floor()
		and current_stamina > 0.0
	)

	_update_stamina(delta, wants_sprint)
	_update_sprint_speed(delta)
	_apply_horizontal_velocity(direction, wants_sprint, delta)
	_update_footsteps(delta, is_moving)

func _get_move_direction() -> Vector3:
	var input_dir := Input.get_vector(ACT_LEFT, ACT_RIGHT, ACT_FORWARD, ACT_BACK)
	# no input means no basis multiply and no normalize
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var direction := camera_mount.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	return direction.normalized()

func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		sprint_timer += delta
		current_stamina = maxf(0.0, current_stamina - stamina_drain_rate * delta)
		regen_delay_timer = stamina_regen_delay
	else:
		sprint_timer = 0.0
		if regen_delay_timer > 0.0:
			regen_delay_timer -= delta
		elif current_stamina < max_stamina:
			current_stamina = minf(max_stamina, current_stamina + stamina_regen_rate * delta)

	_set_super_sprinting(sprinting and sprint_timer >= super_sprint_delay)

func _set_super_sprinting(value: bool) -> void:
	if value == is_super_sprinting:
		return
	is_super_sprinting = value
	if speedline:
		speedline.visible = value

func _update_sprint_speed(delta: float) -> void:
	var target := super_run_speed if is_super_sprinting else RUN_SPEED
	var rate := 10.0 if is_super_sprinting else 15.0
	current_sprint_speed = move_toward(current_sprint_speed, target, rate * delta)
	
func _get_move_speed(sprinting: bool) -> float:
	var speed := WALK_SPEED

	if grabbed_object:
		speed = CARRY_SPEED
	elif sprinting:
		speed = current_sprint_speed

	if is_micro:
		speed *= MICRO_SPEED_MULT

	return speed

func _apply_horizontal_velocity(direction: Vector3, sprinting: bool, delta: float) -> void:
	var target_blend := Vector2.ZERO

	if direction != Vector3.ZERO:
		var target_angle := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, _smooth(ROTATION_SMOOTHING, delta))

		var speed := _get_move_speed(sprinting)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		target_blend = Vector2(0.0, speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, STOP_DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, STOP_DECEL * delta)

	var new_blend := current_blend_position.move_toward(target_blend, ACCEL * delta)
	if new_blend != current_blend_position:
		current_blend_position = new_blend
		animation_tree.set(BLEND_PATH, new_blend)

func _update_footsteps(delta: float, is_moving: bool) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_running := Input.is_action_pressed(ACT_SPRINT) and horizontal_speed > WALK_SPEED + 1.0
	var grounded := is_on_floor() and not is_hovering
	
	var want_dust := is_running and grounded
	if footstep_dust.emitting != want_dust:
		footstep_dust.emitting = want_dust

	if is_moving and grounded:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.play()
			if is_super_sprinting:
				footstep_timer = SUPER_RUN_STEP_TIME
			elif is_running:
				footstep_timer = RUN_STEP_TIME
			else:
				footstep_timer = WALK_STEP_TIME
	else:
		footstep_timer = 0.0
	
# ---------- telekinesis ----------

func _handle_grab_input() -> void:
	if current_ability != Ability.TELEKINESIS:
		return

	if Input.is_action_just_pressed(ACT_GRAB) and not grabbed_object:
		try_grab_object()
	if Input.is_action_just_released(ACT_GRAB) and grabbed_object:
		release_object()

func _handle_hold_distance_input(delta: float) -> void:
	if not grabbed_object:
		return

	var axis := int(Input.is_key_pressed(KEY_E)) - int(Input.is_key_pressed(KEY_Q))
	if axis != 0:
		_set_hold_distance(hold_distance + axis * HOLD_ADJUST_SPEED * delta)

func _set_hold_distance(distance: float) -> void:
	hold_distance = clampf(distance, MIN_HOLD_DISTANCE, MAX_HOLD_DISTANCE)
	hold_position.position = Vector3(0.0, 0.0, -hold_distance)

func _validate_grab() -> void:
	if grabbed_object and not is_instance_valid(grabbed_object):
		grabbed_object = null
		_end_grab_visuals()
		

func try_grab_object() -> void:
	# cannot grab with no ability energy
	if is_ability_exhausted or current_ability_charges <= 0.0:
		return
	if not tele_ray.is_colliding():
		return

	var body := tele_ray.get_collider() as RigidBody3D
	if body == null:
		return

	grabbed_object = body
	body.angular_velocity = Vector3(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
	body.gravity_scale = 0.0

	var grab_distance := camera.global_position.distance_to(tele_ray.get_collision_point())
	_set_hold_distance(minf(grab_distance, GRAB_MAX_DISTANCE))
	_set_hold_blend(1.0)

	telekinesis_vfx.emitting = true
	telekinesis_vfx.restart()
	head_look.target_node = hold_position.get_path()

func release_object() -> void:
	if grabbed_object:
		grabbed_object.gravity_scale = 1.0
		grabbed_object.linear_velocity = Vector3.ZERO
		grabbed_object.angular_velocity = Vector3.ZERO
		grabbed_object = null

	_end_grab_visuals()

func throw_object() -> void:
	if not grabbed_object:
		return

	grabbed_object.gravity_scale = 1.0
	grabbed_object.linear_velocity = -camera.global_transform.basis.z * throw_strength

	grabbed_object = null
	_end_grab_visuals()

	current_anim_state = STATE_MOVEMENT
	_travel_animation_state(STATE_MOVEMENT)

func _end_grab_visuals() -> void:
	_set_hold_blend(0.0)
	telekinesis_vfx.emitting = false
	head_look.active = false
	head_look.target_node = NodePath("")

# force only, head look is handled in _process
func process_telekinesis(delta: float) -> void:
	if not grabbed_object:
		return

	var to_target := hold_position.global_position - grabbed_object.global_position
	var desired_vel := to_target * pull_strength

	grabbed_object.linear_velocity = grabbed_object.linear_velocity.lerp(desired_vel, _smooth(pull_damping, delta))
	grabbed_object.angular_velocity = grabbed_object.angular_velocity.lerp(Vector3.ZERO, _smooth(ANGULAR_DAMP_RATE, delta))
	
func _update_head_look() -> void:
	var forward := -global_transform.basis.z
	var to_target := hold_position.global_position - global_position
	forward.y = 0.0
	to_target.y = 0.0

	head_look.active = forward.normalized().dot(to_target.normalized()) >= head_look_cos
	
func _set_hold_blend(target_value: float) -> void:
	hold_tween = _fresh_tween(hold_tween)
	hold_tween.tween_property(animation_tree, "parameters/HoldBlend/blend_amount", target_value, 0.2)	

func _travel_animation_state(state_name: StringName) -> void:
	if state_machine == null:
		state_machine = animation_tree.get(STATE_MACHINE_PATH)
	if state_machine:
		state_machine.travel(state_name)

func _update_crosshair() -> void:
	var can_interact := (
		current_ability == Ability.TELEKINESIS
		and tele_ray.is_colliding()
		and tele_ray.get_collider() is RigidBody3D
		and not is_ability_exhausted
	)

	if can_interact == crosshair_interactable:
		return
	crosshair_interactable = can_interact
	if can_interact:
		Crosshair.set_state_can_interact()
	else:
		Crosshair.set_state_default()
	

# ---------- public api ----------

func set_input_locked(locked: bool) -> void:
	is_input_locked = locked

	if locked:
		velocity.x = 0.0
		velocity.z = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Crosshair.set_state_default()
		crosshair_interactable = false
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
			equip_ability(Ability.MICRO, icon_micro, "Micro-Duck")
		_:
			print("No ability selected (cursor was in the deadzone).")


func equip_ability(ability: Ability, icon: Texture2D, ability_name: String) -> void:
	if ability != Ability.TELEKINESIS and grabbed_object:
		release_object()

	current_ability = ability
	print("Equipped: " + ability_name)

	# the ray only needs to cast while telekinesis is the active ability
	tele_ray.enabled = ability == Ability.TELEKINESIS

	ability_meter.set_ability_icon(icon)
	active_ability_icon.texture = icon


func toggle_hover() -> void:
	is_hover_toggled = !is_hover_toggled
	print("Hover Mode: ON" if is_hover_toggled else "Hover Mode: OFF")


func toggle_perspective() -> void:
	is_3d_mode = !is_3d_mode

	if not is_3d_mode:
		print("Perspective: Switched to 2D")
		set_input_locked(true)
	else:
		print("Perspective: Switched to 3D")
		set_input_locked(false)


func toggle_micro_size() -> void:
	if is_micro:
		# divide target by our scale so we check true world height while shrunk
		ceiling_ray.target_position = Vector3(0.0, MICRO_CEILING_CHECK / scale.y, 0.0)
		ceiling_ray.force_raycast_update()

		if ceiling_ray.is_colliding():
			print("Ceiling too low! The duck cannot un-shrink here.")
			return

	is_micro = !is_micro
	var target_scale := Vector3.ONE * micro_size if is_micro else NORMAL_SCALE
	var target_cam := micro_size * micro_camera_height_mult if is_micro else 1.0

	micro_tween = _fresh_tween(micro_tween)

	# body scale and camera rig tween together
	micro_tween.tween_property(self, "scale", target_scale, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	micro_tween.parallel().tween_property(self, "camera_scale", target_cam, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("Micro-Duck Mode: ON" if is_micro else "Micro-Duck Mode: OFF")


func _on_dialogue_trigger_body_exited(_body: Node3D) -> void:
	pass

func _on_dialogue_trigger_body_entered(_body: Node3D) -> void:
	pass

func _on_kimem_body_entered(_body: Node3D) -> void:
	pass


# ---------- death ----------

func die(respawn_pos: Vector3) -> void:
	if is_dead:
		return

	is_dead = true
	set_input_locked(true)
	current_respawn_pos = respawn_pos

	if grabbed_object:
		release_object()

	is_hover_toggled = false
	if is_micro:
		# kill the tween first so it cant shrink us again after respawn
		if micro_tween and micro_tween.is_valid():
			micro_tween.kill()
		scale = NORMAL_SCALE
		camera_scale = 1.0
		is_micro = false

	if death_sound:
		death_sound.play()

	if death_texture and not death_images.is_empty():
		death_texture.texture = death_images[death_count % death_images.size()]
	death_count += 1

	if death_layer and death_background:
		death_layer.visible = true
		death_tween = _fresh_tween(death_tween)
		death_tween.tween_property(death_background, "modulate:a", 1.0, DEATH_FADE_IN).set_trans(Tween.TRANS_SINE)


func _on_respawn_pressed() -> void:
	if not is_dead:
		return

	if death_layer and death_background:
		death_tween = _fresh_tween(death_tween)
		death_tween.tween_property(death_background, "modulate:a", 0.0, DEATH_FADE_OUT).set_trans(Tween.TRANS_SINE)
		death_tween.tween_callback(death_layer.hide)

	global_position = current_respawn_pos
	velocity = Vector3.ZERO
	is_dead = false
	set_input_locked(false)

func _on_quit_pressed() -> void:
	get_tree().quit()
