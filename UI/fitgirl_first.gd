extends Control

@export var next_button: Button
@export var fitgirl_install_window: Control

func _ready() -> void:
	if next_button:
		next_button.pressed.connect(_on_next_pressed)

func _on_next_pressed() -> void:
	hide()
	if fitgirl_install_window:
		fitgirl_install_window.show()
		fitgirl_install_window.move_to_front()
