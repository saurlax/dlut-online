extends Node3D

@onready var avatar: Node3D = $Avatar
@onready var camera: Camera3D = $Camera3D
@onready var controls: VBoxContainer = $Interface/Panel/Margin/Scroll/Controls

var sliders: Array[HSlider] = []
var sample: OptionButton
var outfit: OptionButton
var motion: OptionButton
var zoom := 3.0
var face_view := false
var dragging := false

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_add_label("人物试衣", 26)
	_add_label("DLUT Online", 16)
	_space(18)
	sample = _choice("人物", ["男生", "女生"], func(index: int) -> void:
		avatar.set_sample(index)
		_update_camera())
	outfit = _choice("服装", ["便装一", "便装二"], func(index: int) -> void: avatar.set_outfit(index))
	_space(10)
	var names := ["脸宽", "下颌", "鼻宽", "嘴宽"]
	for index in names.size():
		_add_label(names[index], 16)
		var slider := HSlider.new()
		slider.min_value = -1.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size.y = 24
		var parameter: StringName = avatar.FACE_PARAMETERS[index]
		slider.value_changed.connect(func(value: float) -> void: avatar.set_face_parameter(parameter, value))
		controls.add_child(slider)
		sliders.append(slider)
	_space(10)
	motion = _choice("动作预览", ["站立", "行走", "奔跑"], func(index: int) -> void: avatar.set_motion([&"idle", &"walk", &"run"][index]))
	var views := HBoxContainer.new()
	controls.add_child(views)
	for title in ["全身", "面部", "背面"]:
		var button := Button.new()
		button.text = title
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40
		button.pressed.connect(func() -> void:
			face_view = title == "面部"
			zoom = 0.68 if face_view else 3.0
			avatar.rotation.y = PI if title == "背面" else 0.0
			_update_camera())
		views.add_child(button)
	var reset := Button.new()
	reset.text = "重置外观"
	reset.custom_minimum_size.y = 40
	reset.pressed.connect(func() -> void:
		avatar.reset_appearance()
		outfit.select(0)
		motion.select(0)
		for slider in sliders:
			slider.set_value_no_signal(0.0))
	controls.add_child(reset)
	_space(8)
	_add_label("拖动人物旋转，滚轮缩放", 14)
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()

func _choice(title: String, options: Array, callback: Callable) -> OptionButton:
	_add_label(title, 16)
	var control := OptionButton.new()
	control.custom_minimum_size.y = 40
	for option in options:
		control.add_item(option)
	control.item_selected.connect(callback)
	controls.add_child(control)
	return control

func _add_label(text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	controls.add_child(label)

func _space(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	controls.add_child(spacer)

func _update_camera() -> void:
	var target_height := 1.59 if face_view else 0.9
	if face_view and avatar.sample_index == 1:
		target_height -= 0.1
	# Keep the model centered in the area to the left of the control panel.
	var size := get_viewport().get_visible_rect().size
	var center_offset := (340.0 / maxf(size.x, 1.0)) * zoom * 0.6
	camera.position = Vector3(center_offset, target_height + (0.0 if face_view else 0.12), zoom)
	camera.look_at(Vector3(center_offset, target_height, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.5, 4.5)
			_update_camera()
	elif event is InputEventMouseMotion and dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		avatar.rotation.y += event.relative.x * 0.01

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
