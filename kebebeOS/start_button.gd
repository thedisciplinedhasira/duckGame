extends Button

@export var start_menu: Control

func _pressed() -> void:
	if start_menu:
		# Flips the visibility state on each click
		start_menu.visible = !start_menu.visible
		
		# Pushes the menu over the desktop icons when opened
		if start_menu.visible:
			start_menu.move_to_front()
