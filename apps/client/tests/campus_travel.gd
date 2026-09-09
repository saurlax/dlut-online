extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func settle(frames := 12) -> void:
	for i in frames:
		await physics_frame

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	change_scene_to_file("res://scenes/main.tscn")
	await settle(45)
	assert(current_scene.campus_id == "lingshui")
	assert(current_scene.player.is_on_floor())
	assert(current_scene.has_node("CampusModel"))
	var world := current_scene
	world.hud.enter_campus()
	await create_timer(1.7).timeout
	assert(world.player.playing)
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
	for destination in ["eda","panjin","lingshui","eda","lingshui"]:
		var old: WeakRef = weakref(current_scene)
		current_scene.hud.teleport(destination)
		await settle(45)
		assert(old.get_ref()==null,"Old campus must unload")
		assert(current_scene.campus_id==destination)
		assert(not current_scene.hud.overlay.visible,"Travel must never show the cover again")
		assert(current_scene.player.playing,"Travel must resume gameplay")
		assert(current_scene.player.is_on_floor(),"Arrival must be grounded")
		assert(current_scene.find_children("*","Camera3D",true,false).size()==1)
		assert(InputMap.action_get_events("move_forward").size()==1,"Travel must not duplicate bindings")
		assert(current_scene.manifest.features.size()==(27 if destination=="eda" else 0))
	print("PASS: default lingshui; M/click map; paused movement; resume; eda/panjin/lingshui travel; old scene freed; grounded arrival; no duplicate controls")
	quit()
