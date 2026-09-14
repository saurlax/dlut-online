extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")
const SAMPLES := [[Vector2(100,-245),21.18],[Vector2(70,-190),9.78],[Vector2(170,-180),24.78],[Vector2(141.47234,-210.59116),29.2],[Vector2(184.55,-88.05),24.82],[Vector2(127.676,-134.121),9.87]]

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
			for id in ["77925","77928","77927"]:
				assert(model.get_node("Feature_"+id).get_child_count()<=7)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in SAMPLES:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,80,pos.y),Vector3(pos.x,-1,pos.y)))
			assert(not hit.is_empty(),"Missing roof at "+str(pos))
			assert(absf(hit.position.y-float(sample[1]))<0.03,"Wrong roof height at "+str(pos)+": "+str(hit.position))
		var south_eave := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(201.302,26,-117.011),Vector3(201.302,23,-117.011)))
		assert(not south_eave.is_empty() and absf(south_eave.position.y-24.78)<0.03,"Missing C south-end eave")
		# The rotunda's visible lower column must remain solid beyond the wall.
		var a := Vector2(182.378,-89.314)
		var b := Vector2(177.046,-93.047)
		var out := Vector2((b-a).y,-(b-a).x).normalized()
		var mid := (a+b)/2
		var from := mid+out*1.5
		var to := mid+out*0.1
		var column := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from.x,4,from.y),Vector3(to.x,4,to.y)))
		var expected := mid+out*0.83
		assert(not column.is_empty() and column.position.distance_to(Vector3(expected.x,4,expected.y))<0.03,"Missing C rotunda column")
		# B's former 21m shell must not remain above the low wing.
		var clearance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(25,15,-190),Vector3(110,15,-190)))
		assert(clearance.is_empty(),"Old B wing collision remains at 15m")
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(25,2,-190),Vector3(110,2,-190)))
		assert(not wall.is_empty(),"Low B wing exterior must remain closed")
		world.free()
		viewport.free()
	print("PASS: client/server academic A/B/C roof heights, A glass tower C rotunda column/eaves and low B clearance")
	quit()
