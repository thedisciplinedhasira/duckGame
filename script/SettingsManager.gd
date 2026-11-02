extends Node

# picks a preset from the hardware, then a small loop watches gpu time
# and nudges the 3d resolution so weak or hot machines stay playable
# and strong machines are left alone

const SAVE_PATH := "user://settings.cfg"
# bump this when presets or the file layout change, old files get re-detected
const SETTINGS_VERSION := 2
const DEF_PRESET := "Medium"
const DEF_RES := Vector2i(1920, 1080)
const DEF_FPS := 0 

const TIER_ORDER := ["Low", "Medium", "High", "Ultra"]

# dynamic resolution
const DYN_TARGET_FPS := 60.0 # only react when gpu time cant fit this
const DYN_WINDOW := 1.0 # seconds of samples averaged before deciding
const DYN_COOLDOWN := 3.0 # changing res rebuilds buffers, dont do it often
const DYN_WARMUP := 6.0 # first seconds are shader compiles and loading
const DYN_STEP := 0.05
const DYN_MIN_SCALE := 0.5
const DYN_DOWN_AT := 0.9 # drop res when gpu time is over 90% of the budget
const DYN_UP_AT := 0.6 # raise res when gpu time is under 60% of the budget
const NATIVE_CUTOFF := 0.99 # at or above this we render native, no upscaler

# one table instead of four copy pasted blocks
const PRESETS := {
	"Low": {
		"scale": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": true,
		"shadow_quality": RenderingServer.SHADOW_QUALITY_HARD,
		"dir_shadow_size": 2048,
		"pos_shadow_size": 1024,
		"lod": 2.5,
		"debanding": false,
	},
	"Medium": {
		"scale": 0.85,
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"dir_shadow_size": 4096,
		"pos_shadow_size": 2048,
		"lod": 1.5,
		"debanding": true,
	},
	"High": {
		"scale": 1.0,
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"dir_shadow_size": 4096,
		"pos_shadow_size": 4096,
		"lod": 1.0,
		"debanding": true,
	},
	"Ultra": {
		"scale": 1.0,
		"msaa": Viewport.MSAA_4X,
		"fxaa": false,
		"shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"dir_shadow_size": 8192,
		"pos_shadow_size": 4096,
		"lod": 0.75,
		"debanding": true,
	},
}

signal settings_applied

var config := ConfigFile.new()

var preset_name: String = DEF_PRESET
var dynamic_res := true
var base_scale := 1.0 # what the preset asked for, dynamic res never goes above it
var cur_scale := 1.0 # what we are actually rendering at right now

var vp_rid: RID
var gpu_sum := 0.0
var gpu_samples := 0
var window_time := 0.0
var cooldown := DYN_WARMUP


func _ready() -> void:
	vp_rid = get_viewport().get_viewport_rid()

	var loaded: bool = config.load(SAVE_PATH) == OK
	var version: int = int(config.get_value("meta", "version", 0))
	if loaded and version == SETTINGS_VERSION:
		load_settings()
	else:
		_auto_setup()


# ---------- AUTO SETUP ----------

func _auto_setup() -> void:
	config.clear()
	var screen: int = DisplayServer.window_get_current_screen()
	var res: Vector2i = DisplayServer.screen_get_size(screen)

	set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	set_resolution(res)
	set_vsync(false)
	set_max_fps(DEF_FPS)
	set_dynamic_res(true)
	apply_graphics_preset(_recommended_preset())
	save_settings()


# ---------- HARDWARE ----------

func _recommended_preset() -> String:
	var gpu: String = RenderingServer.get_video_adapter_name().to_lower()
	var cores: int = OS.get_processor_count()
	var tier: String = _gpu_tier(gpu)

	if cores <= 2:
		return "Low"

	# few threads means the cpu is the wall, so drop one tier (but never to Low)
	if cores <= 4:
		var idx: int = TIER_ORDER.find(tier)
		if idx > 1:
			tier = TIER_ORDER[idx - 1]

	return tier


