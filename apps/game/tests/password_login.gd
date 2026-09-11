extends SceneTree
const Account = preload("res://scripts/client/account_session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	var session := Account.new()
	root.add_child(session)
	var email := "client@example.com"
	await session.begin(email, "wrong-password")
	assert(Account.token.is_empty() and not session.waiting)
	session.begin(email, "correct-horse-battery-staple")
	session.cancel()
	await create_timer(0.3).timeout
	assert(Account.token.is_empty() and not session.waiting)
	await session.begin(email, "correct-horse-battery-staple")
	assert(not Account.token.is_empty() and Account.player_id.length() == 15 and Account.username == "Client player")
	assert(not session.waiting and session.pending == null)
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud._account_authenticated()
	var network := root.get_node("GameNetwork")
	var deadline := Time.get_ticks_msec() + 10000
	while not network.welcomed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(network.welcomed and not current_scene.hud.overlay.visible)
	network.require_login()
	assert(Account.token.is_empty() and current_scene.hud.overlay.visible)
	assert(current_scene.hud.password_input.editable)
	Account.clear()
	session.queue_free()
	print("PASS: native PocketBase password login, invalid password, cancellation and authenticated game entry")
	quit()
