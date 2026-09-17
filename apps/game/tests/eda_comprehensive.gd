extends SceneTree

const Collision = preload("res://scripts/shared/campus_collision.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var reference: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	var base_y: float = reference.get_node("Feature_77921").position.y
	reference.free()
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
			assert(model.get_node("Feature_77921").get_child_count()<=8)
			Collision.build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for sample in [[Vector2(-270,290),base_y+20.18],[Vector2(-293.70,281.90),base_y+16.225]]:
			var pos: Vector2 = sample[0]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x,base_y+30,pos.y),Vector3(pos.x,base_y,pos.y)))
			assert(not hit.is_empty(),"Missing comprehensive roof or projection")
			assert(absf(hit.position.y-float(sample[1]))<0.02,"Wrong comprehensive height: "+str(hit))
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-270,base_y+1.7,305),Vector3(-270,base_y+1.7,290)))
		assert(not wall.is_empty(),"Exterior must remain closed")
		# Sample the saved plaza in the complete collision world, so a misplaced
		# building cannot be hidden by testing the isolated road mesh alone.
		var plaza_samples := 0
		var overlay: Dictionary = manifest.ground_overlays[0]
		assert(overlay.id == "eda-comprehensive-south-plaza")
		var outer := PackedVector2Array()
		var hole := PackedVector2Array()
		for p in overlay.outer: outer.append(Vector2(p[0],p[1]))
		for p in overlay.holes[0]: hole.append(Vector2(p[0],p[1]))
		for x in range(-330,-285,5):
			for z in range(308,346,5):
				var p := Vector2(x,z)
				if not Geometry2D.is_point_in_polygon(p,outer) or Geometry2D.is_point_in_polygon(p,hole): continue
				var y: float = terrain.elevation(p.x,p.y)+0.16
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+40,p.y),Vector3(p.x,y-1,p.y)))
				if hit.is_empty() or absf(hit.position.y-y)>0.03:
					push_error("Comprehensive plaza obstructed/missing: server=%s at=%s hit=%s" % [server,p,hit])
					quit(1)
					return
				plaza_samples += 1
		assert(plaza_samples==66,"Plaza sample coverage changed; review the source footprint")
		print("COMPREHENSIVE PLAZA PASS: server=",server," samples=",plaza_samples)
		world.free()
		viewport.free()
	print("PASS: client/server WGS84 comprehensive roof, lower glass projection, closed exterior and south plaza")
	quit()
