extends Node

const SAVE_PATH := "user://settings.cfg"
var config := ConfigFile.new()

# fires whenever settings finish being applied and persisted - hook into this
# if something else (post-process volume, debug HUD, etc) needs to react
signal settings_applied


func _ready() -> void:
	if config.load(SAVE_PATH) != OK:
		auto_detect_hardware() # first launch ever - nothing saved to fall back on
	else:
		load_settings()          # restore whatever was saved last time
		_apply_detected_preset() # then always re-check hardware and refresh the preset


## Full first-run setup - picks a preset AND sets resolution/window mode/
## vsync/fps, since there's nothing saved yet to fall back on.
func auto_detect_hardware() -> void:
	print("--- STARTING AUTO DETECT ---")

	var current_screen := DisplayServer.window_get_current_screen()
	var native_res := DisplayServer.screen_get_size(current_screen)
	print("Detected Native Resolution: ", native_res)

	var recommended_preset := _get_recommended_preset()
	print("Final Recommended Preset Selected: ", recommended_preset)

	# window mode goes first so set_resolution below evaluates its "am I
	# windowed / exclusive fullscreen" check against the mode we're actually
	# landing on, not whatever the project happened to boot into
	set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	set_resolution(native_res)

	# Lock vsync universally, but drop the FPS cap to 30 for low-end hardware
	set_vsync(true)
	if recommended_preset == "Low":
		set_max_fps(30)
	else:
		set_max_fps(60)

	apply_graphics_preset(recommended_preset)

	save_settings()



## Re-runs just the hardware check and refreshes the preset. Deliberately
## does NOT touch resolution/window mode/vsync/fps, so it's safe to call on
## every launch without stomping on choices the player made manually there.
## Heads up: this does mean a manually-picked preset (e.g. player forces
## Ultra on Medium-tier hardware) gets reset back to the detected tier on
## next launch. Say the word if you'd rather that stick once picked.
func _apply_detected_preset() -> void:
	var recommended_preset := _get_recommended_preset()
	print("Re-detected preset on launch: ", recommended_preset)
	apply_graphics_preset(recommended_preset)
	save_settings()


func _get_recommended_preset() -> String:
	var cpu_threads := OS.get_processor_count() # this is thread count, not core count
	var gpu_name := RenderingServer.get_video_adapter_name().to_lower()
	print("Detected CPU threads: ", cpu_threads, " | GPU: ", RenderingServer.get_video_adapter_name())

	var recommended_preset := _detect_gpu_tier(gpu_name)

	# CPU can bottleneck a strong GPU - thread count is a blunt proxy but it
	# catches the obvious cases (old dual cores, budget laptop chips)
	if cpu_threads <= 2:
		recommended_preset = "Low"
	elif cpu_threads <= 4 and recommended_preset in ["High", "Ultra"]:
		recommended_preset = "Medium"

	return recommended_preset


## Rough GPU tier guess from the adapter name string. Kept as its own function
## so the matching logic doesn't get buried elsewhere, and so it's easy to
## unit-test or extend on its own later.
func _detect_gpu_tier(gpu_name: String) -> String:
	# discrete AMD Vega cards were legit mid/high-end in their day - check
	# these before the generic "vega" match below, which is really aimed at
	# weak integrated Vega iGPUs (e.g. "Vega 8 Graphics")
	if "vega 56" in gpu_name or "vega 64" in gpu_name or "radeon vii" in gpu_name:
		return "High"

	# Intel Arc discrete cards - not to be confused with Intel integrated graphics
	if "arc a" in gpu_name or "arc b" in gpu_name:
		return "Medium"

	# weak integrated graphics
	if "intel" in gpu_name or "uhd" in gpu_name or "iris" in gpu_name or "vega" in gpu_name:
		return "Low"

	# Nvidia RTX - check the newest/strongest generations first so nothing
	# falls through to a lower tier than it deserves
	if "rtx 50" in gpu_name or "rtx 40" in gpu_name:
		return "Ultra"
	if "rtx 30" in gpu_name or "rtx" in gpu_name:
		return "High"

	# AMD RX - flagship cards checked before their generation's generic
	# match, otherwise a 6800/6900 gets bucketed the same as a 6600
	if "rx 7900" in gpu_name or "rx 6900" in gpu_name or "rx 6800" in gpu_name:
		return "Ultra"
	if "rx 7" in gpu_name or "rx 6" in gpu_name:
		return "High"

	if "gtx 1080" in gpu_name or "gtx 1070" in gpu_name:
		return "High"
	if "gtx" in gpu_name or "radeon" in gpu_name:
		return "Medium"

	return "Medium" # unrecognized hardware, safe middle default


func _supports_fsr2() -> bool:
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	return method == "forward_plus" or method == "mobile"


func apply_graphics_preset(preset: String) -> void:
	# FSR2 only works on Forward+ / Mobile - on the Compatibility renderer
	# it's silently ignored, which would quietly undo the whole point of
	# scaling down for weak hardware. fall back to bilinear scaling there.
	var use_fsr2 := _supports_fsr2()
	var upscale_mode := Viewport.SCALING_3D_MODE_FSR2 if use_fsr2 else Viewport.SCALING_3D_MODE_BILINEAR

	match preset:
		"Low":
			get_viewport().scaling_3d_mode = upscale_mode
			get_viewport().scaling_3d_scale = 0.65
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		"Medium":
			get_viewport().scaling_3d_mode = upscale_mode
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
	var mode := DisplayServer.window_get_mode()

	# regular borderless Fullscreen always matches the screen's native size,
	# so there's nothing to actually apply there - we still remember the
	# choice below for whenever the player switches to Windowed or Exclusive
	# Fullscreen, which are the two modes that actually use a custom size
	if mode == DisplayServer.WINDOW_MODE_WINDOWED or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_size(size)
		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
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
	settings_applied.emit()


## Restores everything from disk, including the preset that was saved last
## time. On normal startup this gets called right before _apply_detected_preset(),
## which immediately re-checks hardware and overwrites the preset applied
## here - that's expected, not a bug, it just means load_settings() stays a
## complete, standalone "restore everything" function on its own.
func load_settings() -> void:
	var preset: String = config.get_value("graphics", "preset", "Medium")
	var mode: DisplayServer.WindowMode = config.get_value("graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
	var res: Vector2i = config.get_value("graphics", "resolution", Vector2i(1920, 1080))
	var vsync: bool = config.get_value("graphics", "vsync", true)
	var fps: int = config.get_value("graphics", "max_fps", 60)

	set_window_mode(mode)
	set_resolution(res)
	set_vsync(vsync)
	set_max_fps(fps)
	apply_graphics_preset(preset)

	settings_applied.emit()


# --- getters, so UI code doesn't have to reach into `config` directly ---

func get_current_preset() -> String:
	return config.get_value("graphics", "preset", "Medium")


func get_current_resolution() -> Vector2i:
	return config.get_value("graphics", "resolution", Vector2i(1920, 1080))


func get_current_window_mode() -> DisplayServer.WindowMode:
	return config.get_value("graphics", "window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)


func get_vsync_enabled() -> bool:
	return config.get_value("graphics", "vsync", true)


func get_max_fps() -> int:
	return config.get_value("graphics", "max_fps", 60)
