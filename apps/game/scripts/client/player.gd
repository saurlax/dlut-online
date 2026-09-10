extends CharacterBody3D

const Movement = preload("res://scripts/shared/movement.gd")
const WALK_SPEED := 6.0
const RUN_SPEED := 13.0
const JUMP_SPEED := 7.0
const EYE_HEIGHT := 1.7
const SPAWN := Vector3(12,0.35,387)
var guest_id := ""
var username := ""
var spawn_position := SPAWN
var camera: Camera3D
var playing := false
var network_ready := false
var jump_sequence := 0
var visual_offset := Vector3.ZERO
var drag_look := false
var pitch := 0.0

func _ready() -> void:
	name = "Player"
	position = spawn_position
	Movement.setup(self)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = EYE_HEIGHT
	camera.fov = 75
	camera.near = 0.08
	camera.far = 2200
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (drag_look and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_LEFT)) != 0)):
		rotate_y(-event.relative.x*0.0025)
		pitch = clampf(pitch-event.relative.y*0.0025,-1.45,1.45)
		camera.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	return (global_basis * Vector3(input.x,0,input.y)).normalized()

func _physics_process(delta: float) -> void:
	var active := network_ready and playing and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or drag_look)
	var axis := Input.get_vector("move_left","move_right","move_forward","move_back") if active else Vector2.ZERO
	var jumping := active and Input.is_action_just_pressed("jump")
	if jumping: jump_sequence += 1
	Movement.step(self, axis, active and Input.is_action_pressed("run"), jumping, delta, spawn_position)
	visual_offset = visual_offset.lerp(Vector3.ZERO, minf(1.0, delta * 12))
	camera.position = Vector3(0, EYE_HEIGHT, 0) + basis.inverse() * visual_offset

func stop() -> void:
	playing = false
	drag_look = false
	velocity = Vector3.ZERO

func correct_position(offset: Vector3) -> void:
	position += offset
	if offset.length() < 2.0: visual_offset -= offset
	else: visual_offset = Vector3.ZERO
