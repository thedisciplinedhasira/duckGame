extends Control

@export var message_label: Label
@export var ight_button: Button
@export var x_button: Button

func _ready() -> void:
	if message_label:
		# 1. Fetch the system username
		var player_name: String = OS.get_environment("USERNAME")
		if player_name == "":
			player_name = OS.get_environment("USER") 
		if player_name == "":
			player_name = "Guest"
			
		# Optional: Capitalizes the first letter so "izzy" becomes "Izzy"
		player_name = player_name.capitalize() 

		# 2. Fetch the date and combine them
		var formatted_date = get_formatted_date()
		message_label.text = "Hey " + player_name + ",\n Meskot XP End of Support is on " + formatted_date + "\n Make sure to Upgrade to Meskot 10."
		
	# 3. Connect the close buttons
	if ight_button:
		ight_button.pressed.connect(hide)
	if x_button:
		x_button.pressed.connect(hide)

func get_formatted_date() -> String:
	var time_dict = Time.get_datetime_dict_from_system()
	
	var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var month_name = months[time_dict.month - 1]
	var day = time_dict.day
	var year = time_dict.year
	
	var suffix = "th"
	if day % 10 == 1 and day != 11:
		suffix = "st"
	elif day % 10 == 2 and day != 12:
		suffix = "nd"
	elif day % 10 == 3 and day != 13:
		suffix = "rd"
		
	return "%s %d%s, %d" % [month_name, day, suffix, year]
