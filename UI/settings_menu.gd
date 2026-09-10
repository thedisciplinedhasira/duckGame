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

const REVERT_TIMEOUT := 15 # seconds before an unconfirmed display change reverts

# built in code so this script is a clean drop-in with no extra scene setup -
# resolution and window mode changes can strand the player on a bad display
# mode, so give them a confirm-or-auto-revert safety net
var _confirm_dialog: ConfirmationDialog
var _confirm_timer: Timer
var _confirm_seconds_left := 0
var _revert_resolution: Vector2i
var _revert_window_mode: DisplayServer.WindowMode


func _ready() -> void:
	hide()
	_setup_ui_options()
	_build_confirm_dialog()
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


func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Keep display settings?"
	_confirm_dialog.get_cancel_button().pressed.connect(_on_confirm_reverted)
	_confirm_dialog.confirmed.connect(_on_confirm_kept)
	add_child(_confirm_dialog)

	_confirm_timer = Timer.new()
	_confirm_timer.wait_time = 1.0
	_confirm_timer.timeout.connect(_on_confirm_tick)
	add_child(_confirm_timer)


func _on_resolution_selected(index: int) -> void:
	_revert_resolution = SettingsManager.get_current_resolution()
	_revert_window_mode = SettingsManager.get_current_window_mode()
	SettingsManager.set_resolution(RESOLUTIONS[index])
	SettingsManager.save_settings()
	_start_confirm_countdown()


func _on_preset_selected(index: int) -> void:
	# preset changes don't touch resolution/window mode, so there's no
	# "black screen with no way back" risk here - apply immediately
	SettingsManager.apply_graphics_preset(PRESETS[index])
	SettingsManager.save_settings()


func _on_mode_selected(index: int) -> void:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match index:
		1: mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2: mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

	_revert_resolution = SettingsManager.get_current_resolution()
	_revert_window_mode = SettingsManager.get_current_window_mode()
	SettingsManager.set_window_mode(mode)
	SettingsManager.save_settings()
	_start_confirm_countdown()


func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.set_vsync(toggled_on)
	SettingsManager.save_settings()


func _on_auto_detect_pressed() -> void:
	SettingsManager.auto_detect_hardware()
	_sync_ui_with_settings()


func _start_confirm_countdown() -> void:
	_confirm_seconds_left = REVERT_TIMEOUT
	_confirm_dialog.dialog_text = "Keep these display settings? Reverting in %d seconds." % _confirm_seconds_left
	_confirm_dialog.popup_centered()
	_confirm_timer.start()


func _on_confirm_tick() -> void:
	_confirm_seconds_left -= 1
	if _confirm_seconds_left <= 0:
		_confirm_dialog.hide()
		_on_confirm_reverted()
		return
	_confirm_dialog.dialog_text = "Keep these display settings? Reverting in %d seconds." % _confirm_seconds_left


func _on_confirm_kept() -> void:
	_confirm_timer.stop()


func _on_confirm_reverted() -> void:
	_confirm_timer.stop()
	SettingsManager.set_window_mode(_revert_window_mode)
	SettingsManager.set_resolution(_revert_resolution)
	SettingsManager.save_settings()
	_sync_ui_with_settings()


func _sync_ui_with_settings() -> void:
	var current_preset := SettingsManager.get_current_preset()
	preset_option.select(PRESETS.find(current_preset))

	var current_res := SettingsManager.get_current_resolution()
	var res_index := RESOLUTIONS.find(current_res)
	if res_index != -1:
		res_option.select(res_index)

	match SettingsManager.get_current_window_mode():
		DisplayServer.WINDOW_MODE_WINDOWED:
			mode_option.select(0)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			mode_option.select(1)
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			mode_option.select(2)

	vsync_check.button_pressed = SettingsManager.get_vsync_enabled()
