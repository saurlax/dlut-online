extends SceneTree
const Account = preload("res://scripts/client/account_session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	var session := Account.new()
	root.add_child(session)
	var arguments := OS.get_cmdline_user_args()
	if "restore" in arguments:
		await session.restore()
		assert(not Account.token.is_empty() and Account.username == "Client player")
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
		assert(not Account.token.is_empty() and Account.username == "Client player")
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
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud._account_authenticated()
	var network := root.get_node("GameNetwork")
	var deadline := Time.get_ticks_msec() + 10000
	while not network.welcomed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(network.welcomed and not current_scene.hud.overlay.visible)
	await Account.forget_saved()
	network.require_login()
	assert(Account.token.is_empty() and current_scene.hud.overlay.visible)
	assert(current_scene.hud.password_input.editable)
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
