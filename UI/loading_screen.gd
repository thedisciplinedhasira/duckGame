extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var target_scene: String =  "res://scenes/test_tutorial.scn" #"res://test_open.scn"



func _ready() -> void:
	# 1. Tell Godot to start loading your heavy scene in the background
	ResourceLoader.load_threaded_request(target_scene)
	
	# 2. Connect the video finishing to our custom function
	video_player.finished.connect(_on_video_finished)

func _on_video_finished() -> void:
	# 3. The video is done! Grab the loaded scene from the background and switch to it.
	var new_scene = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(new_scene)
