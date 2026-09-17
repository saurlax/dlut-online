extends RefCounted
## Offline terrain construction and fitting. No runtime mesh generation.

var data: Dictionary

func load_campus(campus: String) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/terrain.json" % campus))

func elevation(x: float, z: float) -> float:
	var col := clampf((x - float(data.origin_xz[0])) / float(data.step_m), 0, int(data.width) - 1.00001)
	var row := clampf((z - float(data.origin_xz[1])) / float(data.step_m), 0, int(data.height) - 1.00001)
	var c := int(col)
	var r := int(row)
	var u := col - c
	var v := row - r
	var a: float = data.rows[r][c]
	var b: float = data.rows[r][c + 1]
	var d: float = data.rows[r + 1][c]
	var e: float = data.rows[r + 1][c + 1]
	# Same diagonal as the terrain mesh, so physics and fitting agree.
	return a + u * (b - a) + v * (d - a) if u + v <= 1 else e + (1 - u) * (d - e) + (1 - v) * (b - e)

func point(c: int, r: int) -> Vector3:
	return Vector3(float(data.origin_xz[0]) + c * float(data.step_m), data.rows[r][c], float(data.origin_xz[1]) + r * float(data.step_m))

func build(builder: SceneTree, campus: String) -> void:
	load_campus(campus)
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in int(data.height) - 1:
		for c in int(data.width) - 1:
			for p in [point(c,r), point(c+1,r), point(c,r+1), point(c+1,r), point(c+1,r+1), point(c,r+1)]:
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = st.commit()
	mesh.material_override = builder.material("Terrain", Color("74795b"))
	terrain.add_child(mesh)
	mesh.owner = terrain
	mesh.create_trimesh_collision()
	for body in mesh.get_children():
		body.owner = terrain
		for shape in body.get_children():
			shape.owner = terrain
			shape.shape.backface_collision = true
	var packed := PackedScene.new()
	assert(packed.pack(terrain) == OK)
	assert(ResourceSaver.save(packed, "res://assets/campuses/%s/models/terrain.tscn" % campus) == OK)
	terrain.free()
	var model: Node3D = builder.scene
	var base := model.get_node_or_null("CampusBase")
	if base != null:
		model.remove_child(base)
		base.free()
	for feature: Dictionary in builder.manifest.features:
		var node_name: String = "Feature_" + feature.id + ("_" + str(int(feature.part)) if feature.has("part") else "")
		var group := model.get_node(node_name)
		if feature.kind == "hill":
			for child in group.get_children():
				group.remove_child(child)
				child.free()
		elif data.feature_base_y.has(node_name):
			group.position.y = data.feature_base_y[node_name]
			group.set_meta("terrain_preview_base_y", group.position.y)
		else:
			fit(group)
	for child in model.get_children():
		if child is MeshInstance3D:
			fit(child)

func fit(node: Node3D) -> void:
	if node is MeshInstance3D:
		if node.get_meta("road_surface", false) or node.get_meta("terrain_surface", false):
			fit_road(node)
			node.set_meta("walk_collision",true)
			return
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			subdivide(st, node.transform * faces[i], node.transform * faces[i+1], node.transform * faces[i+2])
		st.index()
		st.generate_normals()
		node.mesh = st.commit()
		node.transform = Transform3D.IDENTITY
		# Ground overlays must support walking above the underlying terrain.
		node.set_meta("walk_collision", true)
	else:
		for child in node.get_children():
			if child is Node3D:
				fit(child)

func subdivide(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var ab := Vector2(a.x-b.x, a.z-b.z).length_squared()
	var bc := Vector2(b.x-c.x, b.z-c.z).length_squared()
	var ca := Vector2(c.x-a.x, c.z-a.z).length_squared()
	if maxf(ab, maxf(bc, ca)) > 25.0:
		if ab >= bc and ab >= ca:
			var midpoint := (a+b)*0.5
			subdivide(st,a,midpoint,c)
			subdivide(st,midpoint,b,c)
		elif bc >= ca:
			var midpoint := (b+c)*0.5
			subdivide(st,a,b,midpoint)
			subdivide(st,a,midpoint,c)
		else:
			var midpoint := (c+a)*0.5
			subdivide(st,a,b,midpoint)
			subdivide(st,midpoint,b,c)
		return
	for p in [a,b,c]:
		st.add_vertex(p + Vector3.UP * (elevation(p.x,p.z) + 0.08))

## Clip roads and ground paving to the exact terrain triangles. Independent subdivision
## can interpolate different heights along the same seam and bury thin asphalt.
func fit_road(node: MeshInstance3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := node.mesh.get_faces()
	for i in faces.size(): faces[i] = node.transform*faces[i]
	var origin := Vector2(data.origin_xz[0], data.origin_xz[1])
	var step := float(data.step_m)
	for i in range(0, faces.size(), 3):
		var outline := PackedVector2Array()
		for k in 3:
			outline.append(Vector2(faces[i + k].x, faces[i + k].z))
		var bounds := Rect2(outline[0], Vector2.ZERO)
		for p in outline:
			bounds = bounds.expand(p)
		var first := Vector2i((bounds.position - origin) / step)
		var last := Vector2i((bounds.end - origin) / step)
		for row in range(maxi(0, first.y), mini(int(data.height) - 2, last.y) + 1):
			for col in range(maxi(0, first.x), mini(int(data.width) - 2, last.x) + 1):
				var a := origin + Vector2(col, row) * step
				var b := a + Vector2(step, 0)
				var c := a + Vector2(0, step)
				var d := a + Vector2(step, step)
				for cell in [PackedVector2Array([a, b, c]), PackedVector2Array([b, d, c])]:
					for piece in Geometry2D.intersect_polygons(outline, cell):
						var indices := Geometry2D.triangulate_polygon(piece)
						for j in range(0, indices.size(), 3):
							for k in [0, 2, 1]:
								var p: Vector2 = piece[indices[j + k]]
								st.add_vertex(Vector3(p.x, elevation(p.x, p.y) + faces[i].y + 0.08, p.y))
	st.index()
	st.generate_normals()
	node.mesh = st.commit()
	node.transform = Transform3D.IDENTITY
