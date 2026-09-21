extends CharacterBody3D

signal input_stopped

const LocalSession = preload("res://scripts/client/local_session.gd")
const Movement = preload("res://scripts/shared/movement.gd")
const Footsteps = preload("res://scripts/client/footsteps.gd")
const WALK_SPEED := 6.0
const RUN_SPEED := 13.0
const JUMP_SPEED := 7.0
const EYE_HEIGHT := 1.7
const SPAWN := Vector3(12,0.35,387)
var player_id := ""
var username := ""
var spawn_position := SPAWN
var camera: Camera3D
var playing := false
var network_ready := false
var jump_sequence := 0
var visual_offset := Vector3.ZERO
var drag_look := false
var pitch := 0.0
var touch_enabled := OS.has_feature("android")
var touch_axis := Vector2.ZERO
var touch_running := false
var touch_jump := false
var footsteps: Node

func _ready() -> void:
	name = "Player"
	position = spawn_position
	Movement.setup(self)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = EYE_HEIGHT
	camera.fov = 75
	camera.near = 0.08
	camera.far = 12000
	camera.current = true
	add_child(camera)
	footsteps = Footsteps.new()
	add_child(footsteps)

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if not touch_enabled and event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (drag_look and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_LEFT)) != 0)):
		look_by(event.relative * 0.0025)

func look_by(relative: Vector2) -> void:
	rotate_y(-relative.x)
	pitch = clampf(pitch - relative.y, -1.45, 1.45)
	camera.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	return (global_basis * Vector3(input.x,0,input.y)).normalized()

func _physics_process(delta: float) -> void:
	var active := network_ready and playing and (touch_enabled or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or drag_look)
	var axis := Input.get_vector("move_left","move_right","move_forward","move_back") if active else Vector2.ZERO
	if active and touch_axis != Vector2.ZERO: axis = touch_axis
	var jumping := active and (touch_jump or Input.is_action_just_pressed("jump"))
	touch_jump = false
	if jumping: jump_sequence += 1
	var running := active and (touch_running or Input.is_action_pressed("run"))
	var network := get_node("/root/GameNetwork")
	if not LocalSession.enabled: network.begin_prediction(delta, axis, running)
	var movement_start := global_position
	Movement.step(self, axis, running, jumping, delta, spawn_position)
	footsteps.update(self, global_position - movement_start, delta, active and axis.length_squared() > 0.0, running)
	if not LocalSession.enabled: network.end_prediction()

func _process(delta: float) -> void:
	visual_offset *= exp(-12.0 * delta)
	_update_camera_offset()

func _update_camera_offset() -> void:
	camera.position = Vector3(0, EYE_HEIGHT, 0) + basis.inverse() * visual_offset

func stop() -> void:
	if footsteps != null: footsteps.stop()
	playing = false
	drag_look = false
	velocity = Vector3.ZERO
	touch_axis = Vector2.ZERO
	touch_running = false
	touch_jump = false
	input_stopped.emit()

func correct_position(offset: Vector3) -> void:
	position += offset
	if offset.length() < 2.0: visual_offset -= offset
	else: visual_offset = Vector3.ZERO
	# Position and its visual compensation must change atomically, before rendering.
	_update_camera_offset()
