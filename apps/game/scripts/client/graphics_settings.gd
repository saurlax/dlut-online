extends RefCounted
## Local graphics preferences. No autoload or server-side configuration.

const CONFIG_PATH := "user://graphics.cfg"
const GROUP := "graphics_environments"
const DEFAULTS := {
	"window_mode": 0, "vsync": 1, "fps": 60,
	"upscaler": 0, "scale": 100, "sharpness": 80, "aa": 1,
	"anisotropy": 2, "shadows": 2, "shadow_distance": 250,
	"ssao": false, "ssil": false, "ssr": true, "sdfgi": false,
	"glow": false, "volumetric_fog": false, "debanding": false,
	"tonemap": 2,
}
const CHOICES := {
	"window_mode": [[0, "窗口"], [1, "全屏"]],
	"vsync": [[0, "关闭"], [1, "开启"]],
	"fps": [[30, "30 FPS"], [60, "60 FPS"], [90, "90 FPS"], [120, "120 FPS"], [144, "144 FPS"], [165, "165 FPS"], [240, "240 FPS"], [0, "不限制"]],
	"upscaler": [[0, "双线性"], [1, "FSR 1.0"], [2, "FSR 2.2"], [3, "MetalFX 空间"], [4, "MetalFX 时域"]],
	"scale": [[50, "50%"], [59, "59%"], [67, "67%"], [77, "77%"], [85, "85%"], [100, "100% 原生"], [125, "125% 超采样"], [150, "150% 超采样"], [200, "200% 超采样"]],
	"sharpness": [[0, "0% 柔和"], [25, "25%"], [50, "50%"], [75, "75%"], [80, "80%"], [100, "100% 锐利"]],
	"aa": [[0, "关闭"], [1, "MSAA 2×"], [2, "MSAA 4×"], [3, "MSAA 8×"], [4, "FXAA"], [5, "SMAA"], [6, "TAA"]],
	"anisotropy": [[0, "关闭"], [1, "2×"], [2, "4×"], [3, "8×"], [4, "16×"]],
	"shadows": [[0, "关闭"], [1, "低"], [2, "中"], [3, "高"]],
	"shadow_distance": [[100, "100 米"], [250, "250 米"], [500, "500 米"]],
	"tonemap": [[0, "Linear"], [1, "Reinhard"], [2, "Filmic"], [3, "ACES"], [4, "AgX"]],
}
static var values: Dictionary = {}

static func forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

static func supported(key: String, value: Variant) -> bool:
	var method := RenderingServer.get_current_rendering_method()
	if key == "window_mode": return not OS.has_feature("mobile")
	if key in ["ssao", "ssil", "ssr", "sdfgi", "volumetric_fog"]: return forward_plus() or not bool(value)
	if key == "upscaler":
		if int(value) in [3, 4]:
			var device := RenderingServer.get_rendering_device()
			return forward_plus() and device != null and device.has_feature(RenderingDevice.SUPPORTS_METALFX_SPATIAL if int(value) == 3 else RenderingDevice.SUPPORTS_METALFX_TEMPORAL)
		return int(value) == 0 or forward_plus()
	if key == "aa": return int(value) < 4 or (method != "gl_compatibility" and (int(value) < 6 or forward_plus()))
	if key == "debanding": return method != "gl_compatibility" or not bool(value)
	return true

static func defaults() -> Dictionary:
	return sanitize(DEFAULTS)

static func sanitize(source: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for key in DEFAULTS:
		var value: Variant = source.get(key, DEFAULTS[key])
		if typeof(DEFAULTS[key]) == TYPE_BOOL:
			if typeof(value) == TYPE_BOOL: result[key] = value
		elif typeof(value) == TYPE_INT:
			for choice in CHOICES[key]:
				if choice[0] == value: result[key] = value
		if not supported(key, result[key]):
			result[key] = false if typeof(DEFAULTS[key]) == TYPE_BOOL else 0
	if result.upscaler != 0: result.scale = mini(result.scale, 100)
	if result.upscaler in [2, 4]: result.aa = 0
	if result.upscaler == 4 and not scale_supported(result.scale, 4): result.scale = 100
	return result

static func scale_supported(scale: int, upscaler: int) -> bool:
	if upscaler != 0 and scale > 100: return false
	if upscaler == 4:
		var device := RenderingServer.get_rendering_device()
		if device == null: return false
		var minimum := device.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MIN_SCALE) / 1000000.0
		var maximum := device.limit_get(RenderingDevice.LIMIT_METALFX_TEMPORAL_SCALER_MAX_SCALE) / 1000000.0
		return float(scale) / 100.0 >= minimum and float(scale) / 100.0 <= maximum
	return true

static func ensure_loaded() -> void:
	if not values.is_empty(): return
	var config := ConfigFile.new()
	var loaded := {}
	if config.load(CONFIG_PATH) == OK:
		for key in DEFAULTS: loaded[key] = config.get_value("graphics", key, DEFAULTS[key])
	values = sanitize(loaded)

static func save_and_apply(source: Dictionary, tree: SceneTree) -> Error:
	values = sanitize(source)
	apply_all(tree)
	var config := ConfigFile.new()
	for key in values: config.set_value("graphics", key, values[key])
	return config.save(CONFIG_PATH)

static func apply_all(tree: SceneTree) -> void:
	ensure_loaded()
	apply_display()
	apply_viewport(tree.root)
	for node in tree.get_nodes_in_group(GROUP): node.apply_graphics_settings()

static func apply_display() -> void:
	ensure_loaded()
	Engine.max_fps = values.fps
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync == 1 else DisplayServer.VSYNC_DISABLED)
	if not OS.has_feature("mobile"):
		var mode := DisplayServer.window_get_mode()
		if values.window_mode == 1 and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif values.window_mode == 0 and mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	RenderingServer.directional_shadow_atlas_set_size([1024, 1024, 2048, 4096][values.shadows], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([0, 0, 2, 4][values.shadows])

static func apply_viewport(viewport: Viewport) -> void:
	ensure_loaded()
	viewport.scaling_3d_mode = values.upscaler
	viewport.scaling_3d_scale = float(values.scale) / 100.0
	# Godot's FSR parameter is inverse sharpness: 0 is sharpest, 2 softest.
	viewport.fsr_sharpness = 2.0 * (1.0 - float(values.sharpness) / 100.0)
	viewport.msaa_3d = values.aa if values.aa in [1, 2, 3] else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = values.aa - 3 if values.aa in [4, 5] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = values.aa == 6 and values.upscaler not in [2, 4]
	viewport.anisotropic_filtering_level = values.anisotropy
	viewport.use_debanding = values.debanding

static func apply_environment(environment: Environment, sun: DirectionalLight3D) -> void:
	ensure_loaded()
	for key in ["ssao", "ssil", "ssr", "sdfgi", "glow", "volumetric_fog"]:
		environment.set(key + "_enabled", values[key])
	# Preserve the time/weather controller's ordinary fog. Volumetric fog is
	# an optional thin scattering layer, not a replacement weather preset.
	environment.volumetric_fog_density = 0.0002
	environment.tonemap_mode = values.tonemap
	sun.shadow_enabled = values.shadows != 0
	sun.directional_shadow_max_distance = values.shadow_distance
