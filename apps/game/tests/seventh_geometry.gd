extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in manifest.features:
		if item.id=="2304982": feature = item
	assert(feature.building_parts.size()==2 and not feature.has("reference_points"))
	assert(feature.height==63.6 and feature.height_source=="official-news-81930")
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_2304982")
	var top_vertices := PackedVector2Array()
	for mesh: MeshInstance3D in group.get_children():
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point := mesh.transform*vertex
			if absf(point.y-63.6)<0.001: top_vertices.append(Vector2(point.x,point.z))
		if mesh.get_meta("walk_collision",false): preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	for coordinate: Array in feature.building_parts[0].points:
		var found := false
		for vertex in top_vertices:
			if vertex.distance_to(Vector2(coordinate[0],coordinate[1]))<0.001: found = true
		assert(found,"Saved tower parapet lost a source corner")
	await physics_frame
	await physics_frame
	var space := model.get_world_3d().direct_space_state
	# Independent locations distinguish the south tower, low north podium and
	# photo-visible raised courtyard roof. An overall extruded envelope fails.
	for sample in [[395,145,62.4],[365,100,8.2],[385,117,12.3]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample[0],group.position.y+80,sample[1]),Vector3(sample[0],group.position.y-1,sample[1])))
		assert(not hit.is_empty(),"Seventh roof collision missing")
		assert(absf(hit.position.y-group.position.y-float(sample[2]))<0.04,"Seventh high/low roof partition is wrong")
	print("SEVENTH GEOMETRY PASS: two source parts, official height, nine parapet corners and three roof levels")
	quit()
