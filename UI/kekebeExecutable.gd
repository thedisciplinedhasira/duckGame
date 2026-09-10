extends VBoxContainer

@export var fitgirl_first_window: Control

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			if fitgirl_first_window:
				fitgirl_first_window.show()
				fitgirl_first_window.move_to_front()
