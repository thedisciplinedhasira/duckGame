extends Control

@export var title_label: Label
@export var message_label: Label
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var off_screen_pos: Vector2
var on_screen_pos: Vector2

func _ready() -> void:
	# Store the current position in the editor as the "on screen" target
	on_screen_pos = position
	# Calculate a position just below the screen
	off_screen_pos = on_screen_pos + Vector2(0, size.y + 100) 
	
	# Start hidden and off-screen
	position = off_screen_pos
	visible = false

func show_notification(title_text: String, message_text: String) -> void:
	# Set the text
	if title_label:
		title_label.text = title_text
	if message_label:
		message_label.text = message_text
		
	# Reset position and make visible
	position = off_screen_pos
	visible = true
	
	# Play the classic XP sound
	if audio_player.stream:
		audio_player.play()
		
	# Slide up smoothly
	var tween = create_tween()
	tween.tween_property(self, "position", on_screen_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Auto-hide after 5 seconds (XP balloons usually stick around for a bit)
	get_tree().create_timer(5.0).timeout.connect(hide_notification)

func hide_notification() -> void:
	# Slide back down
	var tween = create_tween()
	tween.tween_property(self, "position", off_screen_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): visible = false)
