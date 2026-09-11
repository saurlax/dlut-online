extends SceneTree

const Account = preload("res://scripts/client/account_session.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	Account.restore_attempted = true
	Account.clear()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	assert(current_scene.login_only and current_scene.overlay.visible)
	assert(current_scene.player == null and current_scene.minimap == null)
	assert(current_scene.find_children("*", "Node3D", true, false).is_empty())
	for id in ["lingshui", "eda", "panjin"]:
		assert(not ResourceLoader.has_cached("res://scenes/campuses/" + id + ".tscn"), "Login must not load campus scenes")
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	current_scene.hud.enter_campus()
	assert(current_scene.hud.overlay.visible and not current_scene.player.playing, "Anonymous users cannot dismiss the cover")
	var session: Node = current_scene.hud.account_login
	assert(current_scene.hud.password_input.secret)
	current_scene.hud.email_input.text = ""
	current_scene.hud.password_input.text = ""
	current_scene.hud._begin_login()
	assert(not session.waiting and Account.token.is_empty())
	current_scene.hud.password_input.text = "discard-me"
	current_scene.hud._begin_login()
	assert(current_scene.hud.password_input.text.is_empty())
	session.cancel()
	assert(not session.waiting and session.pending == null)
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
	var old: WeakRef = weakref(current_scene)
	await process_frame
	await process_frame
	await process_frame
	assert(old.get_ref() == null, "Logout must unload the campus")
	assert(current_scene.login_only and current_scene.overlay.visible)
	assert(current_scene.password_input.editable)
	print("PASS: anonymous cover, password masking, empty-input rejection, cancellation and expired session")
	quit()
