extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var account = load("res://scripts/client/account_session.gd")
	account.token = OS.get_environment("DO_TEST_ACCOUNT_TOKEN")
	account.player_id = OS.get_environment("DO_TEST_ACCOUNT_ID")
	account.username = "Test player"
	assert(not account.token.is_empty())
	create_timer(60).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/campuses/eda.tscn")
	await process_frame
	await process_frame
	current_scene.hud._account_authenticated()
	var net: Node = root.get_node("GameNetwork")
	for frame in 300:
		await process_frame
		if net.welcomed: break
	assert(net.welcomed)
	for frame in 90: await physics_frame
	var body: CharacterBody3D = current_scene.player
	body.playing = true
	body.drag_look = true
	var before: Vector3 = body.position
	Input.action_press("move_forward")
	for frame in 6: await physics_frame
	assert(body.position.distance_to(before)>0.2,"Prediction must start without a network round trip")
	for frame in 90: await physics_frame
	Input.action_release("move_forward")
	for frame in 45: await physics_frame
	var distance := body.position.distance_to(before)
	assert(distance > 8.0 and distance < 11.5,
		"1.6 seconds of walking must stay near 9.6 metres, including bounded network start/stop delay")
	var stable: Vector3 = body.position
	body.position += Vector3(30,0,0)
	for frame in 120: await physics_frame
	assert(body.position.distance_to(stable)<0.5,"Server must correct a forged local position")
	Input.action_press("jump")
	for frame in 6: await physics_frame
	Input.action_release("jump")
	assert(body.position.y>stable.y+0.2,"Jump prediction must respond")
	for frame in 150: await physics_frame
	assert(absf(body.position.y-stable.y)<0.1,"Authoritative jump must settle")
	current_scene.hud.pause_exploration()
	var stopped: Vector3 = body.position
	Input.action_press("move_forward")
	for frame in 60: await physics_frame
	Input.action_release("move_forward")
	assert(body.position.distance_to(stopped)<0.1,"Paused input must stay stopped")
	print("PASS: delayed input prediction, authoritative correction, jump and pause")
	quit()
