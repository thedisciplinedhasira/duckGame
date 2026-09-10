extends Control

@export var target_window: Control

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	# Stop the script if no window is assigned in the Inspector
	if not target_window:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			# Calculate offset from the target window's position, not the title bar's position
			drag_offset = event.global_position - target_window.global_position
			target_window.move_to_front() 
		else:
			dragging = false
			
	if event is InputEventMouseMotion and dragging:
		# Move the assigned target window
		target_window.global_position = event.global_position - drag_offset
