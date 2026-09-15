extends Control

signal pause_requested
const RADIUS := 84.0
const DEAD_ZONE := 0.15
var player: CharacterBody3D
var move_finger := -1
var look_finger := -1
var stick := Vector2.ZERO

func _ready() -> void:
	player.input_stopped.connect(reset)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	visible = is_instance_valid(player) and player.playing
	if not visible: reset()
	queue_redraw()

func reset() -> void:
	move_finger = -1
	look_finger = -1
	stick = Vector2.ZERO
	if is_instance_valid(player):
		player.touch_axis = Vector2.ZERO
		player.touch_running = false
		player.touch_jump = false

func stick_center() -> Vector2:
	return Vector2(144, size.y - 144)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not player.playing:
		reset()
		return
	# Releases are observed even when the finger ends over another control.
	if event is InputEventScreenTouch and not event.pressed:
		if event.index == move_finger:
			move_finger = -1
			stick = Vector2.ZERO
			player.touch_axis = Vector2.ZERO
			player.touch_running = false
		elif event.index == look_finger:
			look_finger = -1
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			_move(event.position)
		elif event.index == look_finger:
			player.look_by(event.relative * 0.003)
		else: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not player.playing: return
	if not event is InputEventScreenTouch or not event.pressed: return
	if Rect2(size.x - 104, 24, 72, 72).has_point(event.position):
		reset()
		pause_requested.emit()
	elif event.position.distance_to(Vector2(size.x - 112, size.y - 120)) <= 48:
		player.touch_jump = true
	elif move_finger == -1 and event.position.distance_to(stick_center()) <= RADIUS * 1.5:
		move_finger = event.index
		_move(event.position)
	elif look_finger == -1 and event.position.x > size.x * 0.45:
		look_finger = event.index
	else: return
	get_viewport().set_input_as_handled()

func _move(point: Vector2) -> void:
	stick = ((point - stick_center()) / RADIUS).limit_length()
	var strength := stick.length()
	player.touch_axis = stick.normalized() * maxf(0, (strength - DEAD_ZONE) / (1 - DEAD_ZONE))
	player.touch_running = strength > 0.9

func _draw() -> void:
	var ink := Color(1, 1, 1, 0.5)
	var fill := Color(0.05, 0.07, 0.08, 0.25)
	draw_circle(stick_center(), RADIUS, fill)
	draw_arc(stick_center(), RADIUS, 0, TAU, 64, ink, 2, true)
	draw_circle(stick_center() + stick * RADIUS, 28, ink)
	var jump := Vector2(size.x - 112, size.y - 120)
	draw_circle(jump, 48, fill)
	draw_arc(jump, 48, 0, TAU, 48, ink, 2, true)
	draw_polyline(PackedVector2Array([jump + Vector2(-16, 4), jump + Vector2(0, -12), jump + Vector2(16, 4)]), ink, 4, true)
	draw_line(jump + Vector2(0, -12), jump + Vector2(0, 20), ink, 4, true)
	var pause := Vector2(size.x - 68, 60)
	draw_circle(pause, 36, fill)
	for x in [-8, 8]:
		draw_line(pause + Vector2(x, -12), pause + Vector2(x, 12), ink, 5, true)
