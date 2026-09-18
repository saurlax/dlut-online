extends SceneTree
## Check the actual tube primitive, including tilted and tapered branches.
func _initialize() -> void:
	var generator := preload("res://tools/vegetation_meshes.gd").new()
	for endpoint in [Vector3(0, 3, 0), Vector3(2, 1, -3), Vector3(0, -2, 0)]:
		for radius in [0.22, 0.03]:
			generator.wood = SurfaceTool.new()
			generator.wood.begin(Mesh.PRIMITIVE_TRIANGLES)
			generator.twig(Vector3.ZERO, endpoint, radius, radius * 0.3)
			var mesh: ArrayMesh = generator.wood.commit()
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var axis: Vector3 = endpoint.normalized()
			for i in range(0, vertices.size(), 3):
				var center := (vertices[i] + vertices[i+1] + vertices[i+2]) / 3.0
				var outward := (center - axis * center.dot(axis)).normalized()
				var front := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
				assert(front.dot(outward) > 0.7, "Bark front face points inward")
				for j in 3:
					assert(normals[i+j].dot(outward) > 0.7, "Bark normal points inward")
	print("VEGETATION NORMALS PASS: vertical, tilted, downward, trunk and twig")
	quit()
