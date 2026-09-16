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
	print("PHOTO SURFACE CLIPPING PASS")
	quit()
