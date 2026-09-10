extends Control

@export var progress_bar: ProgressBar
@export var progress_label: Label
@export var install_timer: Timer
@export var open_button: Button

var total_size_mb: float = 167.0 

func _ready() -> void:
	if open_button:
		open_button.disabled = true
		open_button.pressed.connect(_on_open_pressed)
		
	if install_timer:
		install_timer.timeout.connect(_on_timer_timeout)
		
	# Listen for when this window gets shown or hidden
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	# Only start the installation timer if the window is currently visible
	if visible and install_timer:
		install_timer.start()

func _on_timer_timeout() -> void:
	if progress_bar.value < 100:
		progress_bar.value += randf_range(0.0, 1.5)
		var current_mb = (progress_bar.value / 100.0) * total_size_mb
		
		if progress_label:
			progress_label.text = "%0.2f of %0.2f MB" % [current_mb, total_size_mb]
	else:
		install_timer.stop()
		if progress_label:
			progress_label.text = "Installation Complete!"
		if open_button:
			open_button.disabled = false

func _on_open_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/loading_screen.tscn")
