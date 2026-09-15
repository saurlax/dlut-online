extends SceneTree

const Player = preload("res://scripts/client/player.gd")
const Touch = preload("res://scripts/client/touch_controls.gd")
const LocalSession = preload("res://scripts/client/local_session.gd")
var player: CharacterBody3D
var touch: Control

func _initialize() -> void:
	_run.call_deferred()

func press(index: int, point: Vector2, down := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	LocalSession.enabled = true
	root.size = Vector2i(1280, 720)
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "run"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	player = Player.new()
	player.spawn_position = Vector3(0, 0.1, 0)
	player.touch_enabled = true
	world.add_child(player)
	player.playing = true
	player.network_ready = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	touch = Touch.new()
	touch.player = player
	layer.add_child(touch)
	touch.pause_requested.connect(player.stop)
	for frame in 12: await physics_frame
	assert(player.is_on_floor())
	var center: Vector2 = touch.stick_center()
	press(0, center)
	assert(player.touch_axis == Vector2.ZERO)
	drag(0, center + Vector2(0, -84), Vector2(0, -84))
	press(1, Vector2(800, 300))
	drag(1, Vector2(840, 320), Vector2(40, 20))
	assert(player.rotation.y < 0 and player.pitch < 0)
	assert(player.touch_axis.y == -1 and player.touch_running)
	var start: Vector3 = player.position
	for frame in 12: await physics_frame
	assert(player.position.distance_to(start) > 0.5)
	press(0, Vector2(1100, 100), false)
	assert(player.touch_axis == Vector2.ZERO and not player.touch_running)
	var yaw: float = player.rotation.y
	drag(1, Vector2(880, 320), Vector2(40, 0))
	assert(player.rotation.y < yaw) # Releasing movement must preserve the look finger.
	press(1, Vector2(880, 320), false)
	press(2, Vector2(1168, 600))
	for frame in 3: await physics_frame
	assert(player.velocity.y > 0 and not player.touch_jump)
	press(2, Vector2(1168, 600), false)
	press(0, center + Vector2(0, -84))
	press(3, Vector2(1212, 60))
	assert(not player.playing and player.touch_axis == Vector2.ZERO)
	await process_frame
	assert(touch.move_finger == -1 and touch.look_finger == -1)
	player.playing = true
	await process_frame
	drag(0, center + Vector2(84, 0), Vector2(84, 84))
	assert(player.touch_axis == Vector2.ZERO) # Stale touch cannot resume motion.
	press(4, center + Vector2(0, -84))
	player.stop() # Map opening, transfer and focus loss use this same reset.
	await process_frame
	assert(player.touch_axis == Vector2.ZERO and touch.move_finger == -1)
	world.queue_free()
	layer.queue_free()
	await process_frame
	print("PASS: touch movement, simultaneous look, release, jump, pause and stale-finger reset")
	quit()