func _gpu_tier(gpu: String) -> String:
	# apple silicon reports as integrated but is far stronger than intel igpus
	if "apple" in gpu:
		return "High"

	# ask the driver first, names are only a guess
	var kind: int = RenderingServer.get_video_adapter_type()
	if kind == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU \
	or kind == RenderingDevice.DEVICE_TYPE_CPU \
	or kind == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		return "Low"

	# name checks for when the driver doesnt say
	if "uhd" in gpu or "iris" in gpu or "hd graphics" in gpu:
		return "Low"
	if " gt " in gpu:
		return "Low"

	if "arc" in gpu:
		if " a7" in gpu or " b5" in gpu or " b7" in gpu:
			return "High"
		return "Medium"

	if "rtx 50" in gpu or "rtx 40" in gpu:
		return "Ultra"
	if "rtx" in gpu:
		return "High"

	if "gtx" in gpu:
		return "Medium"

	if "rx 9" in gpu:
		return "Ultra"
	if "rx 7" in gpu or "rx 6" in gpu:
		return "High"
	if "rx 5" in gpu or "rx 4" in gpu:
		return "Medium"

	# unknown gpus land in the middle, dynamic res fixes a wrong guess
	return DEF_PRESET


# ---------- GRAPHICS ----------

func apply_graphics_preset(preset: String) -> void:
	if not PRESETS.has(preset):
		preset = DEF_PRESET
	preset_name = preset

	var p: Dictionary = PRESETS[preset]
	var vp: Viewport = get_viewport()

	vp.positional_shadow_atlas_size = p["pos_shadow_size"]
	RenderingServer.directional_shadow_atlas_set_size(p["dir_shadow_size"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["shadow_quality"])
	RenderingServer.positional_soft_shadow_filter_set_quality(p["shadow_quality"])
	# higher lod threshold swaps to simpler meshes sooner, only affects meshes with lods
	vp.mesh_lod_threshold = p["lod"]
	vp.use_debanding = p["debanding"]

	base_scale = p["scale"]
	cur_scale = base_scale
	_apply_scale(cur_scale)
	_reset_window()
	cooldown = DYN_WARMUP

	config.set_value("graphics", "preset", preset)


# scale, upscaler and anti aliasing are decided together because they depend on each other
func _apply_scale(s: float) -> void:
	var vp: Viewport = get_viewport()
	var p: Dictionary = PRESETS[preset_name]
	var method: String = RenderingServer.get_current_rendering_method()
	var fsr1_ok: bool = method != "gl_compatibility"
	var fsr2_ok: bool = method == "forward_plus"

	var mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR
	if s < NATIVE_CUTOFF:
		# fsr2 has a fixed cost per output pixel, weak gpus cant afford it so they get fsr1
		if fsr2_ok and preset_name != "Low":
			mode = Viewport.SCALING_3D_MODE_FSR2
		elif fsr1_ok:
			mode = Viewport.SCALING_3D_MODE_FSR

	# fsr2 brings its own temporal aa, msaa or fxaa on top is wasted work
	var fsr2_on: bool = mode == Viewport.SCALING_3D_MODE_FSR2

	if vp.scaling_3d_mode != mode:
		vp.scaling_3d_mode = mode
	if not is_equal_approx(vp.scaling_3d_scale, s):
		vp.scaling_3d_scale = s
	vp.fsr_sharpness = 0.2

	var msaa: Viewport.MSAA = Viewport.MSAA_DISABLED if fsr2_on else p["msaa"]
	if vp.msaa_3d != msaa:
		vp.msaa_3d = msaa

	var want_fxaa: bool = p["fxaa"] and not fsr2_on
	vp.screen_space_aa = (
		Viewport.SCREEN_SPACE_AA_FXAA if want_fxaa
		else Viewport.SCREEN_SPACE_AA_DISABLED
	)


# ---------- DYNAMIC RESOLUTION ----------

func set_dynamic_res(enabled: bool) -> void:
	dynamic_res = enabled
	# gpu time measuring only runs while we need it
	RenderingServer.viewport_set_measure_render_time(vp_rid, enabled)
	set_process(enabled)
	_reset_window()
	cooldown = DYN_WARMUP

	if not enabled and not is_equal_approx(cur_scale, base_scale):
		cur_scale = base_scale
		_apply_scale(cur_scale)

	config.set_value("graphics", "dynamic_res", enabled)


func _reset_window() -> void:
	gpu_sum = 0.0
	gpu_samples = 0
	window_time = 0.0


func _process(delta: float) -> void:
	# a huge delta is a loading hitch or an alt tab, not a real sample
	if delta > 0.25:
		return

	cooldown -= delta
	if cooldown > 0.0:
		return

	# resolution only helps when the gpu is the bottleneck, so measure gpu time not fps
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	if gpu_ms <= 0.0:
		return # driver gave nothing, leave the res alone

	gpu_sum += gpu_ms
	gpu_samples += 1
	window_time += delta
	if window_time < DYN_WINDOW:
		return

	var avg: float = gpu_sum / gpu_samples
	_reset_window()

	var budget: float = 1000.0 / DYN_TARGET_FPS
	var new_scale: float = cur_scale
	if avg > budget * DYN_DOWN_AT:
		new_scale = maxf(DYN_MIN_SCALE, cur_scale - DYN_STEP)
	elif avg < budget * DYN_UP_AT:
		new_scale = minf(base_scale, cur_scale + DYN_STEP)

	new_scale = snappedf(new_scale, DYN_STEP)
	if is_equal_approx(new_scale, cur_scale):
		return

	cur_scale = new_scale
	_apply_scale(cur_scale)
	cooldown = DYN_COOLDOWN


# ---------- DISPLAY ----------

func set_resolution(size: Vector2i) -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_WINDOWED \
	or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_size(size)

		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
			var screen: int = DisplayServer.window_get_current_screen()
			var pos: Vector2i = DisplayServer.screen_get_position(screen)
			var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
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
	var final_fps: int = max(fps, 0)
	Engine.max_fps = final_fps
	config.set_value("graphics", "max_fps", final_fps)


# ---------- SAVE / LOAD ----------

func save_settings() -> void:
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.save(SAVE_PATH)
	settings_applied.emit()


func load_settings() -> void:
	var preset: String = config.get_value("graphics", "preset", DEF_PRESET)
	var mode: DisplayServer.WindowMode = config.get_value(
		"graphics",
		"window_mode",
		DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	var res: Vector2i = config.get_value("graphics", "resolution", DEF_RES)
	var vsync: bool = config.get_value("graphics", "vsync", false)
	var fps: int = config.get_value("graphics", "max_fps", DEF_FPS)
	var dyn: bool = config.get_value("graphics", "dynamic_res", true)

	set_window_mode(mode)
	set_resolution(res)
	set_vsync(vsync)
	set_max_fps(fps) # the old version passed 0 here and ignored the saved value
	set_dynamic_res(dyn)
	apply_graphics_preset(preset)
	settings_applied.emit()


# ---------- GETTERS ----------

func get_current_preset() -> String:
	return config.get_value("graphics", "preset", DEF_PRESET)


func get_current_resolution() -> Vector2i:
	return config.get_value("graphics", "resolution", DEF_RES)


func get_current_window_mode() -> DisplayServer.WindowMode:
	return config.get_value(
		"graphics",
		"window_mode",
		DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func get_vsync_enabled() -> bool:
	return config.get_value("graphics", "vsync", false)


func get_max_fps() -> int:
	return config.get_value("graphics", "max_fps", DEF_FPS)


func get_dynamic_res() -> bool:
	return config.get_value("graphics", "dynamic_res", true)


# handy for a debug label
func get_render_scale() -> float:
	return cur_scale
