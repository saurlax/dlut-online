extends SceneTree
## Verify the reviewed traffic-count POI does not become a building or block its road.
func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var terrain = preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("lingshui")
	var failures := 0
	for label in ["client", "server"]:
		var world: Node3D
		if label == "client":
			world = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
			var reference: Node3D = world.get_node("Feature_81821_0")
			if reference.get_child_count() != 0 or reference.get_meta("reference_type", "") != "traffic-counter":
				push_error("Traffic-count source incorrectly generates physical building geometry")
				failures += 1
			root.add_child(world)
			preload("res://scripts/shared/campus_collision.gd").build(world,world,manifest,"lingshui")
			world.add_child(load("res://assets/campuses/lingshui/models/terrain.tscn").instantiate())
		else:
			world = load("res://scenes/server/lingshui.scn").instantiate()
			root.add_child(world)
		await physics_frame
		await physics_frame
		# Source road 544369558 v1, first segment. Probe across the former POI volume.
		for x in range(46,67,2):
			var z := road_z(float(x))
			var y: float = terrain.elevation(x,z)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,y+30,z),Vector3(x,y-1,z)))
			if hit.is_empty() or absf(hit.position.y-(y+0.12))>0.05:
				push_error("Traffic POI road blocked or unsupported: %s x=%s" % [label,x])
				failures += 1
		if failures == 0:
			var movement = preload("res://scripts/shared/movement.gd")
			var body := CharacterBody3D.new()
			movement.setup(body)
			world.add_child(body)
			for direction in [-1.0,1.0]:
				var start_x := 65.0 if direction<0 else 45.0
				var start := Vector3(start_x,terrain.elevation(start_x,road_z(start_x))+0.6,road_z(start_x))
				body.position = start
				body.velocity = Vector3.ZERO
				for frame in 45:
					await physics_frame
					movement.step(body,Vector2.ZERO,false,false,1.0/60.0,start)
				for frame in 180:
					await physics_frame
					movement.step(body,Vector2(direction,-direction*2.0817/49.9056).normalized(),false,false,1.0/60.0,start)
					assert(body.is_on_floor(),"Restored road lost ground contact")
				assert((body.position.x-start_x)*direction>17.5,"Restored road still obstructs capsule")
			body.free()
		world.queue_free()
		await process_frame
	print("NONBUILDING REFERENCE ","PASS" if failures==0 else "FAIL",": client/server road samples and bidirectional walks; failures=",failures)
	quit(0 if failures==0 else 1)

func road_z(x: float) -> float:
	return 344.4241+(66.0237-x)*2.0817/49.9056
