extends CanvasLayer

@export_group("Menu Animation Settings")
@export var pop_in_duration: float = 0.3
@export var pop_out_duration: float = 0.15

@export_group("Ribbon Animation Settings")
@export var ribbon_move_duration: float = 0.15
@export var ribbon_x_offset: float = -20.0

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	
	if menu_tween and menu_tween.is_running():
		menu_tween.kill()
		
	menu_tween = create_tween().set_parallel(true) # Set to parallel so scale and blur happen together
	
	if is_paused:
		get_tree().paused = true
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_snap_ribbon_to_button(return_btn)
		
		menu_background.scale = Vector2.ZERO
		
		# Set blur to 0 initially, then tween it up to 2.5
		dim_overlay.material.set_shader_parameter("blur_amount", 0.0)
		menu_tween.tween_property(dim_overlay.material, "shader_parameter/blur_amount", 2.5, pop_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		menu_tween.tween_property(menu_background, "scale", Vector2.ONE, pop_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Tween the blur back to 0
		menu_tween.tween_property(dim_overlay.material, "shader_parameter/blur_amount", 0.0, pop_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		menu_tween.tween_property(menu_background, "scale", Vector2.ZERO, pop_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# Wait for the parallel tweens to finish before hiding the menu
		menu_tween.chain().tween_callback(func():
			visible = false
			get_tree().paused = false
		)
		
func _move_ribbon_to_button(button: Button) -> void:
	if not is_paused:
		return
		
	# Play the hover sound whenever the ribbon moves to a new button
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
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
