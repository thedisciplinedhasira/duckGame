extends Control

@export var start_button: Button
@export var start_menu_label: Label
@export var address_bar_label: Label

func _ready() -> void:
	# 1. Fetch the system username (Checks Windows, then Linux/macOS)
	var player_name: String = OS.get_environment("USERNAME")
	
	if player_name == "":
		player_name = OS.get_environment("USER") 
		
	# Fallback just in case the OS blocks it
	if player_name == "":
		player_name = "GUEST"
		
	# Convert to all caps
	player_name = player_name.to_upper()
	
	# 2. Inject the name into the UI
	if start_button:
		start_button.text = player_name
		
	if start_menu_label:
		start_menu_label.text = player_name
		
	if address_bar_label:
		address_bar_label.text = "HOME/" + player_name + "/KEKEBE/"
