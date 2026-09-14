extends CanvasLayer

@onready var text_label: RichTextLabel = $Background/TextureRect/TextLabel
@onready var background: Control = $Background
@onready var notification_panel: Control = $NotificationPanel 
@onready var notification_label: Label = $NotificationPanel/Label
# Based on your image, Kekebe is your portrait node. Rename it to "PortraitRect" in the scene tree if you prefer.
@onready var portrait_rect: Sprite2D = $Kekebe 
# Store the default inspector position of Kekebe on startup
@onready var default_portrait_pos: Vector2 = portrait_rect.position

var dialogue_lines: Array[DialogueLine] = []
var current_line_index := 0
var current_callback: Callable = Callable()

func _ready() -> void:
	background.visible = false
	portrait_rect.visible = false
	if notification_panel:
		notification_panel.visible = false

# --- MULTI-LINE DIALOGUE SYSTEM ---
func show_dialogue(lines: Array[DialogueLine], callback: Callable = Callable()) -> void:
	print("[DEBUG] UI received show_dialogue request with ", lines.size(), " lines.")
	dialogue_lines = lines
	current_line_index = 0
	current_callback = callback
	
	if dialogue_lines.size() > 0:
		background.visible = true
		_update_ui()
		
func _update_ui() -> void:
	var current_line = dialogue_lines[current_line_index]
	text_label.text = current_line.text
	
	if current_line.character_portrait:
		portrait_rect.texture = current_line.character_portrait
		portrait_rect.visible = true
		
		# Move portrait to custom position if defined, else use default position
		if current_line.portrait_position != Vector2.ZERO:
			portrait_rect.position = current_line.portrait_position
		else:
			portrait_rect.position = default_portrait_pos
	else:
		portrait_rect.visible = false
		
func close_dialogue() -> void:
	background.visible = false
	portrait_rect.visible = false
	dialogue_lines.clear()
	current_line_index = 0
	if current_callback.is_valid():
		current_callback.call()
		current_callback = Callable()

#func _unhandled_input(event: InputEvent) -> void:
	#if background.visible and event.is_action_pressed("interact"):
		#get_viewport().set_input_as_handled()
		#
		#current_line_index += 1
		#if current_line_index < dialogue_lines.size():
			#_update_ui()
		#else:
			#close_dialogue()

# --- TOP-SCREEN NOTIFICATION SYSTEM (Unchanged) ---
func show_notification(text: String, sound_stream: AudioStream = null) -> void:
	if notification_panel and notification_label:
		notification_label.text = text
		notification_panel.visible = true
		
		var tween = create_tween()
		tween.tween_interval(3.5)
		tween.tween_callback(func(): notification_panel.visible = false)
