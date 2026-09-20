extends Control

@export var warning_window: Control
@export var error_sound: AudioStreamPlayer
@onready var icon: TextureRect = $Icon

func _ready() -> void:
	if icon:
		icon.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				if icon:
					icon.modulate = Color.WHITE 
				
				# Play the classic error sound
				if error_sound:
					error_sound.play()
					
				# Pop up the warning panel telling them to click the Kekebe folder
				if warning_window:
					warning_window.show()
					warning_window.move_to_front()
			else:
				# Highlight blue-white on single click
				if icon:
					icon.modulate = Color(0.7, 0.8, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse_pos = get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse_pos):
			if icon:
				icon.modulate = Color.WHITE
