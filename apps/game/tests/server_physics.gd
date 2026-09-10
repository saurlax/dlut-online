extends SceneTree
const Movement = preload("res://scripts/shared/movement.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var worlds := {}
	for id in ["lingshui","eda","panjin"]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var world: Node3D = load("res://scenes/server/" + id + ".scn").instantiate()
		viewport.add_child(world)
		worlds[id] = world
		assert(world.find_children("*", "MeshInstance3D", true, false).is_empty())
		assert(world.find_children("*", "Camera3D", true, false).is_empty())
		var body := CharacterBody3D.new()
		Movement.setup(body)
		world.add_child(body)
		body.position = world.get_meta("spawn")
		for frame in 90:
			await physics_frame
			Movement.step(body,Vector2.ZERO,false,false,1.0/60.0,world.get_meta("spawn"))
		assert(body.is_on_floor(),id + " spawn must be grounded")
		if id == "eda":
			body.position = Vector3(35,0.05,350)
			for frame in 240:
				await physics_frame
				Movement.step(body,Vector2(0,-1),true,false,1.0/60.0,world.get_meta("spawn"))
			assert(body.position.z>313 and body.position.z<316,"Shared authoritative collision must block the information building")
		body.queue_free()
	assert(worlds.eda.get_world_3d().space != worlds.lingshui.get_world_3d().space)
	assert(worlds.eda.get_world_3d().space != worlds.panjin.get_world_3d().space)
	print("PASS: three collision-only worlds, grounded spawns, separate physics spaces, authoritative wall collision")
	quit()
