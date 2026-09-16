extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in manifest.features:
		if item.id=="77943": feature = item
	assert(feature.get("osm_id","")=="way/375541048" and not feature.has("reference_points"))
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_77943")
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
				assert(point.x>379 and point.x<384 and point.z>219 and point.z<224,"Ducts left the photographed east wall")
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
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(390,group.position.y+7,230),Vector3(375,group.position.y+7,230)))
	assert(not wall.is_empty() and wall.position.x>379 and wall.position.x<381,"Dining east wall collision missing")
	print("DINING GEOMETRY PASS: 19 source corners, east ducts, roof and east wall collision")
	quit()
