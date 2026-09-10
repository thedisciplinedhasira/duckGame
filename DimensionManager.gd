extends Node

@onready var video_player = $CanvasLayer/VideoStreamPlayer
@onready var world_3d: Node3D = $World3D
@onready var world_2d: Node2D = $World2D # Add an empty Node2D named World2D to your scene

@export var player_3d: CharacterBody3D

var active_gate = null
var current_2d_scene_instance: Node2D = null

var is_in_2d: bool = false
var is_transitioning: bool = false

func _ready():
	activate_3d()

func set_active_gate(gate):
	active_gate = gate

func clear_active_gate(gate):
	if active_gate == gate:
		active_gate = null

func _unhandled_input(event):
	if event.is_action_pressed("swap_dimension") and not is_transitioning:
		if not is_in_2d and active_gate and active_gate.target_2d_scene:
			execute_dimension_swap(true)
		elif is_in_2d:
			execute_dimension_swap(false)

func execute_dimension_swap(to_2d: bool):
	is_transitioning = true
	is_in_2d = to_2d

	if video_player:
		video_player.visible = true
		video_player.play()
		await video_player.finished

	if is_in_2d:
		# 1. Lock the 3D player using your custom script method
		if player_3d and player_3d.has_method("set_input_locked"):
			player_3d.set_input_locked(true)

		# 2. Spawn the 2D map
		current_2d_scene_instance = active_gate.target_2d_scene.instantiate()
		world_2d.add_child(current_2d_scene_instance)

		activate_2d()
		await get_tree().process_frame

		# 3. Handle 2D Camera
		var player_2d = get_tree().get_first_node_in_group("player_2d")
		if player_2d:
			var cam2d = player_2d.get_node_or_null("Camera2D")
			if cam2d:
				cam2d.make_current()
				cam2d.reset_smoothing()
	else:
		var target_marker = active_gate.return_3d_marker if active_gate else null
		
		activate_3d()

		# 1. Delete 2D Map
		if current_2d_scene_instance:
			current_2d_scene_instance.queue_free()
			current_2d_scene_instance = null

		await get_tree().process_frame

		# 2. Teleport & Unlock 3D Player
		if target_marker and player_3d:
			player_3d.global_position = target_marker.global_position
			player_3d.velocity = Vector3.ZERO
			
			if player_3d.has_method("set_input_locked"):
				player_3d.set_input_locked(false)
			
			# Target the specific camera path from your player script
			var cam3d = player_3d.get_node_or_null("cameraMount/Camera3D")
			if cam3d:
				cam3d.make_current()

	if video_player:
		video_player.visible = false

	is_transitioning = false

func activate_3d():
	world_3d.visible = true
	world_3d.process_mode = Node.PROCESS_MODE_INHERIT
	if world_2d:
		world_2d.visible = false
		world_2d.process_mode = Node.PROCESS_MODE_DISABLED

func activate_2d():
	if world_2d:
		world_2d.visible = true
		world_2d.process_mode = Node.PROCESS_MODE_INHERIT
	world_3d.visible = false
	world_3d.process_mode = Node.PROCESS_MODE_DISABLED
