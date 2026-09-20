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
