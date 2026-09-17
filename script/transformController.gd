extends Node

@export_category("Scene Targets")
@export_file("*.tscn", "*.scn") var target_2d_scene_path: String
@export_file("*.tscn", "*.scn") var target_3d_scene_path: String

@export_category("Transition Settings")
@export_file("*.ogv") var video_file_path: String 

var player_inside: bool = false
var is_transitioning: bool = false
var video_player: VideoStreamPlayer = null
var active_scene_path: String = "" 
var parent_area: Node = null

func _ready() -> void:
	parent_area = get_parent()
	
	# Connect to the parent area's signals
	if parent_area.has_signal("body_entered"):
		parent_area.body_entered.connect(_on_body_entered)
	if parent_area.has_signal("body_exited"):
		parent_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_transitioning:
		player_inside = true
		update_gate_state()
		start_transition()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		update_gate_state()

func start_transition() -> void:
	is_transitioning = true
		
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

func update_gate_state() -> void:
	var manager = get_tree().get_first_node_in_group("dimension_manager")
	if player_inside:
		if manager and manager.has_method("set_active_gate"):
			manager.set_active_gate(parent_area)
	else:
		if manager and manager.has_method("clear_active_gate") and not manager.is_transitioning:
			manager.clear_active_gate(parent_area)
