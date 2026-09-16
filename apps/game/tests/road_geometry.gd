extends SceneTree
const Roads = preload("res://tools/build_roads.gd")

func rectangle(x: float, y: float, width: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y), Vector2(x+width,y), Vector2(x+width,y+length), Vector2(x,y+length)])

func area(pieces: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for piece in pieces:
		for i in piece.size():
			total += piece[i].cross(piece[(i+1)%piece.size()]) * 0.5
	return total

func covered(p: Vector2, pieces: Array[PackedVector2Array]) -> bool:
	for piece in pieces:
		if Geometry2D.is_point_in_polygon(p, piece):
			return true
	return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var roads := Roads.new()
	# Crossing rectangles must have union area, not overlapping triangles.
	var rings: Array[PackedVector2Array] = [rectangle(-2,-10,4,20), rectangle(-10,-2,20,4)]
	assert(absf(area(roads.tessellate(rings)) - 144.0) < 0.001)
	# A closed block must retain its empty interior.
	rings = [rectangle(0,0,20,2), rectangle(0,18,20,2), rectangle(0,2,2,16), rectangle(18,2,2,16)]
	var pieces := roads.tessellate(rings)
	assert(absf(area(pieces) - 144.0) < 0.001)
	assert(not covered(Vector2(10,10), pieces))
	# Shared OSM nodes close bends between separate ways without proximity snapping.
	var centerlines := [{"width":4, "points":[[0,0],[0,20]]}, {"width":4, "points":[[0,20],[20,20]]}]
	var joined := preload("res://scripts/shared/road_geometry.gd").polygons(centerlines)
	assert(covered(Vector2(-0.5,20.5), roads.tessellate(joined)))
	centerlines[1].points = [[0,24],[20,24]]
	assert(not covered(Vector2(0,21), roads.tessellate(preload("res://scripts/shared/road_geometry.gd").polygons(centerlines))))
	# Real saved meshes follow the exact terrain plane within 2 mm, including
	# edge midpoints and triangle interiors, not only their sampled vertices.
	for campus in ["eda", "lingshui"]:
		var terrain := preload("res://tools/build_terrain.gd").new()
		terrain.load_campus(campus)
		var filename: String = "development_campus" if campus == "eda" else "lingshui_campus"
		var model: Node3D = load("res://assets/campuses/%s/models/%s.tscn" % [campus, filename]).instantiate()
		var count := 0
		for child in model.get_children():
			if not child is MeshInstance3D or not child.get_meta("road_surface", false):
				continue
			var clearance := 0.12 if campus == "lingshui" else (0.22 if child.material_override.resource_name == "Road" else 0.16)
			var faces: PackedVector3Array = child.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				for p in [(faces[i]+faces[i+1]+faces[i+2])/3.0, (faces[i]+faces[i+1])*0.5]:
					assert(absf(p.y - terrain.elevation(p.x,p.z) - clearance) < 0.002, "Road must follow the same terrain plane")
				count += 1
		assert(count > 0)
		print("ROAD TERRAIN PASS: ", campus, " triangles=", count)
		model.free()
	# Ray-test actual saved collision meshes along every imported segment.
	for campus in ["eda", "lingshui", "panjin"]:
		var filename: String = "development_campus" if campus == "eda" else campus + "_campus"
		var model: Node3D = load("res://assets/campuses/%s/models/%s.tscn" % [campus, filename]).instantiate()
		var stage := Node3D.new()
		root.add_child(stage)
		for child in model.get_children():
			if child is MeshInstance3D and child.get_meta("road_surface", false):
				child.owner = null
				model.remove_child(child)
				stage.add_child(child)
				child.owner = stage
				preload("res://scripts/shared/campus_collision.gd")._collider(child)
		model.free()
		await physics_frame
		await physics_frame
		var source: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/osm_roads.json" % campus)).roads
		var samples := 0
		for road in source:
			for i in range(road.points.size() - 1):
				var a := Vector2(road.points[i][0], road.points[i][1])
				var b := Vector2(road.points[i+1][0], road.points[i+1][1])
				if a.distance_to(b) < 0.01:
					continue
				for fraction in [0.01, 0.5, 0.99]:
					var p := a.lerp(b, fraction)
					var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,500,p.y), Vector3(p.x,-100,p.y))
					assert(not stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Missing road collision at %s %s" % [campus, p])
					samples += 1
		print("ROAD COLLISION PASS: ", campus, " samples=", samples)
		stage.queue_free()
		await physics_frame
	print("ROAD GEOMETRY PASS: junction union, holes, shared-node bends, no proximity snapping")
	quit()
