extends ColorRect

signal closed
const Settings = preload("res://scripts/client/graphics_settings.gd")
var draft: Dictionary
var fields: Dictionary = {}
var hints: Dictionary = {}
var status: Label
var apply_button: Button
var close_button: Button
var panel: PanelContainer
var preset_select: OptionButton
var preset_hint: Label

func _ready() -> void:
	name = "GraphicsSettings"
	color = Color(0.01, 0.02, 0.03, 0.82)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182229")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(dismiss)
	header.add_child(close_button)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "图形"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	_build_presets(rows)
	_section(rows, "显示")
	_option(rows, "window_mode", "显示模式", "全屏使用当前显示器分辨率。")
	_option(rows, "vsync", "垂直同步", "减少画面撕裂；开启后帧率受显示器刷新率限制。")
	_option(rows, "fps", "帧率上限", "限制功耗与发热，不改变游戏模拟速度。")
	_section(rows, "画面清晰度")
	_option(rows, "upscaler", "分辨率缩放", "FSR 2 自带时域抗锯齿；MetalFX 需要支持它的 Apple 设备和 Metal 驱动。")
	_option(rows, "scale", "渲染比例", "只改变三维画面分辨率，界面保持清晰。超采样仅适用于双线性。")
	_option(rows, "sharpness", "FSR 锐化", "仅在 FSR 启用时生效；FSR 1 在原生比例下不执行升频。")
	_option(rows, "aa", "抗锯齿", "MSAA 改善几何边缘；SMAA、FXAA 为后处理；TAA 减少闪烁。")
	_option(rows, "anisotropy", "各向异性过滤", "改善支持此过滤的材质在倾斜视角下的纹理清晰度。")
	_section(rows, "光照与阴影")
	_option(rows, "shadows", "阴影质量", "调整太阳阴影分辨率与过滤质量。")
	_option(rows, "shadow_distance", "阴影距离", "更远的阴影增加开销，也会分散近处的阴影精度。")
	_option(rows, "ssao", "环境遮蔽 SSAO", "加强墙角与物体接触处的阴影。")
	_option(rows, "ssil", "间接光照 SSIL", "从屏幕中可见的表面近似计算反弹光。")
	_option(rows, "ssr", "屏幕空间反射 SSR", "改善水面等反射；屏幕外物体无法参与。")
	_option(rows, "sdfgi", "全局光照 SDFGI", "实时反弹光，开销较高；首次开启和移动时可能短暂停顿。")
	_section(rows, "后期效果")
	_option(rows, "glow", "辉光", "让明亮区域产生柔和光晕。")
	_option(rows, "volumetric_fog", "体积雾", "增加光线在薄雾中的散射，开销较高。")
	_option(rows, "debanding", "消除色带", "用轻微抖动缓解天空等渐变区域的色带。")
	_option(rows, "tonemap", "色调映射", "控制明暗与高光过渡，默认 Filmic。")
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	var reset := Button.new()
	reset.text = "恢复默认"
	reset.pressed.connect(func():
		draft = Settings.defaults()
		_refresh()
		status.text = "已恢复默认选项，点击应用生效。"
	)
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	apply_button = Button.new()
	apply_button.text = "应用"
	apply_button.custom_minimum_size.x = 144
	apply_button.pressed.connect(_apply)
	footer.add_child(apply_button)
	resized.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	if not is_instance_valid(panel): return
	panel.position = Vector2(maxf(16, (size.x - 900) * 0.5), 20)
	panel.size = Vector2(minf(900, size.x - 32), size.y - 40)

func _section(rows: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("9bcbd0"))
	label.custom_minimum_size.y = 44
	rows.add_child(label)

