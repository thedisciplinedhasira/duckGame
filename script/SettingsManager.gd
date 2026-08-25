extends Node

const SAVE_PATH := "user://settings.cfg"
var config := ConfigFile.new()

signal settings_applied

func _ready() -> void:
	if config.load(SAVE_PATH) != OK:
		auto_detect_hardware()
	else:
		load_settings()


## Automatically inspects the GPU name string to pick recommended initial settings
func auto_detect_hardware() -> void:
	print("--- STARTING AUTO DETECT ---")
	
	# 1. Detect Native Display Resolution
	var current_screen := DisplayServer.window_get_current_screen()
	var native_res := DisplayServer.screen_get_size(current_screen)
	print("Detected Native Resolution: ", native_res)
	set_resolution(native_res)

	# 2. Query CPU Information
	var cpu_name := OS.get_processor_name()
	var cpu_threads := OS.get_processor_count()
	print("Detected CPU: ", cpu_name, " with ", cpu_threads, " threads")
	
	# 3. Query GPU Information
	var gpu_name := RenderingServer.get_video_adapter_name().to_lower()
	print("Detected GPU: ", RenderingServer.get_video_adapter_name())
	
	var recommended_preset := "Medium"

	# 4. Evaluate GPU Hardware Class (Primary Factor)
	if "intel" in gpu_name or "uhd" in gpu_name or "iris" in gpu_name or "vega" in gpu_name:
		recommended_preset = "Low"
	elif "rtx 30" in gpu_name or "rtx 40" in gpu_name or "rx 67" in gpu_name or "rx 7" in gpu_name:
		recommended_preset = "Ultra"
	elif "rtx" in gpu_name or "rx 6" in gpu_name or "gtx 1080" in gpu_name:
		recommended_preset = "High"
	elif "gtx" in gpu_name or "radeon" in gpu_name:
		recommended_preset = "Medium"
		
	# 5. CPU Bottleneck Check (Secondary Factor)
	# If the CPU has 4 or fewer threads, it's likely an older processor that might bottleneck a good GPU.
	if cpu_threads <= 4 and recommended_preset in ["High", "Ultra"]:
		print("Notice: Weak CPU detected. Downgrading preset to avoid bottlenecking.")
		recommended_preset = "Medium"
	elif cpu_threads <= 2:
		print("Notice: Very weak CPU detected. Forcing Low preset.")
		recommended_preset = "Low"

	print("Final Recommended Preset Selected: ", recommended_preset)

	# 6. Apply settings
	apply_graphics_preset(recommended_preset)
	set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	set_vsync(true)
	set_max_fps(60)
	
	save_settings()
	print("--- AUTO DETECT COMPLETE ---")
	
func apply_graphics_preset(preset: String) -> void:
	match preset:
		"Low":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			get_viewport().scaling_3d_scale = 0.65 # Renders at lower internal resolution
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		"Medium":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			get_viewport().scaling_3d_scale = 0.85
			get_viewport().msaa_3d = Viewport.MSAA_2X
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		"High":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			get_viewport().scaling_3d_scale = 1.0
			get_viewport().msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		"Ultra":
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			get_viewport().scaling_3d_scale = 1.0
			get_viewport().msaa_3d = Viewport.MSAA_8X
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

	config.set_value("graphics", "preset", preset)


func set_resolution(size: Vector2i) -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(size)
		var screen_center := DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
		DisplayServer.window_set_position(screen_center - size / 2)
	config.set_value("graphics", "resolution", size)


func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)
	config.set_value("graphics", "window_mode", mode)


func set_vsync(enabled: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	config.set_value("graphics", "vsync", enabled)


func set_max_fps(fps: int) -> void:
	Engine.max_fps = fps
	config.set_value("graphics", "max_fps", fps)


func save_settings() -> void:
	config.save(SAVE_PATH)


func load_settings() -> void:
	var preset = config.get_value("graphics", "preset", "Medium")
	var mode = config.get_value("graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
	var res = config.get_value("graphics", "resolution", Vector2i(1920, 1080))
	var vsync = config.get_value("graphics", "vsync", true)
	var fps = config.get_value("graphics", "max_fps", 60)

	apply_graphics_preset(preset)
	set_window_mode(mode)
	set_resolution(res)
	set_vsync(vsync)
	set_max_fps(fps)
