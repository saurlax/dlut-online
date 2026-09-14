extends SceneTree

const Account = preload("res://scripts/client/account_session.gd")
const LocalSession = preload("res://scripts/client/local_session.gd")
const Catalog = preload("res://scripts/shared/campus_catalog.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	Account.clear()
	Account.restore_attempted = false
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var network := root.get_node("GameNetwork")
	assert(not Account.restore_attempted and not network.started and network.host == null)
	assert(current_scene.singleplayer_button.visible and current_scene.multiplayer_button.visible)
	assert(not current_scene.overlay.get_node("Composition/Form").visible)
	# Opening and cancelling multiplayer never makes the offline entry depend on login.
	Account.restore_attempted = true
	current_scene._begin_multiplayer()
	assert(current_scene.overlay.get_node("Composition/Form").visible)
	current_scene.password_input.text = "not-a-real-password"
	current_scene._cancel_login()
	assert(current_scene.password_input.text.is_empty() and not current_scene.multiplayer_requested)
	Account.restore_attempted = false
	current_scene._begin_singleplayer()
	while current_scene == null or current_scene.scene_file_path == "res://scenes/main.tscn": await process_frame
	assert(LocalSession.enabled and Catalog.started and current_scene.player.network_ready)
	assert(not Account.restore_attempted and Account.token.is_empty())
	assert(not network.started and network.host == null and network.player == null)
	var hud: CanvasLayer = current_scene.hud
	assert(hud.chat == null and hud.player_status == null and not hud.overlay.visible)
	for frame in 90: await physics_frame
	assert(current_scene.player.is_on_floor(), "Local player must stand on campus collision")
	var start: Vector3 = current_scene.player.position
	hud.enter_campus()
	current_scene.player.drag_look = true
	Input.action_press("move_forward")
	for frame in 30: await physics_frame
	Input.action_release("move_forward")
	assert(current_scene.player.position.distance_to(start) > 0.5, "Local movement must not require a server welcome")
	hud.toggle_map()
	assert(hud.map_overlay.visible and not current_scene.player.playing)
	var panel: PanelContainer = hud.map_overlay.get_node("LocalEnvironment")
	assert(panel.position == Vector2(28, 28))
	var fields := panel.get_child(0)
	fields.get_node("Time").value = 360
	var weather: OptionButton = fields.get_node("Weather")
	weather.select(weather.get_item_index(73))
	weather.item_selected.emit(weather.selected)
	await create_timer(0.4).timeout
	assert(LocalSession.minutes == 360 and LocalSession.weather_code == 73)
	var environment := current_scene.get_node("CampusEnvironment")
	assert(environment.effects.y > 0.0, "Local snow selection must reach the renderer")
	hud.teleport("eda")
	hud.cancel_transfer()
	while ResourceLoader.load_threaded_get_status(Catalog.CAMPUSES.eda.scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await process_frame
	await process_frame
	assert(current_scene.campus_id == "lingshui" and not hud.switching)
	var old: WeakRef = weakref(current_scene)
	hud.teleport("panjin")
	while current_scene == null or current_scene.campus_id != "panjin": await process_frame
	await process_frame
	assert(old.get_ref() == null and LocalSession.minutes == 360 and LocalSession.weather_code == 73)
	assert(not network.started and network.host == null and network.player == null)
	current_scene.hud._leave_mode()
	for frame in 4: await process_frame
	assert(current_scene.login_only and not LocalSession.enabled and not Catalog.started)
	assert(not Account.restore_attempted)
	# A valid in-memory login starts loading from the multiplayer click immediately.
	Account.token = "test-only"
	current_scene._begin_multiplayer()
	assert(current_scene.loading_campus and not LocalSession.enabled)
	assert(not current_scene.overlay.get_node("Composition/Form").visible)
	network._return_to_menu("test cancelled")
	Account.clear()
	Account.restore_attempted = true
	current_scene._begin_multiplayer()
	Account.token = "authenticated-test-only"
	current_scene.account_login.authenticated.emit()
	assert(current_scene.loading_campus, "Login success must continue the requested multiplayer entry")
	network._return_to_menu("test cancelled")
	Account.clear()
	while ResourceLoader.load_threaded_get_status(Catalog.CAMPUSES.lingshui.scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await process_frame
	await process_frame
	print("PASS: mode menu, login cancellation, offline physics, local weather/time, campus transfer, return and authenticated entry")
	quit()
