extends CanvasLayer

@onready var text_label: RichTextLabel = $Background/TextureRect/TextLabel
@onready var background: Control = $Background
@onready var notification_panel: Control = $NotificationPanel 
@onready var notification_label: Label = $NotificationPanel/Label
#@onready var notification_sound: AudioStreamPlayer = $NotificationSound

var dialogue_lines: Array[String] = []
var current_line_index := 0
var current_callback: Callable = Callable()

func _ready() -> void:
	background.visible = false
	if notification_panel:
		notification_panel.visible = false

# --- MULTI-LINE DIALOGUE SYSTEM ---
func show_dialogue(lines: Array[String], callback: Callable = Callable()) -> void:
	dialogue_lines = lines
	current_line_index = 0
	current_callback = callback
	
	if dialogue_lines.size() > 0:
		text_label.text = dialogue_lines[current_line_index]
		background.visible = true

# --- TOP-SCREEN NOTIFICATION SYSTEM ---
func show_notification(text: String, sound_stream: AudioStream = null) -> void:
	if notification_panel and notification_label:
		notification_label.text = text
		notification_panel.visible = true
		
		# Play sound effect
		#if sound_stream and notification_sound:
			#notification_sound.stream = sound_stream
			#notification_sound.play()
		#elif notification_sound and notification_sound.stream:
			#notification_sound.play()
		
		# Automatically hide the banner after 3.5 seconds
		var tween = create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(func(): notification_panel.visible = false)

func close_dialogue() -> void:
	background.visible = false
	dialogue_lines.clear()
	current_line_index = 0
	if current_callback.is_valid():
		current_callback.call()
		current_callback = Callable()

func _unhandled_input(event: InputEvent) -> void:
	if background.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		
		# Step to the next line, or close if we reached the end
		current_line_index += 1
		if current_line_index < dialogue_lines.size():
			text_label.text = dialogue_lines[current_line_index]
		else:
			close_dialogue()
