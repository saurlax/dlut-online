extends SceneTree
## Local renderer/settings regression; deliberately not part of lightweight CI.
const Settings = preload("res://scripts/client/graphics_settings.gd")
const Local = preload("res://scripts/client/local_session.gd")
const Catalog = preload("res://scripts/shared/campus_catalog.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	Settings.values = Settings.defaults()
	var display_choices := {"window_mode": 1, "fps": 144, "vsync": 0}
	for id: String in Settings.PRESETS:
		var preset := Settings.preset_values(id, display_choices)
		assert(preset.fps == 144 and preset.vsync == 0)
		assert(preset.window_mode == (1 if Settings.supported("window_mode", 1) else 0))
		assert(Settings.matching_preset(preset) == id, "Preset recognition must survive renderer fallback")
		assert(preset == Settings.sanitize(preset))
		preset.scale = 85
		assert(Settings.matching_preset(preset).is_empty())
	assert(Settings.matching_preset(Settings.defaults()) == "balanced")
	assert(Settings.preset_values("unknown", Settings.defaults()) == Settings.defaults())
	var invalid := Settings.sanitize({"fps": -1, "aa": "6", "scale": 9999, "sdfgi": "true"})
	assert(invalid.fps == 60 and invalid.aa == 1 and invalid.scale == 100 and not invalid.sdfgi)
	var temporal := Settings.sanitize({"upscaler": 2, "aa": 6, "scale": 200})
	if Settings.forward_plus():
		assert(temporal.aa == 0 and temporal.scale == 100)
	else:
		assert(temporal.upscaler == 0)
		assert(not Settings.sanitize({"sdfgi": true, "ssil": true}).sdfgi)
	Local.enabled = true
	change_scene_to_file("res://scenes/campuses/lingshui.tscn")
	await process_frame
	await process_frame
	var hud: CanvasLayer = current_scene.hud
	hud.enter_campus()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._input(escape)
	assert(not hud.player.playing and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	hud.settings_button.pressed.emit()
	var panel: ColorRect = hud.settings_panel
	assert(panel.visible and not hud.player.playing)
	panel.preset_select.item_selected.emit(4)
	assert(Settings.matching_preset(panel.draft) == "ultra")
	assert(Settings.values == Settings.defaults(), "Selecting a preset must only modify the draft")
	panel.fields.scale.item_selected.emit(4) # 85% is not a preset.
	assert(panel.preset_select.selected == 0)
	panel.dismiss()
	panel.open()
	assert(panel.preset_select.selected == 2, "Discarded draft must not survive reopening")
	hud.toggle_map()
	assert(not hud.map_overlay.visible)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	hud._unhandled_input(click)
	assert(not hud.player.playing, "Settings clicks must never resume walking")
	panel.draft.fps = 120
	panel.draft.upscaler = 1
	panel.draft.scale = 67
	panel.draft.aa = 3
	# Apply without writing the real user's preferences.
	Settings.values = Settings.sanitize(panel.draft)
	Settings.apply_all(self)
	assert(Engine.max_fps == 120)
	assert(root.msaa_3d == Viewport.MSAA_8X and is_equal_approx(root.scaling_3d_scale, 0.67))
	var world: Environment = current_scene.get_node("CampusEnvironment/WorldEnvironment").environment
	assert(world.ssr_enabled == Settings.values.ssr)
	var density := world.fog_density
	Settings.values.ssao = Settings.forward_plus()
	Settings.values.ssil = Settings.forward_plus()
	Settings.values.sdfgi = Settings.forward_plus()
	Settings.values.shadows = 0
	Settings.apply_all(self)
	assert(world.sdfgi_enabled == Settings.forward_plus() and world.ssao_enabled == Settings.forward_plus())
	assert(not current_scene.get_node("CampusEnvironment/Sun").shadow_enabled)
	assert(world.fog_density == density, "Graphics settings must preserve weather fog")
	hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(panel.visible and not hud.player.playing)
	hud._input(escape)
	assert(not panel.visible and not hud.player.playing)
	hud._input(escape)
	assert(hud.player.playing)
	# A new campus must inherit the configuration without resetting the cap.
	change_scene_to_file("res://scenes/campuses/eda.tscn")
	await process_frame
	await process_frame
	assert(Engine.max_fps == 120 and is_equal_approx(root.scaling_3d_scale, 0.67))
	assert(current_scene.get_node("CampusEnvironment/WorldEnvironment").environment.sdfgi_enabled == Settings.forward_plus())
	assert(root.get_node("GameNetwork").host == null, "Local graphics must not connect to a server")
	Settings.values = Settings.defaults()
	Settings.apply_all(self)
	Catalog.started = false
	print("PASS: graphics normalization, renderer gating, modal input/focus, weather preservation and campus inheritance")
	quit()
