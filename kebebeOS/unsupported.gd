extends Control

@export var unsupported_window: Control
@export var error_sound: AudioStreamPlayer
@export var icon: TextureRect

func _ready() -> void:
	# Safely assign the child icon node without type conflict on 'self'
	if not icon:
		if has_node("TextureRect"):
			icon = $TextureRect
		elif has_node("Icon"):
			icon = $Icon

	if icon:
		icon.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				if icon:
					icon.modulate = Color.WHITE
				
				if error_sound:
					error_sound.play()
					
				if unsupported_window:
					unsupported_window.show()
					unsupported_window.move_to_front()
			else:
				if icon:
					icon.modulate = Color(0.7, 0.8, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse_pos = get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse_pos):
			if icon:
				icon.modulate = Color.WHITE
