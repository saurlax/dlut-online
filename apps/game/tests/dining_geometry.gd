extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in manifest.features:
		if item.id=="77943": feature = item
	assert(feature.get("osm_id","")=="way/375541048" and not feature.has("reference_points"))
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_77943")
	var east_start := Vector2(feature.points[15][0],feature.points[15][1])
	var east_end := Vector2(feature.points[14][0],feature.points[14][1])
	var east_axis := (east_end-east_start).normalized()
	var east_length := east_start.distance_to(east_end)
	var east_out := Vector2(east_axis.y,-east_axis.x)
	# Edge 15 -> 14 points south; its outward normal must face east.
	assert(east_out.x>0.9)
	var roof_vertices := PackedVector2Array()
	var ducts := 0
	var bend_top := 0.0
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name=="EDA dining pale cornice":
			for vertex: Vector3 in mesh.mesh.get_faces():
				var point := mesh.transform*vertex
				if absf(point.y-12.18)<0.001: roof_vertices.append(Vector2(point.x,point.z))
		if mesh.material_override.resource_name=="EDA dining green ventilation ducts":
			for vertex: Vector3 in mesh.mesh.get_faces():
				var point := mesh.transform*vertex
				var delta := Vector2(point.x,point.z)-east_start
				var station := delta.dot(east_axis)
				assert(minf(absf(station-east_length*0.24),absf(station-east_length*0.28))<0.37,"Ducts left their photo-registered stations")
				assert(delta.dot(east_out)>-0.4 and delta.dot(east_out)<1.02,"Ducts left the photographed east wall")
				ducts += 1
				bend_top = maxf(bend_top,point.y)
		if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	assert(ducts>2 and bend_top>12.5,"Photo-visible duct bends missing")
	for coordinate: Array in feature.points:
		var found := false
		for vertex in roof_vertices:
			if vertex.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
		assert(found,"Saved dining roof lost a source corner")
	await physics_frame
	await physics_frame
	var space := model.get_world_3d().direct_space_state
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(350,group.position.y+20,220),Vector3(350,group.position.y+10,220)))
	assert(not roof.is_empty() and absf(roof.position.y-group.position.y-12.18)<0.03,"Dining roof collision detached")
	var east := east_start.lerp(east_end,0.5)
	var near := east+east_out*3
	var far := east-east_out*3
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x,group.position.y+7,near.y),Vector3(far.x,group.position.y+7,far.y)))
	assert(not wall.is_empty() and wall.position.distance_to(Vector3(east.x,group.position.y+7,east.y))<0.03,"Dining east wall collision missing")
	print("DINING GEOMETRY PASS: 19 source corners, east ducts, roof and east wall collision")
	quit()
