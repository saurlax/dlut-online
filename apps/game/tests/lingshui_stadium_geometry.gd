extends SceneTree
func _initialize() -> void: check.call_deferred()
func area(ring: PackedVector2Array) -> float:
	var result := 0.0
	for i in ring.size(): result += (ring[i]-ring[0]).cross(ring[(i+1)%ring.size()]-ring[0])*0.5
	return absf(result)
func check() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var feature: Dictionary
	for f in data.features:
		if f.id=="78473": feature=f
	assert(feature.osm_id=="way/31305649" and feature.points.size()==22 and not feature.has("reference_points"))
	var ring := PackedVector2Array()
	var pitch := PackedVector2Array()
	for p in feature.points: ring.append(Vector2(p[0],p[1]))
	for p in feature.sports.pitch_outline: pitch.append(Vector2(p[0],p[1]))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var group: Node3D = model.get_node("Feature_78473_0")
	var sums := {"apron":0.0,"pitch":0.0}
	var stand_vertices := 0
	for mesh: MeshInstance3D in group.get_children():
		var name: String = mesh.material_override.resource_name
		var faces := mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var tri := PackedVector2Array()
			var y := 0.0
			var horizontal := true
			for k in 3:
				var p: Vector3 = mesh.transform*faces[i+k]
				if k==0: y=p.y
				horizontal = horizontal and absf(p.y-y)<0.0001
				var flat := Vector2(p.x,p.z)
				var distance := INF
				for edge in ring.size(): distance=minf(distance,flat.distance_to(Geometry2D.get_closest_point_to_segment(flat,ring[edge],ring[(edge+1)%ring.size()])))
				assert(distance<0.002 or Geometry2D.is_point_in_polygon(flat,ring),"Stadium detail outside source boundary: "+name+str(flat))
				if name=="Stadium concrete": stand_vertices+=1
				tri.append(flat)
			if horizontal and name.begins_with("Apron") and absf(y-0.065)<0.001: sums.apron+=area(tri)
			if horizontal and name=="Lingshui field grass" and absf(y-0.10)<0.001:
				sums.pitch+=area(tri)
				var covered_area := 0.0
				for overlap in Geometry2D.intersect_polygons(tri,pitch): covered_area += area(overlap)
				assert(absf(covered_area-area(tri))<0.01)
	assert(absf(sums.apron-area(ring))<0.1)
	assert(absf(sums.pitch-area(pitch))<0.1)
	assert(stand_vertices>0)
	print("STADIUM GEOMETRY PASS: source apron, source grass, track and stand within boundary")
	quit()
