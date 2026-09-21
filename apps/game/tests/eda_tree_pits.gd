extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/vegetation.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var axis := Vector2.ZERO
	var path_origin := Vector2.ZERO
	for zone: Dictionary in data.linear_zones:
		if zone.id == "academic-c-west-ginkgo-rows":
			path_origin = Vector2(zone.expected_points[0][0],zone.expected_points[0][1])
			axis = (Vector2(zone.expected_points[1][0],zone.expected_points[1][1])-Vector2(zone.expected_points[0][0],zone.expected_points[0][1])).normalized()
	assert(axis.length()>0.9)
	var side := Vector2(-axis.y,axis.x)
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
			var paving: MeshInstance3D = model.get_node("CourtyardPaving")
			var faces := paving.mesh.get_faces()
			var area := 0.0
			for i in range(0,faces.size(),3):
				var front := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
				assert(front.y>=-0.000001,"Courtyard paving faces downward")
				area += front.y*0.5
			assert(absf(area-319.68)<0.05,"Paving area must exclude all twenty tree pits")
			preload("res://scripts/shared/campus_collision.gd").build(world,model,manifest,"eda")
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		var count := 0
		for plant: Dictionary in data.instances:
			if plant.zone != "academic-c-west-ginkgo-rows": continue
			count += 1
			var center := Vector2(plant.position[0],plant.position[2])
			for sample: Vector3 in [Vector3(0.84,0.1,0),Vector3(-0.84,0.1,0),Vector3(0,0.1,0.84),Vector3(0,0.1,-0.84),Vector3(0.65,0.035,0.65),Vector3(-0.65,0.035,0.65),Vector3(0.65,0.035,-0.65),Vector3(-0.65,0.035,-0.65)]:
				var p := center+axis*sample.x+side*sample.z
				var y: float = terrain.elevation(p.x,p.y)+sample.y
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.3,p.y),Vector3(p.x,y-0.3,p.y)))
				assert(not hit.is_empty() and absf(hit.position.y-y)<0.012,"Tree pit surface missing or not fitted to terrain: " + str(p) + " expected=" + str(y) + " hit=" + str(hit))
			var hole_y: float = terrain.elevation(center.x,center.y)
			var hole := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,hole_y+0.15,center.y),Vector3(center.x,hole_y+0.015,center.y)))
			assert(hole.is_empty(),"Tree pit cover seals trunk opening")
			for direction: Vector2 in [axis,-axis,side,-side]:
				var p := center+direction*0.4
				var y: float = terrain.elevation(p.x,p.y)
				var seam := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.15,p.y),Vector3(p.x,y+0.015,p.y)))
				assert(seam.is_empty(),"Four-piece cover joint is sealed")
			for quadrant in 4:
				for angle in [PI/8,PI/4,PI*3/8]:
					var direction := Vector2(cos(angle+quadrant*PI/2),sin(angle+quadrant*PI/2))
					var radial := axis*direction.x+side*direction.y
					var inner := center+radial*0.16
					var outer := center+radial*0.27
					var start := Vector3(inner.x,terrain.elevation(inner.x,inner.y)+0.02,inner.y)
					var finish := Vector3(outer.x,terrain.elevation(outer.x,outer.y)+0.02,outer.y)
					var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish))
					assert(not wall.is_empty(),"Round opening has no inward-facing wall")
					assert(absf(Vector2(wall.position.x,wall.position.z).distance_to(center)-0.22)<0.004,"Round opening radius mismatch")
					assert(wall.normal.dot(Vector3(radial.x,0,radial.y))<-0.98,"Round opening wall faces away from hole")
					for radius: float in [0.19,0.25]:
						var p := center+(axis*direction.x+side*direction.y)*radius
						var y: float = terrain.elevation(p.x,p.y)
						var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.15,p.y),Vector3(p.x,y+0.015,p.y)))
						if radius<0.22:
							assert(hit.is_empty(),"Round trunk hole is obstructed")
						else:
							assert(not hit.is_empty() and absf(hit.position.y-y-0.035)<0.005,"Round hole still has a square corner gap")
			for sx in [-1.0,1.0]:
				for sz in [-1.0,1.0]:
					for slot in [0.3725,0.4625,0.5525]:
						var p: Vector2 = center+axis*float(slot)*sx+side*0.49*sz
						var y: float = terrain.elevation(p.x,p.y)
						var drain := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+0.15,p.y),Vector3(p.x,y+0.015,p.y)))
						assert(drain.is_empty(),"Tree pit drain has a hidden cover collider")
			# Test the clear corridor midway between the two rows, above ground.
			if (center-path_origin).dot(side)<-8.0:
				var p := center+side*2.1
				var paving_y: float = terrain.elevation(p.x,p.y)+0.018
				var paving_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,paving_y+0.1,p.y),Vector3(p.x,paving_y-0.05,p.y)))
				assert(not paving_hit.is_empty() and absf(paving_hit.position.y-paving_y)<0.004,"Missing terrain-fitted row paving")
				var shape := CapsuleShape3D.new()
				shape.radius=0.35
				shape.height=1.8
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape=shape
				query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,terrain.elevation(p.x,p.y)+1.1,p.y))
				query.motion=Vector3(axis.x,0,axis.y)*2.0
				assert(space.cast_motion(query)[0]>0.999,"Tree pits obstruct the row corridor")
		assert(count==20)
		print("TREE PIT PHYSICS PASS server=",server," 20 pits, 160 surface samples, 240 drainage slots, 480 round-hole rays, 240 inward wall rays, 80 joint rays and corridor clearance")
		viewport.free()
	quit()
