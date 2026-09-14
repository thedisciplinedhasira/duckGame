extends Node

const SAVE_PATH := "user://settings.cfg"
const DEF_PRESET := "Medium"
const DEF_RES := Vector2i(1920, 1080)
const DEF_FPS := 0 # 0 = unlimited
const LOW_FPS := 30

var config := ConfigFile.new()
signal settings_applied

func _ready() -> void:
	if config.load(SAVE_PATH) != OK:
		_auto_setup()
	else:
		load_settings()

# ---------- AUTO SETUP ----------

func _auto_setup() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var res := DisplayServer.screen_get_size(screen)
	var preset := _recommended_preset()

	set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	set_resolution(res)
	set_vsync(false)
	set_max_fps(LOW_FPS if preset == "Low" else DEF_FPS)
	apply_graphics_preset(preset)
	save_settings()

# ---------- HARDWARE ----------

func _recommended_preset() -> String:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var threads := OS.get_processor_count()
	var preset := _gpu_tier(gpu)

	if threads <= 2:
		return "Low"

	if threads <= 4:
		if preset == "Ultra":
			return "High"
		if preset == "High":
			return "Medium"

	return preset

func _gpu_tier(gpu: String) -> String:
	# Integrated GPUs
	if "uhd" in gpu or "iris" in gpu:
		return "Low"

	# Intel Arc
	if "arc" in gpu:
		return "High"

	# NVIDIA RTX
	if "rtx 50" in gpu:
		return "Ultra"
	if "rtx 40" in gpu:
		return "Ultra"
	if "rtx 30" in gpu or "rtx" in gpu:
		return "High"

	# NVIDIA GTX
	if "gtx 10" in gpu:
		return "High"
	if "gtx" in gpu:
		return "Medium"

	# AMD RX
	if "rx 9" in gpu:
		return "Ultra"
	if "rx 7" in gpu or "rx 6" in gpu:
		return "High"
	if "rx 5" in gpu or "rx 4" in gpu:
		return "Medium"

	# AMD integrated / older Radeon
	if "vega" in gpu:
		return "Low"
	if "radeon" in gpu:
		return "Medium"

	return "Medium"

# ---------- GRAPHICS ----------

func apply_graphics_preset(preset: String) -> void:
	var vp := get_viewport()
	var fsr := _supports_fsr2()

	match preset:
		"Low":
			vp.scaling_3d_mode = (
				Viewport.SCALING_3D_MODE_FSR2 if fsr
				else Viewport.SCALING_3D_MODE_BILINEAR
			)
			vp.scaling_3d_scale = 0.65
			vp.msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD
			)

		"Medium":
			vp.scaling_3d_mode = (
				Viewport.SCALING_3D_MODE_FSR2 if fsr
				else Viewport.SCALING_3D_MODE_BILINEAR
			)
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_2X
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW
			)

		"High":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			)

		"Ultra":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_HIGH
			)

		_:
			apply_graphics_preset(DEF_PRESET)
			return

	config.set_value("graphics", "preset", preset)

func _supports_fsr2() -> bool:
	var method: String = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method",
		"forward_plus"
	)
	return method == "forward_plus" or method == "mobile"

# ---------- DISPLAY ----------

func set_resolution(size: Vector2i) -> void:
	var mode := DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_WINDOWED \
	or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_size(size)

		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
			var screen := DisplayServer.window_get_current_screen()
			var pos := DisplayServer.screen_get_position(screen)
			var screen_size := DisplayServer.screen_get_size(screen)
			DisplayServer.window_set_position(
				pos + (screen_size - size) / 2
			)

	config.set_value("graphics", "resolution", size)

func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)
	config.set_value("graphics", "window_mode", mode)

func set_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled
		else DisplayServer.VSYNC_DISABLED
	)
	config.set_value("graphics", "vsync", enabled)

func set_max_fps(fps: int) -> void:
	Engine.max_fps = max(fps, 0)
	config.set_value("graphics", "max_fps", max(fps, 0))

# ---------- SAVE / LOAD ----------

func save_settings() -> void:
	config.save(SAVE_PATH)
	settings_applied.emit()

func load_settings() -> void:
	var preset: String = config.get_value("graphics", "preset", DEF_PRESET)
	var mode: DisplayServer.WindowMode = config.get_value(
		"graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	var res: Vector2i = config.get_value("graphics", "resolution", DEF_RES)
	var vsync: bool = config.get_value("graphics", "vsync", false)
	var fps: int = config.get_value("graphics", "max_fps", DEF_FPS)

	set_window_mode(mode)
	set_resolution(res)
	set_vsync(vsync)
	set_max_fps(fps)
	apply_graphics_preset(preset)
	settings_applied.emit()

# ---------- GETTERS ----------

func get_current_preset() -> String:
	return config.get_value("graphics", "preset", DEF_PRESET)

func get_current_resolution() -> Vector2i:
	return config.get_value("graphics", "resolution", DEF_RES)

func get_current_window_mode() -> DisplayServer.WindowMode:
	return config.get_value(
		"graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN
	)

func get_vsync_enabled() -> bool:
	return config.get_value("graphics", "vsync", false)

func get_max_fps() -> int:
	return config.get_value("graphics", "max_fps", DEF_FPS)
