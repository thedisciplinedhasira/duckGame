extends VBoxContainer

@export var target_window: Control

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				# Reset the tint and open the window
				modulate = Color(1, 1, 1, 1) 
				if target_window:
					target_window.show()
					target_window.move_to_front()
			else:
				# Single click: Apply a blue-ish selection tint
				modulate = Color(0.644, 0.724, 1.0, 1.0)
