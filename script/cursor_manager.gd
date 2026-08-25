extends Node
var default_cursor = preload("res://UI/UIElements/hand_small_open.png")
var hover_cursor = preload("res://UI/UIElements/hand_small_point.png") 

func _ready():
	# Set the Default Arrow (Cursor Shape 0)
	# The Vector2(0,0) is the hotspot. Adjust if the "point" of your cursor isn't top-left.
	Input.set_custom_mouse_cursor(default_cursor, Input.CURSOR_ARROW, Vector2(0, 0))
	
	# Set the Hovering Hand (Cursor Shape 2)
	Input.set_custom_mouse_cursor(hover_cursor, Input.CURSOR_POINTING_HAND, Vector2(0, 0))
