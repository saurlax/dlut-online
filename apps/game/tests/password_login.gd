extends SceneTree
const Account = preload("res://scripts/client/account_session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var session := Account.new()
	root.add_child(session)
	var arguments := OS.get_cmdline_user_args()
	if "restore" in arguments:
		await session.restore()
		assert(not Account.token.is_empty() and Account.username == "Client player" and Account.account_username == "client_test")
	var email := "client@example.com"
	await session.begin(email, "wrong-password")
	assert(Account.token.is_empty() and not session.waiting)
	session.begin(email, "correct-horse-battery-staple")
	session.cancel()
	await create_timer(0.3).timeout
	assert(Account.token.is_empty() and not session.waiting)
	await session.begin(email, "correct-horse-battery-staple")
	assert(not Account.token.is_empty() and Account.player_id.length() == 15 and Account.username == "Client player" and Account.account_username == "client_test")
	assert(not session.waiting and session.pending == null)
	var store = load("res://scripts/client/credential_store.gd")
	var saved: Dictionary = await store.request("read", session.api_url())
	if "save" in arguments:
		assert(saved.ok and saved.value == Account.token)
		print("PASS: saved account for next process")
		quit()
		return
	if not saved.get("unsupported", false):
		assert(saved.ok and saved.value == Account.token)
		Account.clear()
		Account.restore_attempted = false
		await session.restore()
		assert(not Account.token.is_empty() and Account.username == "Client player" and Account.account_username == "client_test")
		var kept_token := Account.token
		await fixture(session.api_url() + "/test/refresh-unavailable")
		Account.clear()
		Account.restore_attempted = false
		await session.restore()
		assert(Account.token.is_empty() and not session.waiting)
		var preserved: Dictionary = await store.request("read", session.api_url())
		assert(preserved.ok and preserved.value == kept_token)
		await fixture(session.api_url() + "/test/refresh-available")
		await store.request("write", session.api_url(), "expired.invalid.token")
		Account.clear()
		Account.restore_attempted = false
		await session.restore()
		assert(Account.token.is_empty())
		assert((await store.request("read", session.api_url())).missing)
		await session.begin(email, "correct-horse-battery-staple")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	assert(current_scene.login_only and current_scene.player == null)
	var network := root.get_node("GameNetwork")
	assert(not current_scene.loading_campus and not network.started)
	assert(current_scene.enter_button.text == "进入游戏" and not current_scene.enter_button.disabled)
	Account.clear()
	await current_scene.account_login.begin(email, "correct-horse-battery-staple")
	assert(not current_scene.loading_campus and not network.started, "Password login must wait for explicit game entry")
	current_scene._begin_login()
	assert(current_scene.loading_campus and current_scene.enter_button.disabled)
	current_scene._account_authenticated() # Duplicate success must not start another load.
	while current_scene == null or current_scene.scene_file_path == "res://scenes/main.tscn":
		await process_frame
	assert(current_scene.campus_id == "lingshui")
	var deadline := Time.get_ticks_msec() + 10000
	while not network.welcomed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(network.welcomed and not current_scene.hud.overlay.visible)
	await process_frame
	assert(current_scene.hud.player_status.visible)
	assert(current_scene.hud.username_label.text == "client_test")
	var before_sequence: int = network.sequence
	for frame in 180:
		current_scene.player.rotation.y += 0.03
		await physics_frame
	assert(network.welcomed and network.sequence - before_sequence <= 62, "Turning must not hit the server message limit")
	var connection: ENetPacketPeer = network.socket
	current_scene.hud.teleport("panjin")
	while not network.transfer_phase.is_empty():
		await process_frame
	assert(current_scene.campus_id == "panjin" and network.socket == connection)
	assert(not current_scene.hud.overlay.visible)
	var preserved_token := Account.token
	var old_campus: WeakRef = weakref(current_scene)
	network.close_code = 4005
	network._disconnected()
	await process_frame
	await process_frame
	await process_frame
	assert(old_campus.get_ref() == null and current_scene.login_only)
	assert(Account.token == preserved_token and not network.active and not network.started and network.socket == null)
	assert(current_scene.enter_button.text == "进入游戏" and not current_scene.enter_button.disabled)
	assert(current_scene.identity_label.text.contains("过于频繁") and not current_scene.identity_label.text.contains("版本"))
	await create_timer(1.2).timeout
	assert(not network.started, "Disconnection must not automatically reconnect")
	current_scene._begin_login()
	while not network.welcomed: await process_frame
	assert(current_scene.campus_id == "lingshui" and not current_scene.hud.overlay.visible)
	await Account.forget_saved()
	network.require_login()
	assert(Account.token.is_empty() and Account.account_username.is_empty() and current_scene.hud.overlay.visible)
	assert(not current_scene.hud.player_status.visible)
	assert(current_scene.hud.password_input.editable)
	var old: WeakRef = weakref(current_scene)
	await process_frame
	await process_frame
	await process_frame
	assert(old.get_ref() == null and current_scene.login_only)
	assert(current_scene.player == null and current_scene.password_input.editable)
	Account.clear()
	session.queue_free()
	print("PASS: native PocketBase password login, invalid password, cancellation and authenticated game entry")
	quit()

func fixture(url: String) -> void:
	var http := HTTPRequest.new()
	root.add_child(http)
	assert(http.request(url) == OK)
	var result: Array = await http.request_completed
	http.queue_free()
	assert(result[1] == 204)
