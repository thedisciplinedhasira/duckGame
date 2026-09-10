extends Button

func _pressed() -> void:
	# Goes up one level to TitleBar, then up another level to FolderWindow, and hides it
	var window = get_parent().get_parent()
	window.hide()
