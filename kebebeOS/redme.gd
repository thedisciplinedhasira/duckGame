extends Control

@export var readme_label: Label

func _ready() -> void:
	if readme_label:
		var player_name: String = OS.get_environment("USERNAME")
		
		if player_name == "":
			player_name = OS.get_environment("USER") 
		if player_name == "":
			player_name = "Guest"
			
		player_name = player_name.capitalize()
		
		readme_label.text = "Hey " + player_name + ",\n\nTo get started, open the File Explorer and go to the KEKEBE folder.\n\nRun the installer, wait for it to finish, and enjoy the game!"
