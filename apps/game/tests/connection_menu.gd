extends SceneTree

const Account = preload("res://scripts/client/account_session.gd")
const Catalog = preload("res://scripts/shared/campus_catalog.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	Account.restore_attempted = true
	Account.token = "menu-test-only"
	Account.username = "Test player"
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var network := root.get_node("GameNetwork")
	assert(current_scene.login_only and not current_scene.loading_campus)
	assert(current_scene.player == null and not network.started and network.host == null)
	assert(current_scene.multiplayer_button.text == "多人模式" and not current_scene.multiplayer_button.disabled)
	assert(not current_scene.email_input.is_visible_in_tree() and not current_scene.password_input.is_visible_in_tree())
	var labels := {4002:"版本", 4003:"连接中断", 4004:"人数已满", 4005:"过于频繁", 4006:"通信数据异常", 0:"失去连接"}
	for code in labels:
		network.close_code = code
		network.active = true
		network.started = true
		network.transfer_phase = "loading"
		Catalog.entry_requested = true
		var generation: int = network.connection_generation
		network._disconnected()
		assert(network.status_text.contains(labels[code]))
		if code != 4002: assert(not network.status_text.contains("版本"))
		assert(not network.started and not network.active and not network.connecting)
		assert(network.connection_generation > generation and network.transfer_phase.is_empty())
		assert(not Catalog.entry_requested and not Catalog.started)
		assert(Account.token == "menu-test-only" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		assert(current_scene.menu_status.text == network.status_text and not current_scene.enter_button.disabled)
	await create_timer(1.2).timeout
	assert(not network.started and network.host == null, "Menu must wait for an explicit click")
	# Finish the background worker before shutting down the test scene.
	while current_scene.overlay.background_requested or current_scene.overlay.preparing:
		await process_frame
	Account.clear()
	print("PASS: restored account waits in menu; disconnect reasons are distinct; state is cleared without automatic reconnect")
	quit()
