extends SceneTree
func _initialize() -> void: _run.call_deferred()
func request(path: String) -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	http.timeout = 5
	assert(http.request(OS.get_environment("DO_API_SERVER_URL")+path) == OK)
	var result: Array = await http.request_completed
	http.queue_free()
	assert(result[1] == 200)
	return JSON.parse_string(result[3].get_string_from_utf8())
func _run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud.enter_campus()
	var net := root.get_node("GameNetwork")
	while not net.welcomed: await process_frame
	var peer: ENetPacketPeer = net.socket
	var admission: String = net.admission_id
	await create_timer(6).timeout
	await request("/test/outage")
	await create_timer(17).timeout
	assert((await request("/api/v1/game/online")).status == "stale")
	assert(net.welcomed and net.socket == peer)
	current_scene.hud.teleport("eda")
	while net.transfer_phase != "": await process_frame
	assert(current_scene.campus_id == "eda")
	await request("/test/restart")
	for i in 20:
		await create_timer(1).timeout
		if (await request("/api/v1/game/online")).status == "live": break
	var online := await request("/api/v1/game/online")
	assert(online.status == "live" and online.total == 1 and online.campuses.eda == 1)
	assert(net.socket == peer and net.admission_id == admission)
	print("PASS: internal HTTP outage and Go state restart preserve ENet session and map travel; presence recovers")
	quit()