func _build_presets(rows: VBoxContainer) -> void:
	_section(rows, "画质预设")
	preset_select = OptionButton.new()
	preset_select.name = "QualityPreset"
	preset_select.custom_minimum_size.y = 44
	preset_select.add_item("自定义")
	preset_select.set_item_metadata(0, "")
	preset_select.set_item_disabled(0, true)
	for id: String in Settings.PRESETS:
		preset_select.add_item(Settings.PRESETS[id].title)
		preset_select.set_item_metadata(preset_select.item_count - 1, id)
	rows.add_child(preset_select)
	preset_hint = Label.new()
	preset_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_hint.add_theme_font_size_override("font_size", 13)
	preset_hint.add_theme_color_override("font_color", Color("aab6c0"))
	rows.add_child(preset_hint)
	preset_select.item_selected.connect(func(index: int):
		var id: String = preset_select.get_item_metadata(index)
		draft = Settings.preset_values(id, draft)
		_refresh()
		status.text = "已选择%s，点击应用生效。" % Settings.PRESETS[id].title
	)

func _option(rows: VBoxContainer, key: String, title: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.custom_minimum_size.y = 72
	rows.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(labels)
	var label := Label.new()
	label.text = title
	labels.add_child(label)
	var hint := Label.new()
	hint.text = description
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("aab6c0"))
	labels.add_child(hint)
	hint.set_meta("description", description)
	hints[key] = hint
	var select := OptionButton.new()
	select.name = key
	select.custom_minimum_size = Vector2(204, 44)
	select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(select)
	var choices: Array = Settings.CHOICES.get(key, [[false, "关闭"], [true, "开启"]])
	for choice in choices:
		select.add_item(choice[1])
		select.set_item_metadata(select.item_count - 1, choice[0])
	select.item_selected.connect(func(index: int):
		draft[key] = select.get_item_metadata(index)
		draft = Settings.sanitize(draft)
		_refresh()
		status.text = "更改尚未应用。关闭将放弃未应用的更改。"
	)
	fields[key] = select

func open() -> void:
	Settings.ensure_loaded()
	draft = Settings.values.duplicate()
	_refresh()
	status.text = "选择画面效果后点击应用。高画质选项会增加显卡负担。"
	show()
	close_button.grab_focus()

func dismiss() -> void:
	hide()
	closed.emit()

func _refresh() -> void:
	var preset_id := Settings.matching_preset(draft)
	for index in preset_select.item_count:
		if preset_select.get_item_metadata(index) == preset_id: preset_select.select(index)
	preset_hint.text = "已手动调整画质选项。" if preset_id.is_empty() else Settings.PRESETS[preset_id].description
	preset_hint.text += " 预设保留显示模式、垂直同步与帧率上限，不支持的效果自动关闭。"
	for key in fields:
		var select: OptionButton = fields[key]
		var reason := ""
		if not Settings.supported(key, true if typeof(Settings.DEFAULTS[key]) == TYPE_BOOL else draft[key]):
			reason = "当前设备或渲染器不支持此选项。"
		elif key == "aa" and draft.upscaler in [2, 4]: reason = "所选升频方式已包含时域抗锯齿。"
		elif key == "sharpness" and (draft.upscaler not in [1, 2] or (draft.upscaler == 1 and draft.scale == 100)): reason = "启用 FSR 升频后可调整。"
		elif key == "shadow_distance" and draft.shadows == 0: reason = "开启阴影后可调整。"
		select.disabled = not reason.is_empty()
		select.tooltip_text = reason
		hints[key].text = hints[key].get_meta("description") if reason.is_empty() else reason
		for index in select.item_count:
			var value: Variant = select.get_item_metadata(index)
			var available := Settings.supported(key, value)
			if key == "scale" and not Settings.scale_supported(int(value), draft.upscaler): available = false
			select.set_item_disabled(index, not available)
			select.get_popup().set_item_tooltip(index, "" if available else "当前渲染器或缩放模式不支持。")
			if value == draft[key]: select.select(index)
	apply_button.disabled = draft == Settings.values

func _apply() -> void:
	var error := Settings.save_and_apply(draft, get_tree())
	draft = Settings.values.duplicate()
	_refresh()
	status.text = "已应用并保存。" if error == OK else "已应用，但保存失败；下次启动将无法保留。"
	# Allow retrying a failed save without changing the options again.
	apply_button.disabled = error == OK
