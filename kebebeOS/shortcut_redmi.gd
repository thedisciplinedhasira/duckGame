extends Control

@export var redme_window: Control
@onready var icon: TextureRect = $Icon

func _ready() -> void:
	# Ensure the icon starts with its default color
	icon.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				# Open the window and bring it to the front
				icon.modulate = Color.WHITE 
				if redme_window:
					redme_window.show()
					redme_window.move_to_front()
			else:
				# Highlight the icon on a single click. 
				# (0.7, 0.8, 1.0) gives a classic OS blue-white selection tint.
				icon.modulate = Color(0.7, 0.8, 1.0)

func _input(event: InputEvent) -> void:
	# Deselect the icon if the user clicks anywhere else on the screen
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse_pos = get_local_mouse_position()
		# Check if the click happened outside this shortcut's bounding box
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse_pos):
			icon.modulate = Color.WHITE
