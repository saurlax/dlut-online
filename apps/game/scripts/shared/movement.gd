extends RefCounted

const WALK_SPEED := 6.0
const RUN_SPEED := 13.0
const JUMP_SPEED := 7.0

static func setup(body: CharacterBody3D) -> void:
	body.floor_snap_length = 0.35
	body.floor_max_angle = deg_to_rad(46)
	body.collision_layer = 2
	body.collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)

static func step(body: CharacterBody3D, axis: Vector2, running: bool, jumping: bool, delta: float, spawn: Vector3) -> void:
	var direction := body.basis * Vector3(axis.x, 0, axis.y).limit_length()
	var speed := RUN_SPEED if running else WALK_SPEED
	body.velocity.x = direction.x * speed
	body.velocity.z = direction.z * speed
	if not body.is_on_floor():
		body.velocity.y -= 20.0 * delta
	else:
		body.velocity.y = JUMP_SPEED if jumping else 0.0
	body.move_and_slide()
	if body.position.y < -30:
		body.position = spawn
		body.velocity = Vector3.ZERO
