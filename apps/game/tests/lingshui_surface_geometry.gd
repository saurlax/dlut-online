extends SceneTree
func _initialize() -> void: check.call_deferred()
func area(ring: PackedVector2Array) -> float:
	var total := 0.0
	for i in ring.size(): total += (ring[i]-ring[0]).cross(ring[(i+1)%ring.size()]-ring[0])*0.5
	return absf(total)
func check() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/lingshui/data/campus.json"))
	var model: Node3D = load("res://assets/campuses/lingshui/models/lingshui_campus.tscn").instantiate()
	root.add_child(model)
	var terrain := preload("res://tools/build_terrain.gd").new()
	terrain.load_campus("lingshui")
	var count := 0
	for f in data.features:
		if f.id not in ["1331412","2145432","81106","81107","81675","81654","81656"]: continue
		var height := 0.05 if f.kind=="water" else 0.06
		assert(f.footprint_source=="osm" and not f.has("reference_points"))
		var ring := PackedVector2Array()
		for p in f.points: ring.append(Vector2(p[0],p[1]))
		var group: Node3D = model.get_node("Feature_"+f.id+"_0")
		var total := 0.0
		for mesh: MeshInstance3D in group.get_children():
			var faces := mesh.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var tri := PackedVector2Array()
				var top := true
				for j in 3:
					var p: Vector3 = mesh.transform*faces[i+j]
					top = top and absf(p.y-height)<0.001
					tri.append(Vector2(p.x,p.z))
				if not top: continue
				total += area(tri)
				for p in tri:
					var distance := INF
					for edge in ring.size(): distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,ring[edge],ring[(edge+1)%ring.size()])))
					assert(distance<0.001 or Geometry2D.is_point_in_polygon(p,ring),"Saved shore vertex moved outside source")
				var center := (tri[0]+tri[1]+tri[2])/3
				assert(terrain.elevation(center.x,center.y)<group.position.y+height,"Surface buried at "+str(center))
		assert(absf(total-area(ring))<0.1,"Saved surface differs from source area")
		count += 1
	assert(count==7)
	print("SURFACE GEOMETRY PASS: two water areas and five sports fields, saved boundaries/areas and surface heights")
	quit()
