extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	for server in [false,true]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if server:
			world.add_child(load("res://scenes/server/eda.scn").instantiate())
		else:
			var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
			world.add_child(model)
			assert(model.get_node("Feature_77923").get_child_count()<=8)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		# Roof endpoints are higher than the trough; verify the exported collision
		# instead of only inspecting generator parameters.
		for sample in [[-378.0,16.89024],[-316.5,13.5],[-255.0,16.89024]]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample[0],30,-51),Vector3(sample[0],0,-51)))
			assert(not hit.is_empty())
			assert(absf(hit.position.y-float(sample[1]))<0.015,"Gym roof is flat or missing: "+str(hit))
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-230,5,-50),Vector3(-280,5,-50)))
		assert(not wall.is_empty(),"Gym entrance must remain closed")
		# The former tall east projection must be gone above its low base.
		var projection := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-250,10,-60),Vector3(-250,10,-35)))
		assert(projection.is_empty(),"Old full-height east projection remains")
		for sample in [[-78.0,24.5],[-67.0,25.5],[-56.0,24.5],[-45.0,24.5],[-34.0,25.5],[-23.0,24.5]]:
			var post := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-316.5,30,sample[0]),Vector3(-316.5,14,sample[0])))
			assert(not post.is_empty() and absf(post.position.y-sample[1])<0.03,"Missing gym roof post or wrong top")
		var post_side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-317.5,18,-67),Vector3(-315.5,18,-67)))
		assert(not post_side.is_empty(),"Roof post must have structural collision")
		world.free()
		viewport.free()
	print("PASS: client/server curved gym roof, low projection and closed exterior")
	quit()
