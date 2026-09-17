extends SceneTree

func area(ring: PackedVector2Array) -> float:
	var result := 0.0
	for i in ring.size(): result += (ring[i]-ring[0]).cross(ring[(i+1)%ring.size()]-ring[0])/2
	return absf(result)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var feature: Dictionary
	for item: Dictionary in data.features:
		if item.id=="39327169": feature = item
	assert(feature.osm_id=="way/1076344139" and not feature.has("reference_points"))
	var outer := PackedVector2Array()
	var grass := PackedVector2Array()
	for p: Array in feature.sports_surfaces[0].points: outer.append(Vector2(p[0],p[1]))
	for p: Array in feature.sports_surfaces[0].holes[0]: grass.append(Vector2(p[0],p[1]))
	var model: Node3D = load("res://assets/campuses/eda/models/development_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_39327169")
	var saved_area := 0.0
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name not in ["Running surface","Field grass"]: continue
		assert(mesh.get_meta("walk_collision",false))
		preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		if mesh.material_override.resource_name!="Running surface": continue
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var triangle := PackedVector2Array()
			for j in 3:
				var vertex: Vector3 = mesh.transform*faces[i+j]
				assert(absf(vertex.y-0.3)<0.001)
				triangle.append(Vector2(vertex.x,vertex.z))
			saved_area += area(triangle)
			for overlap in Geometry2D.intersect_polygons(triangle,grass):
				assert(area(overlap)<0.001,"Saved running surface fills grass region")
	assert(absf(saved_area-(area(outer)-area(grass)))<0.1,"Saved running surface differs from registered boundary")
	await physics_frame
	await physics_frame
	var center := Vector2.ZERO
	for p in grass: center += p/grass.size()
	var north := grass[0].y
	var outer_north := outer[0].y
	for p in grass: north = minf(north,p.y)
	for p in outer: outer_north = minf(outer_north,p.y)
	for point in [center,Vector2(center.x,(north+outer_north)/2)]:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,group.position.y+3,point.y),Vector3(point.x,group.position.y,point.y)))
		assert(not hit.is_empty() and absf(hit.position.y-group.position.y-0.3)<0.01,"Track or grass collision missing")
	print("TRACK GEOMETRY PASS: registered surface area, grass cutout and both surface collisions")
	quit()
