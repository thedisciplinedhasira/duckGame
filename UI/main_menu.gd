extends Control

@export_range(100, 800) var button_width: float = 300.0
@export_range(20, 300) var button_height: float = 80.0

@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var dust_particles: GPUParticles2D = $DustParticles
@onready var selector: TextureRect = $Selector 

@onready var settings_menu: Control = $SettingsMenu

var hover_sound = preload("res://sounds/menuHover.wav")
# Update this path to where your ComicViewer scene is saved
const COMIC_VIEWER = preload("res://UI/comicviewer.scn") 

func _ready() -> void:
	selector.hide()
	
	for button in menu_container.get_children():
		if button is TextureButton:
			button.ignore_texture_size = true
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED 
			button.custom_minimum_size = Vector2(button_width, button_height)
			button.size = Vector2(button_width, button_height)
			
			button.mouse_entered.connect(button.grab_focus)
			button.focus_entered.connect(_on_button_focused.bind(button))
			
			if button.name == "PlayButton":
				button.pressed.connect(_on_play_pressed)
			elif button.name == "ComicButton":
				button.pressed.connect(_on_comic_pressed)
			elif button.name == "SettingsButton":
				button.pressed.connect(_on_settings_pressed)
			elif button.name == "QuitButton":
				button.pressed.connect(_on_quit_pressed)
	
	if menu_container.get_child_count() > 0:
		menu_container.get_child(0).grab_focus()

func _process(_delta: float) -> void:
	if dust_particles and dust_particles.process_material is ShaderMaterial:
		dust_particles.process_material.set_shader_parameter("mouse_position", get_global_mouse_position())

func _on_button_focused(btn: TextureButton) -> void:
	selector.show()
	audio_player.stream = hover_sound
	audio_player.play()
	
	var center_x_offset = (btn.size.x - selector.size.x) / 2.0
	var center_y_offset = (btn.size.y - selector.size.y) / 2.0
	var offset = Vector2(center_x_offset, center_y_offset) 
	
	selector.global_position = btn.global_position + offset

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://kebebeOS/os.tscn")
	
func _on_comic_pressed() -> void:
	var viewer = COMIC_VIEWER.instantiate()
	add_child(viewer)
	
func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.show()

func _on_quit_pressed() -> void:
	get_tree().quit()
