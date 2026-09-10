extends Button

@export var black_screen: ColorRect

func _ready() -> void:
	# Ensures the screen is hidden when the OS boots up
	if black_screen:
		black_screen.hide()

func _pressed() -> void:
	if black_screen:
		black_screen.show()
		# Optional: Moves it to the very bottom of the node list to guarantee it covers everything
		black_screen.move_to_front() 
		
	# Pauses the game for 1.5 seconds on the black screen
	await get_tree().create_timer(1.5).timeout 
	
	# Load your main menu (verify this path matches your project)
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
