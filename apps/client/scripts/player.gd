extends CharacterBody3D

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
var drag_look := false
var pitch := 0.0

func _ready() -> void:
	name = "Player"
	position = spawn_position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
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
	var active := playing and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or drag_look)
	var direction := movement_direction(Input.get_vector("move_left","move_right","move_forward","move_back")) if active else Vector3.ZERO
	var speed := RUN_SPEED if active and Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	if not is_on_floor():
		velocity.y -= 20*delta
	else:
		velocity.y = JUMP_SPEED if active and Input.is_action_just_pressed("jump") else 0.0
	move_and_slide()
	if position.y < -30:
		position = spawn_position
		velocity = Vector3.ZERO

func stop() -> void:
	playing = false
	drag_look = false
	velocity = Vector3.ZERO
