extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in manifest.features:
		if item.id=="77923": feature = item
	assert(feature.get("osm_id","")=="way/1076344144" and not feature.has("reference_points"))
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_77923")
	var base_vertices := PackedVector2Array()
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name=="EDA gym stone":
			for vertex: Vector3 in mesh.mesh.get_faces():
				var point := mesh.transform*vertex
				if absf(point.y-3)<0.001: base_vertices.append(Vector2(point.x,point.z))
		if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	for coordinate: Array in feature.points:
		var found := false
		for vertex in base_vertices:
			if vertex.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
		assert(found,"Saved gym base corner differs from OSM")
	await physics_frame
	await physics_frame
	var space := model.get_world_3d().direct_space_state
	var east := Vector2(feature.points[2][0],feature.points[2][1]).lerp(Vector2(feature.points[3][0],feature.points[3][1]),0.5)
	var at := Vector3(east.x,group.position.y+8,east.y)
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.RIGHT*15,at-Vector3.RIGHT*5))
	assert(not wall.is_empty() and wall.position.distance_to(at)<0.05,"East wall collision detached from OSM wall")
	var northwest := Vector2(feature.points[0][0],feature.points[0][1])
	var southwest := Vector2(feature.points[1][0],feature.points[1][1])
	var northeast := Vector2(feature.points[3][0],feature.points[3][1])
	var southeast := Vector2(feature.points[2][0],feature.points[2][1])
	var location := northwest.lerp(northeast,0.25).lerp(southwest.lerp(southeast,0.25),0.5)
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(location.x,group.position.y+40,location.y),Vector3(location.x,group.position.y+10,location.y)))
	assert(not roof.is_empty(),"Registered roof collision missing")
	assert(absf(roof.position.y-group.position.y-14.375)<0.03,"Sagging roof profile lost during registration")
	print("GYM GEOMETRY PASS: saved OSM base, east wall and curved roof collision")
	quit()
