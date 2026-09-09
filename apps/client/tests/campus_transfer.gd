extends SceneTree
func _initialize() -> void: _run.call_deferred()
func wait_transfer(net: Node) -> void:
	for frame in 600:
		await process_frame
		if net.transfer_phase.is_empty(): return
	assert(false,"transfer did not finish")
func _run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud.enter_campus()
	var net := root.get_node("GameNetwork")
	for frame in 300:
		await process_frame
		if net.welcomed: break
	assert(net.welcomed)
	var ws: WebSocketPeer = net.socket
	var admission: String = net.admission_id
	var world := current_scene
	# Hold resource completion to exercise the real transfer state independently of download speed.
	net.map_prepared.disconnect(world.hud._network_map_prepared)
	world.hud.teleport("eda")
	for frame in 300:
		await process_frame
		if net.transfer_phase == "preparing": break
	assert(net.transfer_phase == "preparing")
	world.hud._pack_completed(false)
	await wait_transfer(net)
	assert(current_scene == world and net.player.network_ready,"Failed download must return to original scene")
	world.hud.teleport("eda")
	world.hud.cancel_transfer()
	await wait_transfer(net)
	assert(current_scene == world,"Cancel before prepare must not migrate")
	world.hud.teleport("eda")
	for frame in 300:
		await process_frame
		if net.transfer_phase == "preparing": break
	await create_timer(20).timeout
	assert(net.socket == ws and net.welcomed and not net.player.network_ready,"Long load must keep heartbeat and freeze movement")
	net.load_target("eda")
	await wait_transfer(net)
	assert(current_scene.campus_id == "eda")
	assert(net.socket == ws and net.admission_id == admission,"Failure, cancel and load must preserve session")
	print("PASS: failed load rollback, early cancel, >15s loading heartbeats, same-connection completion")
	quit()
