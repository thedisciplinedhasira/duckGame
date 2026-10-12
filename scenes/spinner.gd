extends Node3D

# floats near the player but is not attached, only chases a point near them
# reads player state, the player never knows this exists

@export var player: CharacterBody3D
@export var spinner: Node3D
@export var light: OmniLight3D
# drag emblem_comic.gdshader here, every Sprite3D under this node gets it
@export var emblem_shader: Shader

@export_category("Follow")
# offset is measured in camera yaw space, +x is screen right
@export var side_offset := 0.9
@export var height := 2.3
# sideways follow, lower is floatier
@export var follow_rate := 6.0
# up and down follow, higher keeps it level with you while hovering
@export var follow_rate_y := 20.0
@export var face_rate := 4.0
@export var bob_height := 0.1
@export var bob_speed := 2.0
# also tilts with the camera pitch, off keeps it upright
@export var match_pitch := false

@export_category("Spin")
# local axis the ring turns around, z is the axis pointing out of the face
@export var spin_axis := Vector3.BACK
# all spins are radians per second, 6.28 is one full turn per second
@export var idle_spin := 0.5
# spin at full run speed, walking lands somewhere between idle and this
@export var run_spin := 3.0
@export var super_spin := 6.0
# spin while an ability is active, the highest applicable one wins
@export var hover_spin := 4.0
@export var telekinesis_spin := 5.0
@export var micro_spin := 3.5
# how fast the spin ramps toward its target, higher snaps quicker
@export var spin_response := 5.0
# speed that counts as full run for the spin blend
@export var run_speed_ref := 9.0

@export_category("Glow")
# fed to the shader, 1.0 is normal gold, above 1.0 blooms and grows the halo
@export var glow_idle := 1.0
@export var glow_run := 1.3
@export var glow_super := 2.2
@export var light_idle := 0.6
@export var light_super := 2.5
@export var glow_response := 5.0

# if the player teleports (respawn) snap instead of drifting across the map
const TELEPORT_DISTANCE := 20.0

var sprites: Array[Sprite3D] = []
var mats: Array[ShaderMaterial] = []
var last_glow := -1.0
var spin := 0.0
var glow := 1.0
var bob_time := 0.0
# the scale you set in the editor, we multiply by it instead of overwriting it
var base_scale := Vector3.ONE
# false until the first frame where the player is ready
var placed := false


func _ready() -> void:
	# grab the editor scale before anything else touches the transform
	base_scale = scale

	top_level = true
	# run after the player and camera have moved this frame
	process_priority = 100

	spin = idle_spin
	spin_axis = spin_axis.normalized()
	_collect_sprites(self)
	# no player access here, children get ready before the player does


func _process(delta: float) -> void:
	if player == null or player.camera_mount == null:
		return

	# first frame, snap to the target instead of drifting in from the origin
	if not placed:
		placed = true
		global_position = _target_position()

	_follow(delta)
	_update_spin(delta)
	_update_glow(delta)


func _smooth(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _camera_yaw() -> float:
	if player == null or player.camera_mount == null:
		return 0.0
	return player.camera_mount.rotation.y

func _target_position() -> Vector3:
	var yaw_basis := Basis(Vector3.UP, _camera_yaw())
	# player.scale.y makes the offset shrink with micro duck
	var s := player.scale.y
	var offset := yaw_basis * Vector3(side_offset, height, 0.0) * s
	return player.global_position + offset


func _follow(delta: float) -> void:
	bob_time += delta
	var target := _target_position()
	target.y += sin(bob_time * bob_speed) * bob_height * player.scale.y

	if global_position.distance_to(target) > TELEPORT_DISTANCE:
		global_position = target
	else:
		# vertical gets its own faster rate so rising while hovering doesnt leave it behind
		var t_flat := _smooth(follow_rate, delta)
		var t_up := _smooth(follow_rate_y, delta)
		var pos := global_position
		global_position = Vector3(
			lerpf(pos.x, target.x, t_flat),
			lerpf(pos.y, target.y, t_up),
			lerpf(pos.z, target.z, t_flat)
		)

	# turn to match the camera so the face of the emblem always points at the player
	rotation.y = lerp_angle(rotation.y, _camera_yaw(), _smooth(face_rate, delta))
	if match_pitch:
		rotation.x = lerp_angle(rotation.x, player.camera.rotation.x, _smooth(face_rate, delta))
	scale = base_scale * player.scale.y


func _movement_amount() -> float:
	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	return clampf(h_speed / run_speed_ref, 0.0, 1.0)

func _target_spin() -> float:
	var target := lerpf(idle_spin, run_spin, _movement_amount())
	if player.is_super_sprinting:
		target = maxf(target, super_spin)
	# abilities only ever raise the spin, never lower it
	if player.is_hovering:
		target = maxf(target, hover_spin)
	if player.grabbed_object != null:
		target = maxf(target, telekinesis_spin)
	if player.is_micro:
		target = maxf(target, micro_spin)
	return target

func _update_spin(delta: float) -> void:
	# ease toward the target speed so it ramps up instead of snapping
	spin = lerpf(spin, _target_spin(), _smooth(spin_response, delta))
	if spinner:
		spinner.rotate_object_local(spin_axis, spin * delta)


func _update_glow(delta: float) -> void:
	var target_glow := lerpf(glow_idle, glow_run, _movement_amount())
	var target_light := light_idle
	if player.is_super_sprinting:
		target_glow = glow_super
		target_light = light_super

	var t := _smooth(glow_response, delta)
	glow = lerpf(glow, target_glow, t)

	# only touch the materials when the value actually moved
	if not is_equal_approx(glow, last_glow):
		last_glow = glow
		if mats.is_empty():
			# no shader assigned, fall back to plain modulate
			for s in sprites:
				s.modulate = Color(glow, glow, glow)
		else:
			for m in mats:
				m.set_shader_parameter(&"glow", glow)

	if light:
		light.light_energy = lerpf(light.light_energy, target_light, t)


# grabs every Sprite3D under this node and gives it its own comic material
# new layers get the look without any wiring
func _collect_sprites(node: Node) -> void:
	var sprite := node as Sprite3D
	if sprite:
		sprites.append(sprite)
		if emblem_shader and sprite.texture:
			var mat := ShaderMaterial.new()
			mat.shader = emblem_shader
			mat.set_shader_parameter(&"tex", sprite.texture)
			sprite.material_override = mat
			mats.append(mat)
	for child in node.get_children():
		_collect_sprites(child)
