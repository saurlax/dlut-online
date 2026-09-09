extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var campus: Node3D = load("res://scenes/campuses/eda.tscn").instantiate()
	root.add_child(campus)
	for i in 45:
		await physics_frame
	assert(campus.manifest.features.size()==27)
	for feature in campus.manifest.features:
		assert(campus.model.has_node("Feature_"+feature.id))
	var player: CharacterBody3D = campus.player
	assert(player.is_on_floor(),"Spawn must settle on campus ground")
	assert(absf(player.camera.position.y-1.7)<0.01,"Eye height must be first person")
	assert(campus.hud.overlay.visible and not player.playing,"Initial view must await player gesture")
	assert(not campus.has_method("focus_feature"),"Map navigation must be removed")
	assert(not campus.has_method("_web_command"),"Business JS bridge must be removed")
	assert(campus.hud.root_control.find_children("*","LineEdit",true,false).is_empty(),"No search interface")
	var before := player.position
	Input.action_press("move_forward")
	for i in 10:
		await physics_frame
	Input.action_release("move_forward")
	assert(player.position.distance_to(before)<0.05,"Pause must prevent movement")
	Input.action_press("jump")
	for i in 3:
		await physics_frame
	Input.action_release("jump")
	assert(player.is_on_floor(),"Paused jump must be ignored")
	player.drag_look = true
	player.playing = true
	var ground_y: float = player.position.y
	Input.action_press("jump")
	for i in 8:
		await physics_frame
	assert(player.position.y > ground_y + 0.4,"Space must lift the capsule")
	Input.action_release("jump")
	await physics_frame
	var rising_speed: float = player.velocity.y
	Input.action_press("jump")
	for i in 3:
		await physics_frame
	assert(player.velocity.y < rising_speed,"Airborne input must not reset jump velocity")
	for i in 65:
		await physics_frame
	assert(player.is_on_floor(),"Holding Space must land without automatically jumping again")
	assert(absf(player.position.y-ground_y)<0.05,"Jump must return to the ground")
	Input.action_release("jump")
	await physics_frame
	Input.action_press("jump")
	for i in 4:
		await physics_frame
	assert(player.velocity.y > 0,"A fresh press after landing must jump again")
	Input.action_release("jump")
	for i in 60:
		await physics_frame
	# Exercise the same input-driven controller in the embedded-browser fallback.
	player.drag_look = true
	player.playing = true
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	assert(before.z-player.position.z>2.0,"W input must move forward")
	var walk_distance: float = before.z-player.position.z
	var run_start := player.position
	Input.action_press("move_forward")
	Input.action_press("run")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("run")
	assert(run_start.z-player.position.z>walk_distance*1.5,"Shift must increase speed")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,30)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	player._unhandled_input(motion)
	assert(absf(player.rotation.y)>0.1 and absf(player.camera.rotation.x)>0.01,"Mouse movement must rotate the first-person view")
	player.rotation.y = 0
	campus.hud.pause_exploration()
	assert(player.movement_direction(Vector2(0,-1)).is_equal_approx(Vector3.FORWARD))
	player.rotation.y = PI/2
	assert(player.movement_direction(Vector2(0,-1)).is_equal_approx(Vector3.LEFT))
	player.rotation.y = 0
	# Push the capsule toward the south-facing information-building facade.
	player.set_physics_process(false)
	player.position = Vector3(35,0.05,350)
	var travelled := 0.0
	for i in 240:
		await physics_frame
		var previous := player.position
		player.velocity = Vector3(0,-2,-13)
		player.move_and_slide()
		travelled += previous.distance_to(player.position)
	assert(travelled>5,"Capsule must move across the approach")
	print("Wall test position: ",player.position)
	assert(player.position.z>313,"Information building must block the capsule")
	assert(player.position.z<316,"Capsule must reach the building")
	assert(player.position.y > -0.1,"Ground must block falling")
	campus.hud.pause_exploration()
	assert(player.velocity==Vector3.ZERO and not player.playing)
	print("PASS: 27 models, grounded spawn, 1.7m eye height, paused input, relative movement, building collision, native UI and removed map/JS bridge")
	quit()
