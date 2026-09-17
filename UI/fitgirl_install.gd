extends Control

@export var next_button: Button
@export var check_box_1: CheckBox
@export var check_box_2: CheckBox
@export var fitgirl_progress_window: Control # Add this variable


func _ready() -> void:
	if next_button:
		next_button.disabled = false
		next_button.pressed.connect(_on_next_pressed)
	#
	#if check_box_1:
		#check_box_1.toggled.connect(_on_checkbox_toggled)
	#if check_box_2:
		#check_box_2.toggled.connect(_on_checkbox_toggled)

func _on_checkbox_toggled(_is_checked: bool) -> void:
	if next_button:
		var any_checked = check_box_1.button_pressed or check_box_2.button_pressed
		next_button.disabled = !any_checked

func _on_next_pressed() -> void:
	hide()
	if fitgirl_progress_window:
		fitgirl_progress_window.show()
		fitgirl_progress_window.move_to_front()
