extends RefCounted
## Offline terrain construction and fitting. No runtime mesh generation.

const STAIR_PROFILE=preload("res://tools/eda_stair_profile.gd")
var data: Dictionary
var shores: RefCounted
var xiang_profile:Dictionary={}
var xiang_base:float=0.0

func load_campus(campus: String) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/%s/data/terrain.json" % campus))
	shores = preload("res://tools/build_lake_shores.gd").new()
	shores.load_campus(campus, data)
	xiang_profile.clear()
	if campus=="eda":
		xiang_profile=preload("res://tools/eda_xiang_plaza_profile.gd").load_profile()
		xiang_base=preload("res://tools/eda_xiang_plaza_profile.gd").lower_height(self,xiang_profile)

func elevation(x: float, z: float) -> float:
	if xiang_profile.is_empty() or x < -160 or x > -80 or z < 300 or z > 360:return shore_elevation(x,z)
	# Interpolate the same one-metre triangles used by the ground and road cutters.
	var grid:=Vector2(x,z)-Vector2(data.origin_xz[0],data.origin_xz[1])
	var corner:=grid.floor()+Vector2(data.origin_xz[0],data.origin_xz[1])
	var uv:=grid-grid.floor()
	var a:=graded_sample(corner);var b:=graded_sample(corner+Vector2.RIGHT)
	var c:=graded_sample(corner+Vector2.DOWN);var d:=graded_sample(corner+Vector2.ONE)
	return a+uv.x*(b-a)+uv.y*(c-a) if uv.x+uv.y<=1 else d+(1-uv.x)*(c-d)+(1-uv.y)*(b-d)

func graded_sample(at:Vector2)->float:
	return preload("res://tools/eda_xiang_plaza_profile.gd").ground_height(at,shore_elevation(at.x,at.y),xiang_base,xiang_profile)

func shore_elevation(x:float,z:float)->float:
	return shores.elevation(self,x,z) if shores != null else raw_elevation(x,z)

func raw_elevation(x: float, z: float) -> float:
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
	var x := float(data.origin_xz[0])+c*float(data.step_m)
	var z := float(data.origin_xz[1])+r*float(data.step_m)
	return Vector3(x,elevation(x,z),z)

func cell_triangles(col: int, row: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var divisions: int = shores.divisions(col,row) if shores != null else 1
	var cell_x:float=float(data.origin_xz[0])+col*float(data.step_m)
	var cell_z:float=float(data.origin_xz[1])+row*float(data.step_m)
	if not xiang_profile.is_empty() and cell_x>=-170 and cell_x<=-70 and cell_z>=290 and cell_z<=370:divisions=int(data.step_m)
	var step := float(data.step_m)/divisions
	var origin := Vector2(data.origin_xz[0],data.origin_xz[1])+Vector2(col,row)*float(data.step_m)
	for r in divisions:
		for c in divisions:
			var a := origin+Vector2(c,r)*step
			var b := a+Vector2(step,0)
			var d := a+Vector2(0,step)
			var e := a+Vector2(step,step)
			result.append(PackedVector2Array([a,b,d]))
			result.append(PackedVector2Array([b,e,d]))
	return result

func build(builder: SceneTree, campus: String) -> void:
	load_campus(campus)
	var water := preload("res://tools/build_water.gd").new()
	var regions := water.regions(builder.manifest, self, campus)
	save_terrain(builder.material("Terrain", Color("74795b")), campus, regions)
	var model: Node3D = builder.scene
	var base := model.get_node_or_null("CampusBase")
	if base != null:
		model.remove_child(base)
		base.free()
	for feature: Dictionary in builder.manifest.features:
		var node_name: String = "Feature_" + feature.id + ("_" + str(int(feature.part)) if feature.has("part") else "")
		var group := model.get_node(node_name)
		if feature.kind == "water": continue
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
		if child is MeshInstance3D: fit(child)
	water.replace_surfaces(model, regions, self)

func save_terrain(material: Material, campus: String, regions: Array) -> void:
	var water := preload("res://tools/build_water.gd").new()
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_meta("water_regions", regions)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var replacements: Array[PackedVector2Array]=[]
	if campus=="eda":
		replacements.append(STAIR_PROFILE.mask(STAIR_PROFILE.load_profile()))
		replacements.append_array(preload("res://tools/eda_xiang_plaza_profile.gd").masks())
		var entrance=preload("res://tools/eda_sports_entry_profile.gd")
		replacements.append(entrance.mask(entrance.load_profile()))
	for r in int(data.height) - 1:
		for c in int(data.width) - 1:
			for cell in cell_triangles(c,r):
				var points := PackedVector3Array()
				for p in cell: points.append(Vector3(p.x,elevation(p.x,p.y),p.y))
				var pieces: Array[PackedVector3Array] = [points]
				for replacement in replacements:
					var next: Array[PackedVector3Array] = []
					for piece in pieces: next.append_array(STAIR_PROFILE.outside_triangle(piece,replacement))
					pieces = next
				for piece in pieces: water.terrain_triangle(st, piece, regions, self)
	if not shores.profile.is_empty(): water.seal_shores(st,regions,self)
	st.index()
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = st.commit()
	mesh.material_override = material
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

func fit(node: Node3D) -> void:
	if node is MeshInstance3D:
		if node.get_meta("road_surface", false) or node.get_meta("terrain_surface", false):
			fit_road(node)
			node.set_meta("walk_collision",node.get_meta("walk_collision",true))
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
				for cell in cell_triangles(col,row):
					for piece in Geometry2D.intersect_polygons(outline, cell):
						var indices := Geometry2D.triangulate_polygon(piece)
						for j in range(0, indices.size(), 3):
							var pa: Vector2 = piece[indices[j]]
							var pb: Vector2 = piece[indices[j+1]]
							var pc: Vector2 = piece[indices[j+2]]
							var signed_area := (pb-pa).cross(pc-pa)
							# Sub-millimetre slivers can collapse when scene vertices are serialized.
							var longest_edge := maxf(pa.distance_to(pb), maxf(pb.distance_to(pc), pc.distance_to(pa)))
							if absf(signed_area) < maxf(0.000001, longest_edge * 0.001):
								continue
							# X/Z mapping makes positive 2D area a clockwise +Y face.
							# Double-sided legacy materials hid the previous inverted faces.
							for k in ([0, 1, 2] if signed_area > 0 else [0, 2, 1]):
								var p: Vector2 = piece[indices[j + k]]
								st.add_vertex(Vector3(p.x, elevation(p.x, p.y) + faces[i].y + 0.08, p.y))
	st.index()
	st.generate_normals()
	node.mesh = st.commit()
	node.transform = Transform3D.IDENTITY
