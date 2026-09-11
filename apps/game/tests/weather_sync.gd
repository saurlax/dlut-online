extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	var account = load("res://scripts/client/account_session.gd")
	account.token = OS.get_environment("DO_TEST_ACCOUNT_TOKEN")
	account.player_id = OS.get_environment("DO_TEST_ACCOUNT_ID")
	change_scene_to_file("res://scenes/campuses/lingshui.tscn")
	await process_frame
	await process_frame
	current_scene.hud._account_authenticated()
	var net: Node = root.get_node("GameNetwork")
	while not net.welcomed or net.campus_weather.size() != 3: await process_frame
	assert(absf(net.environment_unix_time()-Time.get_unix_time_from_system()) < 5.0)
	assert(net.campus_weather.lingshui.cloud_cover == 10 and net.campus_weather.eda.cloud_cover == 95 and net.campus_weather.panjin.cloud_cover == 55)
	var connection: ENetPacketPeer = net.socket
	var before: float = net.environment_unix_time()
	current_scene.hud.pause_exploration()
	await create_timer(0.4).timeout
	assert(net.environment_unix_time() > before+0.3,"Pausing movement must not stop real time")
	for campus: String in ["eda","panjin","lingshui"]:
		current_scene.hud.teleport(campus)
		while not net.transfer_phase.is_empty(): await process_frame
		assert(current_scene.campus_id == campus and net.socket == connection)
		var sky := current_scene.get_node("CampusEnvironment")
		sky.initialized = false
		sky._update(0.0)
		assert(absf(sky.cloud-net.campus_weather[campus].cloud_cover/100.0)<0.01,"Sky must select destination weather")
		assert(net.environment_unix_time() >= before)
	# Age the received sample locally to exercise visual expiry without waiting hours.
	net.campus_weather.lingshui.observed_at = net.environment_unix_time()-10801
	var sky := current_scene.get_node("CampusEnvironment")
	sky.initialized = false
	sky._update(0.0)
	assert(is_equal_approx(sky.cloud,0.3))
	print("PASS: authenticated weather delivery, server clock, pause, three-campus transfer and stale fallback")
	quit()
