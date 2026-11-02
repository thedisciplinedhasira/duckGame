extends CanvasLayer

@export_group("Menu Animation Settings")
@export var pop_in_duration: float = 0.3
@export var pop_out_duration: float = 0.15

@export_group("Ribbon Animation Settings")
@export var ribbon_move_duration: float = 0.15
@export var ribbon_x_offset: float = -20.0

@export_group("Button Hover Settings")
# 1.0 = no change, lower = darker
@export_range(0.0, 1.0) var hover_darkness: float = 0.7
@export var hover_fade_duration: float = 0.12

@export_group("Settings")
# pick res://UI/settings_menu.tscn in the inspector
@export_file("*.tscn") var settings_scene_path: String = ""

@onready var menu_background: TextureRect = $MenuBackground
@onready var hover_ribbon: TextureRect = $MenuBackground/HoverRibbon
@onready var return_btn: Button = $MenuBackground/VBoxContainer/ReturnButton
@onready var options_btn: Button = $MenuBackground/VBoxContainer/OptionsButton
@onready var quit_btn: Button = $MenuBackground/VBoxContainer/QuitButton
@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var dim_overlay: ColorRect = $DimOverlay

var hover_sound = preload("res://sounds/menuHover.wav")
var is_paused: bool = false
var ribbon_tween: Tween
var menu_tween: Tween
var settings_instance: Node = null
var menu_buttons: Array[Button] = []
var button_tweens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	audio_player.stream = hover_sound
	menu_background.pivot_offset = menu_background.size / 2.0

	return_btn.pressed.connect(_on_return_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	return_btn.mouse_entered.connect(func(): _move_ribbon_to_button(return_btn))
	options_btn.mouse_entered.connect(func(): _move_ribbon_to_button(options_btn))
	quit_btn.mouse_entered.connect(func(): _move_ribbon_to_button(quit_btn))

	hover_ribbon.modulate.a = 0.0

	# darken on hover
	menu_buttons = [return_btn, options_btn, quit_btn]
	for btn in menu_buttons:
		btn.mouse_entered.connect(_darken_button.bind(btn, true))
		btn.mouse_exited.connect(_darken_button.bind(btn, false))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# escape closes settings first, then the pause menu
		if is_instance_valid(settings_instance):
			settings_instance.queue_free()
			get_viewport().set_input_as_handled()
			return
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused

	if menu_tween and menu_tween.is_running():
		menu_tween.kill()

	menu_tween = create_tween().set_parallel(true) # parallel so scale and blur happen together

	if is_paused:
		get_tree().paused = true
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_snap_ribbon_to_button(return_btn)
		_reset_buttons()

		menu_background.scale = Vector2.ZERO

		# blur starts at 0 then tweens up to 2.5
		dim_overlay.material.set_shader_parameter("blur_amount", 0.0)
		menu_tween.tween_property(dim_overlay.material, "shader_parameter/blur_amount", 2.5, pop_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		menu_tween.tween_property(menu_background, "scale", Vector2.ONE, pop_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# close settings too if its still open
		if is_instance_valid(settings_instance):
			settings_instance.queue_free()

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		# tween the blur back to 0
		menu_tween.tween_property(dim_overlay.material, "shader_parameter/blur_amount", 0.0, pop_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		menu_tween.tween_property(menu_background, "scale", Vector2.ZERO, pop_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		# wait for the parallel tweens to finish before hiding the menu
		menu_tween.chain().tween_callback(func():
			visible = false
			get_tree().paused = false
		)

func _darken_button(btn: Button, hovered: bool) -> void:
	# dont darken while settings is covering the menu
	if hovered and is_instance_valid(settings_instance):
		return

	# kill the old tween for this button so they dont fight
	if button_tweens.has(btn) and button_tweens[btn].is_valid():
		button_tweens[btn].kill()

	# modulate multiplies the color, so rgb below 1.0 darkens and alpha stays 1.0
	var d: float = hover_darkness if hovered else 1.0
	var t: Tween = create_tween()
	t.tween_property(btn, "modulate", Color(d, d, d, 1.0), hover_fade_duration)
	button_tweens[btn] = t

func _reset_buttons() -> void:
	# if the menu closed while hovering, the button would still be dark next time
	for btn in menu_buttons:
		if button_tweens.has(btn) and button_tweens[btn].is_valid():
			button_tweens[btn].kill()
		btn.modulate = Color.WHITE

func _move_ribbon_to_button(button: Button) -> void:
	if not is_paused:
		return
	# dont animate the ribbon while settings is covering the menu
	if is_instance_valid(settings_instance):
		return

	# play the hover sound whenever the ribbon moves to a new button
	audio_player.play()

	if ribbon_tween and ribbon_tween.is_running():
		ribbon_tween.kill()

	ribbon_tween = create_tween().set_parallel(true)
	ribbon_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hover_ribbon.modulate.a < 1.0:
		ribbon_tween.tween_property(hover_ribbon, "modulate:a", 1.0, ribbon_move_duration)

	var target_y: float = button.global_position.y + (button.size.y / 2.0) - (hover_ribbon.size.y / 2.0)
	var target_x: float = button.global_position.x + ribbon_x_offset

	ribbon_tween.tween_property(hover_ribbon, "global_position", Vector2(target_x, target_y), ribbon_move_duration)

func _snap_ribbon_to_button(button: Button) -> void:
	hover_ribbon.modulate.a = 1.0
	var target_y: float = button.global_position.y + (button.size.y / 2.0) - (hover_ribbon.size.y / 2.0)
	var target_x: float = button.global_position.x + ribbon_x_offset
	hover_ribbon.global_position = Vector2(target_x, target_y)

func _on_return_pressed() -> void:
	toggle_pause()

func _on_options_pressed() -> void:
	# dont open two at once
	if is_instance_valid(settings_instance):
		return
	if settings_scene_path == "":
		push_warning("settings_scene_path is empty")
		return

	var scene: PackedScene = load(settings_scene_path)
	settings_instance = scene.instantiate()
	add_child(settings_instance)

	# cover the whole screen so it blocks the pause buttons
	if settings_instance is Control:
		settings_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# force it visible and on top in case the scene hides itself
	settings_instance.show()
	settings_instance.move_to_front()

	# settings script might have grabbed the mouse, give it back
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# close button frees the settings scene so we land back on the pause menu
	var close_btn = settings_instance.find_child("CloseButton", true, false)
	if close_btn is Button:
		close_btn.pressed.connect(settings_instance.queue_free)

func _on_quit_pressed() -> void:
	get_tree().quit()
