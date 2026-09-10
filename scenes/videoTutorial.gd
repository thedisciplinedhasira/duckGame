extends Area3D

var prompt_visual: Sprite3D = null
var video_player: VideoStreamPlayer = null

func _ready() -> void:
	prompt_visual = find_child("Sprite3D", true, false) as Sprite3D
	video_player = find_child("VideoStreamPlayer", true, false) as VideoStreamPlayer
	
	if prompt_visual:
		prompt_visual.visible = false
		
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		
	# Ensure the video loops endlessly while the player is in the zone
	if video_player and not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if prompt_visual:
			prompt_visual.visible = true
		if video_player:
			video_player.play()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if prompt_visual:
			prompt_visual.visible = false
		if video_player:
			video_player.stop()

func _on_video_finished() -> void:
	if video_player and prompt_visual and prompt_visual.visible:
		video_player.play()
