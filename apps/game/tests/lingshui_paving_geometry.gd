extends SceneTree

func _initialize() -> void: check.call_deferred()

func area(ring: PackedVector2Array) -> float:
	var total := 0.0
	for i in ring.size(): total += (ring[i]-ring[0]).cross(ring[(i+1)%ring.size()]-ring[0])*0.5
	return absf(total)

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("lingshui")
	var samples: Array[Vector3] = []
	var count := 0
	var triangles := 0
	var fountain_samples := 0
	for f: Dictionary in data.features:
		if f.kind not in ["plaza","gate"]: continue
		var group: Node3D = model.get_node("Feature_"+f.id+"_"+str(int(f.part)))
		if terrain.data.feature_base_y.has(str(group.name)): continue
		var expected := 0.0
		for polygon: Array in f.render_polygons:
			var ring := PackedVector2Array()
			for p: Array in polygon: ring.append(Vector2(p[0],p[1]))
			expected += area(ring)
		var actual := 0.0
		for mesh: MeshInstance3D in group.get_children():
			assert(mesh.get_meta("walk_collision",false),"Paving requires collision")
			var faces := mesh.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var a := mesh.global_transform*faces[i]
				var b := mesh.global_transform*faces[i+1]
				var c := mesh.global_transform*faces[i+2]
				actual += area(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]))
				# Interior and all edges catch triangles cutting across a terrain fold.
				for p: Vector3 in [a,b,c,(a+b+c)/3,(a+b)/2,(b+c)/2,(c+a)/2]:
					assert(absf(p.y-terrain.elevation(p.x,p.z)-0.14)<0.002,"Paving buried or floating: "+f.id+" "+str(p))
				if f.id in ["78550","17922962"]:
					samples.append((a+b+c)/3)
					if f.id=="17922962": fountain_samples += 1
				triangles += 1
		assert(absf(actual-expected)<0.2,"Paving footprint changed: "+f.id)
		count += 1
	assert(count==22 and fountain_samples>0)
	# Check the exported collision, rather than constructing a test-only collider.
	model.queue_free()
	var world: Node3D = load("res://scenes/server/lingshui.scn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	for p: Vector3 in samples:
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.025,p-Vector3.UP*0.025)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and absf(hit.position.y-p.y)<0.002,"Paving collision missing")
	print("PAVING GEOMETRY PASS: ",count," terrain-fitted parts, ",triangles," triangles, ",samples.size()," parking/square collision samples; fountain north=",fountain_samples)
	quit()
