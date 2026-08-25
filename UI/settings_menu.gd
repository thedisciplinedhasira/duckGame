extends Control

@onready var res_option: OptionButton = $Background/VBoxContainer/ResolutionRow/ResolutionOption
@onready var preset_option: OptionButton = $Background/VBoxContainer/PresetRow/PresetOption
@onready var mode_option: OptionButton = $Background/VBoxContainer/ModeRow/WindowModeOption
@onready var vsync_check: CheckBox = $Background/VBoxContainer/VSyncCheck
@onready var close_btn: Button = $Background/VBoxContainer/CloseButton
@onready var auto_detect_btn: Button = $Background/VBoxContainer/AutoDetectButton

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const PRESETS := ["Low", "Medium", "High", "Ultra"]

func _ready() -> void:
	hide()
	_setup_ui_options()
	
	# Add this line here so the UI matches the saved settings when the game opens
	_sync_ui_with_settings() 

	res_option.item_selected.connect(_on_resolution_selected)
	preset_option.item_selected.connect(_on_preset_selected)
	mode_option.item_selected.connect(_on_mode_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	close_btn.pressed.connect(hide)
	
	if auto_detect_btn:
		auto_detect_btn.pressed.connect(_on_auto_detect_pressed)

func _setup_ui_options() -> void:
	res_option.clear()
	for res in RESOLUTIONS:
		res_option.add_item("%dx%d" % [res.x, res.y])

	preset_option.clear()
	for p in PRESETS:
		preset_option.add_item(p)

	mode_option.clear()
	mode_option.add_item("Windowed")
	mode_option.add_item("Fullscreen")
	mode_option.add_item("Exclusive Fullscreen")


func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(RESOLUTIONS[index])
	SettingsManager.save_settings()


func _on_preset_selected(index: int) -> void:
	SettingsManager.apply_graphics_preset(PRESETS[index])
	SettingsManager.save_settings()


func _on_mode_selected(index: int) -> void:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match index:
		1: mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2: mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	
	SettingsManager.set_window_mode(mode)
	SettingsManager.save_settings()


func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.set_vsync(toggled_on)
	SettingsManager.save_settings()


func _on_auto_detect_pressed() -> void:
	SettingsManager.auto_detect_hardware()
	_sync_ui_with_settings()
		
func _sync_ui_with_settings() -> void:
	# 1. Update the Preset dropdown
	var current_preset = SettingsManager.config.get_value("graphics", "preset", "Medium")
	preset_option.select(PRESETS.find(current_preset))
	
	# 2. Update the Resolution dropdown
	var current_res = SettingsManager.config.get_value("graphics", "resolution", Vector2i(1920, 1080))
	var res_index = RESOLUTIONS.find(current_res)
	if res_index != -1:
		res_option.select(res_index)
		
	# 3. Update Window Mode dropdown
	var current_mode = SettingsManager.config.get_value("graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		mode_option.select(0)
	elif current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		mode_option.select(1)
	elif current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		mode_option.select(2)
		
	# 4. Update V-Sync Checkbox
	vsync_check.button_pressed = SettingsManager.config.get_value("graphics", "vsync", true)
