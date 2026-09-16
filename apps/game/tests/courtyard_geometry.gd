extends SceneTree
## Verify saved roofs and collision preserve archived courtyard holes.
func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var probes: Array[Vector3] = []
	for feature: Dictionary in manifest.features:
		if feature.get("holes",[]).is_empty(): continue
		var group: Node3D = model.get_node("Feature_"+feature.id+"_"+str(int(feature.part)))
		for hole: Array in feature.holes:
			var ring := PackedVector2Array()
			var center := Vector2.ZERO
			for p: Array in hole:
				ring.append(Vector2(p[0],p[1]))
				center += ring[-1]/hole.size()
			assert(Geometry2D.is_point_in_polygon(center,ring),"Choose an interior probe for this courtyard")
			probes.append(Vector3(center.x,group.position.y,center.y))
			var cap_count := 0
			for child: MeshInstance3D in group.get_children():
				if child.name not in ["Building","Roof"]: continue
				var faces := child.mesh.get_faces()
				for i in range(0,faces.size(),3):
					if absf(faces[i].y-faces[i+1].y)>0.001 or absf(faces[i].y-faces[i+2].y)>0.001: continue
					cap_count += 1
					var triangle := PackedVector2Array()
					for k in 3: triangle.append(Vector2(faces[i+k].x,faces[i+k].z))
					for overlap in Geometry2D.intersect_polygons(triangle,ring):
						var area := 0.0
						for j in overlap.size(): area += (overlap[j]-overlap[0]).cross(overlap[(j+1)%overlap.size()]-overlap[0])*0.5
						assert(absf(area)<0.001,"Saved roof fills OSM courtyard "+feature.id)
				preload("res://scripts/shared/campus_collision.gd")._collider(child)
			assert(cap_count>0,"Building cap geometry missing")
	await physics_frame
	await physics_frame
	for p in probes:
		var hit := model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*100,p-Vector3.UP))
		assert(hit.is_empty(),"Building-only collision blocks courtyard")
	assert(probes.size()>=2)
	print("COURTYARD PASS: ",probes.size()," archived holes remain open in saved roofs and collision")
	quit()
