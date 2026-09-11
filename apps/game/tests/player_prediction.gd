extends SceneTree

const Player = preload("res://scripts/client/player.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var network := root.get_node("GameNetwork")
	var sample := {"points":PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -0.1), Vector3(0, 0, -0.2), Vector3(0, 0, -0.3)]),
		"start_velocity":Vector3(0, 0, -6), "end_velocity":Vector3(0, 0, -6)}
	assert(network.prediction_error(Vector3(0, 0, -0.25), sample).length() < 0.0001,
		"An acknowledged input covers multiple physics steps; normal travel is not an error")
	assert(network.prediction_error(Vector3(0, 0, -0.4), sample).length() < 0.0001,
		"A single physics-step sampling boundary must not cause repeated corrections")
	assert(network.prediction_error(Vector3(0, 0, -1), sample).length() > 0.59,
		"Sampling tolerance must remain bounded rather than exempting motion along the input axis")
	assert(network.prediction_error(Vector3(0.5, 0, -0.25), sample).is_equal_approx(Vector3(0.5, 0, 0)))
	var stopped := {"points":PackedVector3Array([Vector3.ZERO]), "start_velocity":Vector3.ZERO, "end_velocity":Vector3.ZERO}
	assert(network.prediction_error(Vector3(0.1, 0, 0), stopped).is_equal_approx(Vector3(0.1, 0, 0)),
		"Stationary errors must not inherit a moving tolerance")

	var body := Player.new()
	root.add_child(body)
	body.set_physics_process(false)
	body.set_process(false)
	body.rotation.y = 0.7
	for fps in [30, 60, 144]:
		body.visual_offset = Vector3.ZERO
		body.correct_position(Vector3.ZERO)
		var before: Vector3 = body.camera.global_position
		body.correct_position(Vector3(0.2, 0, -0.1))
		assert(body.camera.global_position.distance_to(before) < 0.0001,
			"A correction must compensate the camera in the same call, without a physics-frame flash")
		body._process(1.0 / fps)
		assert(body.camera.global_position.distance_to(before) < 0.08,
			"The visual correction must decay continuously on render frames")
		for frame in fps: body._process(1.0 / fps)
		assert(body.visual_offset.length() < 0.0001)
	# Exercise the real physics-step boundary for consecutive start/stop/jump inputs.
	network.player = body
	network.welcomed = true
	body.position = Vector3.ZERO
	body.velocity = Vector3.ZERO
	network.begin_prediction(1.0 / 60, Vector2(0, -1), false)
	var walking_sequence: int = network.sequence
	body.position.z = -0.1
	body.velocity.z = -6.0
	network.end_prediction()
	network.begin_prediction(1.0 / 60, Vector2.ZERO, false)
	assert(network.sequence == walking_sequence + 1, "Releasing movement must send before the next physics step")
	body.velocity = Vector3.ZERO
	network.end_prediction()
	var stopped_sequence: int = network.sequence
	body.jump_sequence += 1
	network.begin_prediction(1.0 / 60, Vector2.ZERO, false)
	assert(network.sequence == stopped_sequence + 1, "Jump edges must not wait for the periodic send")
	body.position.y = 7.0 / 60
	body.velocity.y = 7.0
	network.end_prediction()
	assert(network.history[stopped_sequence].points[-1].y == 0.0,
		"A jump step must never contaminate the preceding stationary interval")
	assert(network.prediction_error(Vector3(0, 0, -0.1), network.history[network.sequence]).length() < 0.0001,
		"The jump interval must include its grounded starting position")
	var jumping_sequence: int = network.sequence
	network.begin_prediction(1.0 / 60, Vector2.ZERO, false)
	assert(network.sequence == jumping_sequence, "Unchanged inputs retain the bounded periodic send")
	network.welcomed = false
	network.player = null
	body.correct_position(Vector3(30, 0, 0))
	assert(body.visual_offset == Vector3.ZERO, "A large authoritative correction must snap instead of dragging the camera")
	for delay_ticks in [3, 6]:
		await _check_delayed_physics(network, delay_ticks)
	print("PASS: prediction interval, bounded sampling, stationary authority and same-frame camera compensation at 30/60/144 Hz")
	quit()

func _check_delayed_physics(network: Node, delay_ticks: int) -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var predicted := Player.new()
	root.add_child(predicted)
	predicted.set_physics_process(false)
	predicted.set_process(false)
	predicted.position = Vector3.ZERO
	var authority := CharacterBody3D.new()
	Player.Movement.setup(authority)
	root.add_child(authority)
	network.player = predicted
	network.welcomed = true
	network.history.clear()
	network.last_input.clear()
	var inputs: Array[Dictionary] = []
	var snapshots: Array[Dictionary] = []
	var server_axis := Vector2.ZERO
	var server_jump := 0
	var server_seq := -1
	var correction_total := 0.0
	var peak := 0.0
	for frame in 180:
		await physics_frame
		var axis := Vector2(0, -1) if frame >= 10 and frame < 50 else Vector2.ZERO
		var jump := frame == 70
		if jump: predicted.jump_sequence += 1
		var previous: int = network.sequence
		network.begin_prediction(1.0 / 60, axis, false)
		if network.sequence != previous:
			inputs.append({"due":frame + delay_ticks, "axis":axis, "jump":predicted.jump_sequence, "seq":network.sequence})
		Player.Movement.step(predicted, axis, false, jump, 1.0 / 60, Vector3.ZERO)
		network.end_prediction()
		var server_jumping := false
		while not inputs.is_empty() and inputs[0].due <= frame:
			var input: Dictionary = inputs.pop_front()
			server_axis = input.axis
			server_seq = input.seq
			server_jumping = server_jumping or input.jump > server_jump
			server_jump = input.jump
		Player.Movement.step(authority, server_axis, false, server_jumping, 1.0 / 60, Vector3.ZERO)
		if frame % 6 == 0 and server_seq >= 0:
			snapshots.append({"due":frame + delay_ticks, "seq":server_seq, "position":[authority.position.x, authority.position.y, authority.position.z], "velocity":[authority.velocity.x, authority.velocity.y, authority.velocity.z]})
		while not snapshots.is_empty() and snapshots[0].due <= frame:
			var snapshot: Dictionary = snapshots.pop_front()
			var before := predicted.position
			network.apply_self(snapshot, false)
			correction_total += before.distance_to(predicted.position)
		predicted._process(1.0 / 60)
		peak = maxf(peak, predicted.position.y)
	assert(peak > 1.0, "The delayed simulation must exercise a complete jump")
	assert(predicted.is_on_floor() and authority.is_on_floor(), "Both simulations must settle after landing")
	assert(correction_total < 0.01, "Normal stop/jump motion must not produce repeated authoritative recoil: %f" % correction_total)
	print("PASS: stop and grounded jump with ", delay_ticks * 1000 / 30, " ms simulated RTT, correction total=", correction_total)
	network.welcomed = false
	network.player = null
	predicted.free()
	authority.free()
	floor_body.free()
