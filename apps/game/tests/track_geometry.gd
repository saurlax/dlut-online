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
	var saved_grass_area := 0.0
	for mesh: MeshInstance3D in group.get_children():
		if mesh.material_override.resource_name not in ["Running surface","Field grass","EDA striped field turf"]: continue
		assert(mesh.get_meta("walk_collision",false))
		preload("res://scripts/shared/campus_collision.gd")._collider(mesh)
		var is_running: bool = mesh.material_override.resource_name=="Running surface"
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var triangle := PackedVector2Array()
			for j in 3:
				var vertex: Vector3 = mesh.transform*faces[i+j]
				assert(absf(vertex.y-0.3)<0.001)
				triangle.append(Vector2(vertex.x,vertex.z))
			if is_running:
				saved_area += area(triangle)
				# Float32 coordinates at this map scale can make a <0.05 mm
				# boundary sliver on a long triangle; reject any wider overlap.
				var edge_length := maxf(triangle[0].distance_to(triangle[1]),maxf(triangle[1].distance_to(triangle[2]),triangle[2].distance_to(triangle[0])))
				for overlap in Geometry2D.intersect_polygons(triangle,grass):
					assert(area(overlap)<maxf(0.001,edge_length*0.00005),"Saved running surface fills grass region")
			else:
				saved_grass_area += area(triangle)
	assert(absf(saved_area-(area(outer)-area(grass)))<0.1,"Saved running surface differs from registered boundary")
	assert(absf(saved_grass_area-area(grass))<0.1,"Saved grass differs from its collision boundary")
	var pitch: Array = feature.sports_lines[0].points
	var north_goal := (Vector2(pitch[0][0],pitch[0][1])+Vector2(pitch[3][0],pitch[3][1]))/2.0
	var south_goal := (Vector2(pitch[1][0],pitch[1][1])+Vector2(pitch[2][0],pitch[2][1]))/2.0
	var axis := (south_goal-north_goal).normalized()
	var rear_points: Array[Vector2] = []
	for goal in [[north_goal,-axis],[south_goal,axis]]:
		for side in [-3.66,0.0,3.66]:
			var rear: Vector2 = goal[0]+goal[1]*2.1+Vector2(-axis.y,axis.x)*side
			assert(Geometry2D.is_point_in_polygon(rear,grass),"Goal rear frame is outside grass")
			rear_points.append(rear)
	await physics_frame
	await physics_frame
	var center := Vector2.ZERO
	for p in grass: center += p/grass.size()
	var north := grass[0].y
	var outer_north := outer[0].y
	for p in grass: north = minf(north,p.y)
	for p in outer: outer_north = minf(outer_north,p.y)
	for point in [center,Vector2(center.x,(north+outer_north)/2)]+rear_points:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,group.position.y+3,point.y),Vector3(point.x,group.position.y,point.y)))
		assert(not hit.is_empty() and absf(hit.position.y-group.position.y-0.3)<0.01,"Track or grass collision missing")
	print("TRACK GEOMETRY PASS: registered surface area, grass cutout and both surface collisions")
	quit()
