extends Node

@export_category("Scene Targets")
@export_file("*.tscn", "*.scn") var target_2d_scene_path: String
@export_file("*.tscn", "*.scn") var target_3d_scene_path: String

@export_category("Transition Settings")
@export_file("*.ogv") var video_file_path: String 
@export var interact_action: String = "dimension_swap"

var prompt_label: Node = null # Generic Node can hold both Label and Label3D
var player_inside: bool = false
var is_transitioning: bool = false
var video_player: VideoStreamPlayer = null
var active_scene_path: String = "" 
var parent_area: Node = null

func _ready() -> void:
	parent_area = get_parent()
	
	# Dynamically search for any node with "Label" in its name (works for 2D and 3D)
	prompt_label = parent_area.find_child("*Label*", true, false)
	if prompt_label and "visible" in prompt_label:
		prompt_label.visible = false
		
	# Connect to the parent area's signals regardless of its dimension
	if parent_area.has_signal("body_entered"):
		parent_area.body_entered.connect(_on_body_entered)
	if parent_area.has_signal("body_exited"):
		parent_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and not is_transitioning and event.is_action_pressed(interact_action):
		start_transition()

func start_transition() -> void:
	is_transitioning = true
	if prompt_label and "visible" in prompt_label:
		prompt_label.visible = false
		
	if target_2d_scene_path != "":
		active_scene_path = target_2d_scene_path
	elif target_3d_scene_path != "":
		active_scene_path = target_3d_scene_path
		
	if active_scene_path != "":
		ResourceLoader.load_threaded_request(active_scene_path)
		
	if video_file_path != "":
		play_fullscreen_video()
	else:
		finish_transition()

func play_fullscreen_video() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	add_child(canvas)
	
	video_player = VideoStreamPlayer.new()
	video_player.expand = true 
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT) 
	canvas.add_child(video_player)
	
	var video_stream = load(video_file_path) as VideoStream
	video_player.stream = video_stream
	video_player.finished.connect(finish_transition)
	video_player.play()

func finish_transition() -> void:
	if active_scene_path != "":
		var load_status = ResourceLoader.load_threaded_get_status(active_scene_path)
		while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			load_status = ResourceLoader.load_threaded_get_status(active_scene_path)
			
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			var next_scene = ResourceLoader.load_threaded_get(active_scene_path) as PackedScene
			get_tree().change_scene_to_packed(next_scene)
		else:
			print("Error: Scene failed to load.")
			is_transitioning = false
	else:
		print("Error: No 2D or 3D scene path was assigned in the Inspector.")
		is_transitioning = false

# Accepting a generic 'Node' allows this to accept both Node2D and Node3D bodies
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		if prompt_label and "visible" in prompt_label and not is_transitioning:
			prompt_label.visible = true
		update_gate_state()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if prompt_label and "visible" in prompt_label:
			prompt_label.visible = false
		update_gate_state()

func update_gate_state() -> void:
	var manager = get_tree().get_first_node_in_group("dimension_manager")
	if player_inside:
		if manager and manager.has_method("set_active_gate"):
			# Pass the parent_area (the actual gate) to the manager, not this component
			manager.set_active_gate(parent_area)
	else:
		if manager and manager.has_method("clear_active_gate") and not manager.is_transitioning:
			manager.clear_active_gate(parent_area)
