extends Node

# --- UI & Video References ---
@onready var video_player = $CanvasLayer/VideoStreamPlayer

# --- World References ---
@onready var world_3d: Node3D = $World3D
@onready var world_2d: Node2D = $tutorial2D 

# --- Player References ---
@export var player_3d: CharacterBody3D
@export var player_2d: CharacterBody2D

# --- Spawn Markers ---
@export var spawn_3d_marker: Marker3D 
@export var tutorial_gate_3d_marker: Marker3D # <-- Marker in front of 3D gate
@export var tutorial_spawn_3d_marker: Marker3D # <-- Marker on the hill (Exit)

# --- Exit Triggers & Puzzles ---
@export var tutorial_boost_box_2d: StaticBody2D 

# --- State Variables ---
var use_tutorial_spawn: bool = false
var use_tutorial_gate_spawn: bool = false
var can_swap_to_2d: bool = false 

var spawn_2d_pos: Vector2 
var is_in_2d: bool = false
var is_transitioning: bool = false 
var can_switch_to_3d: bool = false 
var is_boost_box_placed: bool = false 

func _ready():
	if player_2d:
		spawn_2d_pos = player_2d.global_position
		
	activate_3d()

func _unhandled_input(event):
	if event.is_action_pressed("swap_dimension"):
		if not is_transitioning:
			if not is_in_2d and can_swap_to_2d:
				execute_dimension_swap()
			elif is_in_2d and can_switch_to_3d:
				execute_dimension_swap()
				
func execute_dimension_swap():
	is_transitioning = true
	is_in_2d = !is_in_2d

	if is_in_2d:
		can_switch_to_3d = false 
		
	if video_player:
		video_player.visible = true
		video_player.play()
		await video_player.finished
	
	if is_in_2d:
		activate_2d()
		await get_tree().process_frame
		
# 3. Now it is safe to teleport the player
		if player_2d:
			player_2d.global_position = spawn_2d_pos
			player_2d.velocity = Vector2.ZERO
			
			var cam2d = player_2d.get_node_or_null("Camera2D") 
			if cam2d:
				cam2d.make_current()
				cam2d.reset_smoothing() # <-- THE MAGIC TELEPORT FIX!
				
			# --- THE GHOST CAMERA TEST ---
			# Let's ask the engine EXACTLY which camera is in control
			var active_cam = get_viewport().get_camera_2d()
			if active_cam:
				print(">>> REAL ACTIVE CAMERA IS: ", active_cam.get_path())
			else:
				print(">>> WARNING: NO 2D CAMERA IS ACTIVE!")
								
	else:
		# 1. Grab the correct marker BEFORE we turn off the 2D world!
		var target_marker = spawn_3d_marker # Default fallback
		
		if use_tutorial_spawn:
			target_marker = tutorial_spawn_3d_marker
		elif use_tutorial_gate_spawn:
			target_marker = tutorial_gate_3d_marker
			
		# 2. Waking up 3D first (This triggers the 2D body_exited signal)
		activate_3d()
		await get_tree().process_frame
		
		# 3. Teleport using the marker we safely saved in step 1
		if target_marker and player_3d:
			player_3d.global_position = target_marker.global_position
			player_3d.velocity = Vector3.ZERO 
			player_3d.set_input_locked(false)
			
			var cam3d = player_3d.get_node_or_null("Camera3D") 
			if cam3d:
				cam3d.make_current()
			
		# 4. Safely reset the triggers for the next swap
		use_tutorial_spawn = false 
		use_tutorial_gate_spawn = false 
		
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
