extends SceneTree
## Synthetic wall with an opening: bounded finishes must not bridge the gap.

func _initialize() -> void:
	var builder = preload("res://tools/build_photo_surfaces.gd").new()
	var source := SurfaceTool.new()
	source.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect in [Rect2(0, 0, 1, 3), Rect2(2, 0, 1, 3)]:
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for index in [0, 1, 2, 0, 2, 3]:
			source.add_vertex(Vector3(corners[index].x, corners[index].y, 0))
	var wall := MeshInstance3D.new()
	wall.mesh = source.commit()
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = builder.clip_shell(result, wall, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Rect2(0.5, 1, 2, 1))
	assert(count > 0)
	var arrays := result.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var area := 0.0
	for i in range(0, vertices.size(), 3):
		area += (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).length() * 0.5
		var middle := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
		assert(middle.x <= 1.0 or middle.x >= 2.0, "Cladding bridged opening")
	for v in vertices:
		assert(v.x >= 0.4999 and v.x <= 2.5001 and v.y >= 0.9999 and v.y <= 2.0001)
		assert(is_equal_approx(v.z, 0.012))
	assert(is_equal_approx(area, 1.0), "Clipped wall area changed")
	var off_plane := SurfaceTool.new()
	off_plane.begin(Mesh.PRIMITIVE_TRIANGLES)
	wall.position.z = 1.0
	assert(builder.clip_shell(off_plane, wall, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Rect2(0, 0, 3, 3)) == 0)
	wall.free()
	check_curved_cladding(builder)
	# A remapped box must retain geometry and have usable tangent frames on ALL faces.
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.mesh.size = Vector3(2, 3, 0.03)
	var original: Array = box.mesh.surface_get_arrays(0)
	preload("res://tools/build_surface_materials.gd").new().map_box(box, Vector2(4, 5))
	var mapped: Array = box.mesh.surface_get_arrays(0)
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
		assert(original[channel] == mapped[channel], "UV remapping changed geometry")
	var uv: PackedVector2Array = mapped[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = mapped[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = mapped[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = mapped[Mesh.ARRAY_TANGENT]
	for i in range(0, indices.size(), 3):
		assert(absf((uv[indices[i+1]] - uv[indices[i]]).cross(uv[indices[i+2]] - uv[indices[i]])) > 0.00001, "Degenerate side UV")
	for i in normals.size():
		var tangent := Vector3(tangents[i*4], tangents[i*4+1], tangents[i*4+2])
		assert(tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001)
		assert(absf(tangent.dot(normals[i])) < 0.001, "Tangent not orthogonal")
		if absf(normals[i].z) > 0.5:
			assert(tangent.dot(Vector3.RIGHT) > 0.999, "Facade tangent does not follow U")
	box.free()
	print("PHOTO SURFACE CLIPPING PASS")
	quit()

func check_curved_cladding(builder) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/campus.json"))
	var points := PackedVector2Array()
	for feature in manifest.features:
		if feature.id=="77927":
			for p in feature.points: points.append(Vector2(p[0],p[1]))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../references/eda/buildings/academic_facades.json"))
	var curve := preload("res://tools/eda_ellipse_envelope.gd").new()
	curve.configure(points,profiles["77927"].osm_registration.curve_refinement)
	var origin := points[13]
	var axis := (points[14]-origin).normalized()
	var length := origin.distance_to(points[14])
	var out := Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+points[14])*.5+out,points): out=-out
	var source := SurfaceTool.new()
	source.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The registered C curve carries two bounded patches separated by an opening.
	for span in [Vector2(0,.4),Vector2(.6,1)]:
		var a: Vector2 = origin+axis*length*span.x
		var b: Vector2 = origin+axis*length*span.y
		var corners := [Vector3(a.x,10,a.y),Vector3(b.x,10,b.y),Vector3(b.x,11,b.y),Vector3(a.x,11,a.y)]
		for i in [0,2,1,0,3,2]: source.add_vertex(corners[i])
	var wall := MeshInstance3D.new()
	wall.mesh=source.commit()
	var clipped := SurfaceTool.new()
	clipped.begin(Mesh.PRIMITIVE_TRIANGLES)
	assert(builder.clip_shell(clipped,wall,origin,axis,out,Rect2(0,10,length,1))>0)
	var finish := MeshInstance3D.new()
	finish.mesh=clipped.commit()
	curve.deform(finish)
	var arrays: Array = finish.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var curved := false
	for vertex in vertices:
		var delta := Vector2(vertex.x,vertex.z)-origin
		assert(vertex.y>=9.9999 and vertex.y<=11.0001,"Curved cladding escaped its vertical registration")
		var station := delta.dot(axis)/length
		assert(station<.415 or station>.585,"Curved material bridged the source opening")
		if delta.dot(out)>.05: curved=true
	assert(curved,"C cladding must follow the curved wall instead of remaining a flat chord")
	for i in range(0,indices.size(),3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		var normal := (c-a).cross(b-a).normalized()
		assert(normal.dot(Vector3(out.x,0,out.y))>.94,"Curved cladding faces inward")
		for pair in [[a,b],[b,c],[c,a]]:
			assert(Vector2(pair[0].x-pair[1].x,pair[0].z-pair[1].z).length()<=.52,"Curved cladding kept a coarse straight segment")
	# Registration endpoints must survive the pipeline, including both opening jambs.
	for fraction in [0.0,.4,.6,1.0]:
		for y in [10.0,11.0]:
			var p := origin+axis*length*float(fraction)+out*.012
			var source_p := Vector3(p.x,float(y),p.y)
			var expected := source_p+curve.shift(source_p)
			var nearest := INF
			for vertex in vertices: nearest=minf(nearest,vertex.distance_to(expected))
			assert(nearest<.003,"Curved cladding lost a registered border or opening jamb")
	wall.free()
	finish.free()
	print("C CURVED CLADDING PASS: vertical bounds, curved coverage, open gap, outward normals and preserved borders")
