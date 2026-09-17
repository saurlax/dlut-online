extends SceneTree
## Verify own roofs, then courtyard clearance in complete client/server worlds.
## --isolated limits verification to courtyard-owner meshes for diagnosis.
func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	# The modern-laboratory ID remains addressable, while the compound is built once.
	var member: Node3D = model.get_node("Feature_77419_0")
	var compound: Node3D = model.get_node("Feature_77420_0")
	assert(member.get_child_count()==0,"Legacy modern-laboratory volume must not duplicate the compound")
	var shared_geometry: Dictionary = member.get_meta("shared_geometry")
	assert(shared_geometry.id=="77420" and int(shared_geometry.part)==0)
	assert(compound.get_meta("shared_official_ids")==["77420","77419"])
	var probes: Array[Vector3] = []
	var world_probes: Array[Dictionary] = []
	var isolated := "--isolated" in OS.get_cmdline_user_args()
	for feature: Dictionary in manifest.features:
		if feature.get("holes",[]).is_empty(): continue
		var group: Node3D = model.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
		for hole: Array in feature.holes:
			var ring := PackedVector2Array()
			var center := Vector2.ZERO
			for p: Array in hole:
				ring.append(Vector2(p[0],p[1]))
				center += ring[-1]/hole.size()
			assert(Geometry2D.is_point_in_polygon(center,ring),"Choose an interior probe for this courtyard")
			probes.append(Vector3(center.x,group.position.y,center.y))
			var bounds := Rect2(ring[0],Vector2.ZERO)
			for point in ring: bounds = bounds.expand(point)
			# Sample the whole inner area; a center-only ray can miss a partial fill.
			for x in range(ceili(bounds.position.x),floori(bounds.end.x)+1,2):
				for z in range(ceili(bounds.position.y),floori(bounds.end.y)+1,2):
					var point := Vector2(x,z)
					if not Geometry2D.is_point_in_polygon(point,ring): continue
					var edge_distance := INF
					for i in ring.size(): edge_distance = minf(edge_distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,ring[i],ring[(i+1)%ring.size()])))
					if edge_distance<0.5: continue
					world_probes.append({"id":feature.id,"position":Vector3(x,group.position.y,z),"height":float(feature.height)})
			var cap_count := 0
			for child: MeshInstance3D in group.get_children():
				if child.name not in ["Building","Roof"]: continue
				var faces := child.mesh.get_faces()
				for i in range(0,faces.size(),3):
					if absf(faces[i].y-faces[i+1].y)>0.001 or absf(faces[i].y-faces[i+2].y)>0.001: continue
					cap_count += 1
					var triangle := PackedVector2Array()
					for k in 3: triangle.append(Vector2(faces[i+k].x,faces[i+k].z))
					for overlap in Geometry2D.intersect_polygons(triangle,ring):
						var area := 0.0
						for j in overlap.size(): area += (overlap[j]-overlap[0]).cross(overlap[(j+1)%overlap.size()]-overlap[0])*0.5
						assert(absf(area)<0.001,"Saved roof fills OSM courtyard "+feature.id)
				if isolated: preload("res://scripts/shared/campus_collision.gd")._collider(child)
			assert(cap_count>0,"Building cap geometry missing")
	assert(probes.size()>=2 and world_probes.size()>=probes.size(),"Courtyard source coverage missing")
	if not isolated: preload("res://scripts/shared/campus_collision.gd").build(model,model,manifest,"lingshui")
	await physics_frame
	await physics_frame
	if not isolated:
		var client_failures := check_world(model,world_probes,"client")
		if client_failures==0:
			model.add_child(load("res://assets/campuses/lingshui/models/terrain.tscn").instantiate())
			await physics_frame
			await physics_frame
			await check_walk(model,"client")
		model.queue_free()
		await process_frame
		var server: Node3D = load("res://scenes/server/lingshui.scn").instantiate()
		root.add_child(server)
		await physics_frame
		await physics_frame
		var server_failures := check_world(server,world_probes,"server")
		if server_failures==0: await check_walk(server,"server")
		if client_failures+server_failures>0:
			print("COURTYARD WORLD FAIL: client=",client_failures," server=",server_failures," obstructed samples; isolated cap checks do not establish world clearance")
			quit(1)
			return
		print("COURTYARD WORLD PASS: ",world_probes.size()," interior samples in both client and exported server; samples are not full walkability proof")
		quit()
		return
	for p in probes:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*100,p-Vector3.UP))
		assert(hit.is_empty(),"Building-only collision blocks courtyard")
	assert(probes.size()>=2)
	print("COURTYARD ISOLATED PASS: ",probes.size()," archived holes remain open in saved roofs and collision")
	quit()

func check_world(world: Node3D, samples: Array[Dictionary], label: String) -> int:
	var failures := 0
	var reported := {}
	for sample in samples:
		var point: Vector3 = sample.position
		# Stop above grade: ordinary ground is expected, a building overhead is not.
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*(sample.height+10.0),point+Vector3.UP*2.0))
		if hit.is_empty(): continue
		failures += 1
		if reported.has(sample.id): continue
		reported[sample.id] = true
		print("COURTYARD OBSTRUCTION ",label," owner=",sample.id," probe=",point," hit=",hit.position," collider=",hit.collider.get_path())
	return failures

func check_walk(world: Node3D, label: String) -> void:
	# Exercise the restored inner area, without claiming a new route through its walls.
	var movement = preload("res://scripts/shared/movement.gd")
	var body := CharacterBody3D.new()
	movement.setup(body)
	world.add_child(body)
	for direction in [-1.0,1.0]:
		var x := 638.0 if direction<0 else 610.0
		var query := PhysicsRayQueryParameters3D.create(Vector3(x,25,385),Vector3(x,-25,385))
		query.exclude = [body.get_rid()]
		var ground := world.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not ground.is_empty() and ground.position.y<2,"Restored inner area needs ground, not a roof")
		var spawn: Vector3 = ground.position+Vector3.UP*0.5
		body.position = spawn
		body.velocity = Vector3.ZERO
		for frame in 45:
			await physics_frame
			movement.step(body,Vector2.ZERO,false,false,1.0/60.0,spawn)
		assert(body.is_on_floor(),"Courtyard spawn did not settle on ground")
		for frame in 180:
			await physics_frame
			movement.step(body,Vector2(direction,0),false,false,1.0/60.0,spawn)
			assert(body.is_on_floor(),"Lost floor inside restored courtyard")
		assert((body.position.x-x)*direction>17.5,"Legacy volume still blocks courtyard walking")
	body.free()
	print("COURTYARD WALK PASS: ",label," both directions, 18m interior paths; entrances not verified")
