extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func settle(frames := 12) -> void:
	for i in frames:
		await physics_frame

func _run() -> void:
	var account = load("res://scripts/client/account_session.gd")
	account.token = OS.get_environment("DO_TEST_ACCOUNT_TOKEN")
	account.player_id = OS.get_environment("DO_TEST_ACCOUNT_ID")
	account.username = "Test player"
	assert(not account.token.is_empty())
	create_timer(90).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/main.tscn")
	await settle(2)
	assert(current_scene.login_only)
	current_scene._account_authenticated()
	while current_scene == null or current_scene.scene_file_path == "res://scenes/main.tscn":
		await process_frame
	await settle(45)
	assert(current_scene.campus_id == "lingshui")
	assert(current_scene.player.is_on_floor())
	assert(current_scene.has_node("CampusModel"))
	var network := root.get_node("GameNetwork")
	var world := current_scene
	world.hud._account_authenticated()
	await create_timer(1.7).timeout
	assert(world.player.playing)
	assert(network.welcomed)
	assert(not world.hud.overlay.visible)
	world.hud.pause_exploration()
	assert(not world.hud.overlay.visible and not world.player.playing)
	world.hud.enter_campus()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	assert(world.hud.map_overlay.visible and not world.player.playing)
	var before: Vector3 = world.player.position
	Input.action_press("move_forward")
	await settle(20)
	Input.action_release("move_forward")
	assert(world.player.position.distance_to(before)<0.05)
	world.hud.close_map()
	await create_timer(1.7).timeout
	assert(world.player.playing and not world.hud.map_overlay.visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	world.hud.minimap._gui_input(click)
	assert(world.hud.map_overlay.visible)
	assert(not world.hud.minimap._has_point(Vector2.ZERO))
	assert(world.hud.minimap._has_point(Vector2(74,74)))
	var connection_id: String = network.admission_id
	var socket: ENetPacketPeer = network.socket
	for destination in ["eda","panjin","lingshui","eda","lingshui"]:
		var old: WeakRef = weakref(current_scene)
		current_scene.hud.teleport(destination)
		for attempt in 600:
			await process_frame
			if current_scene != null and current_scene.campus_id == destination and network.transfer_phase.is_empty(): break
		await settle(60)
		assert(network.socket == socket and network.admission_id == connection_id,"Map change must preserve authenticated connection")
		assert(old.get_ref()==null,"Old campus must unload")
		assert(current_scene.campus_id==destination)
		assert(not current_scene.hud.overlay.visible,"Travel must never show the cover again")
		assert(current_scene.player.playing,"Travel must resume gameplay")
		assert(current_scene.player.is_on_floor(),"Arrival must be grounded")
		assert(current_scene.find_children("*","Camera3D",true,false).size()==1)
		assert(InputMap.action_get_events("move_forward").size()==1,"Travel must not duplicate bindings")
		assert(current_scene.manifest.features.size()==({"eda":27,"lingshui":313,"panjin":0}[destination]))
	print("PASS: default lingshui; M/click map; paused movement; resume; eda/panjin/lingshui travel; old scene freed; grounded arrival; no duplicate controls")
	quit()
