extends SceneTree

const Account = preload("res://scripts/client/account_session.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	Account.clear()
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud.enter_campus()
	assert(current_scene.hud.overlay.visible and not current_scene.player.playing, "Anonymous users cannot dismiss the cover")
	var session: Node = current_scene.hud.account_login
	session.listener = TCPServer.new()
	assert(session.listener.listen(0, "127.0.0.1") == OK)
	var port: int = session.listener.get_local_port()
	session.waiting = true
	session.deadline = Time.get_ticks_msec() + 10000
	session.state = "expected"
	session.request_id = "request"
	var http := HTTPRequest.new()
	root.add_child(http)
	http.timeout = 3
	assert(http.request("http://127.0.0.1:%d/callback?code=forged&request=request&state=wrong" % port) == OK)
	var response: Array = await http.request_completed
	assert(response[1] == 400 and Account.token.is_empty() and session.waiting, "Wrong state must not authenticate or cancel the real request")
	session.cancel()
	assert(not session.waiting and session.listener == null and session.verifier.is_empty())
	Account.token = "expired"
	Account.player_id = "account12345678"
	var catalog = load("res://scripts/shared/campus_catalog.gd")
	catalog.started = true
	current_scene.player.stop()
	root.get_node("GameNetwork").connected.emit()
	assert(not current_scene.player.playing, "Reconnect must preserve pause")
	root.get_node("GameNetwork").require_login()
	assert(Account.token.is_empty() and current_scene.hud.overlay.visible)
	assert(not current_scene.player.playing)
	http.queue_free()
	print("PASS: anonymous cover, callback state validation, cancellation and expired session")
	quit()
