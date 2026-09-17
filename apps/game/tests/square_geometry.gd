extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in data.features:
		if item.id=="2304850": feature = item
	assert(feature.osm_id=="way/1381503838" and not feature.has("reference_points"))
	var outer := PackedVector2Array()
	for p: Array in feature.points: outer.append(Vector2(p[0],p[1]))
	var expected_area := 0.0
	for i in outer.size(): expected_area += (outer[i]-outer[0]).cross(outer[(i+1)%outer.size()]-outer[0])/2
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("eda")
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_2304850")
	var saved_area := 0.0
	var samples: Array[Vector3] = []
	for mesh: MeshInstance3D in group.get_children():
		assert(mesh.get_meta("walk_collision",false))
		preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3 = mesh.transform*faces[i]
			var b: Vector3 = mesh.transform*faces[i+1]
			var c: Vector3 = mesh.transform*faces[i+2]
			var center := (a+b+c)/3
			assert(absf(center.y-terrain.elevation(center.x,center.z)-0.18)<0.003,"Square triangles bridge over the terrain")
			saved_area += absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))/2
			if i%90==0: samples.append(center)
	assert(absf(saved_area-absf(expected_area))<0.05,"Saved square differs from its source perimeter")
	await physics_frame
	await physics_frame
	for p in samples:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP))
		assert(not hit.is_empty() and hit.position.distance_to(p)<0.01,"Square walking collision differs from the visible surface")
	print("SQUARE GEOMETRY PASS: source area, exact terrain triangle fit and ",samples.size()," walking samples")
	quit()
