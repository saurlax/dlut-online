extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in data.features:
		if item.id=="2304789": feature = item
	assert(feature.osm_id=="way/1076344145" and feature.sports_surfaces.size()==6)
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_2304789")
	var expected_area := 0.0
	var centers: Array[Vector2] = []
	for court: Dictionary in feature.sports_surfaces:
		var center := Vector2.ZERO
		var ring := PackedVector2Array()
		for p: Array in court.points:
			ring.append(Vector2(p[0],p[1]))
			center += ring[-1]/court.points.size()
		centers.append(center)
		for i in range(1,ring.size()-1): expected_area += absf((ring[i]-ring[0]).cross(ring[i+1]-ring[0]))/2
	var saved_area := 0.0
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name!="Court surface": continue
		assert(mesh.get_meta("walk_collision",false),"Playing surfaces lack collision marker")
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3 = mesh.transform*faces[i]
			var b: Vector3 = mesh.transform*faces[i+1]
			var c: Vector3 = mesh.transform*faces[i+2]
			if absf(a.y-0.3)>0.001 or absf(b.y-0.3)>0.001 or absf(c.y-0.3)>0.001: continue
			saved_area += absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))/2
		preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
	assert(absf(saved_area-expected_area)<0.1,"Saved courts missing, duplicated or replaced with generic rectangles")
	await physics_frame
	await physics_frame
	for center in centers:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(center.x,group.position.y+3,center.y),Vector3(center.x,group.position.y,center.y)))
		assert(not hit.is_empty() and absf(hit.position.y-group.position.y-0.3)<0.01,"Court center collision missing")
	print("TENNIS GEOMETRY PASS: six archived court areas and center collisions")
	quit()
