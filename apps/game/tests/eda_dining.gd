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
			assert(model.get_node("Feature_77943").get_child_count()<=8)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in [[Vector2(400,25),12.18],[Vector2(386.473,51.013),14.5]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,30,pos.y),Vector3(pos.x,0,pos.y)))
			assert(not hit.is_empty(),"Missing dining roof or projection")
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Wrong dining height: "+str(hit))
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(400,1.7,80),Vector3(400,1.7,30)))
		assert(not wall.is_empty(),"Exterior must remain closed")
		world.free()
		viewport.free()
	print("PASS: client/server dining roof, raised divider and closed exterior")
	quit()
