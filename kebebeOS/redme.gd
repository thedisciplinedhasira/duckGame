extends Control

@export var readme_label: Label
@onready var notification_panel: Control = $"../../../Notification"


var player_name: String = ""

func _ready() -> void:
	player_name = OS.get_environment("USERNAME")
	if player_name == "":
		player_name = OS.get_environment("USER") 
	if player_name == "":
		player_name = "Guest"
		
	player_name = player_name.capitalize()
	
	if readme_label:
		readme_label.text = "Hey " + player_name + ",\n\nOpen the KEKEBE folder.\n\nRun the installer, wait for it to finish, and enjoy the game"
		
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible and notification_panel and notification_panel.has_method("show_notification"):
		# 1. Wait for 1.5 seconds (you can change this number!)
		await get_tree().create_timer(1.5).timeout
		
		# 2. Make sure the Redme panel wasn't closed while we were waiting
		if visible:
			var popup_title = "New Message from MOM"
			var popup_message = "Hey " + player_name + ", please touch some grass😭🙏"
			notification_panel.show_notification(popup_title, popup_message)
