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
	body.correct_position(Vector3(30, 0, 0))
	assert(body.visual_offset == Vector3.ZERO, "A large authoritative correction must snap instead of dragging the camera")
	print("PASS: prediction interval, bounded sampling, stationary authority and same-frame camera compensation at 30/60/144 Hz")
	quit()
