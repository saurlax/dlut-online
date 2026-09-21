extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary, material: Material) -> void:
	var join = preload("res://tools/build_eda_library_ring.gd").new()
	var edges := PackedInt32Array(profile.edges)
	for level in profile.bands:
		var y := float(level)
		var outer := 1.8 if is_equal_approx(y,24.7) else 0.88
		for edge in edges:
			var next := (edge+1)%points.size()
			var polygon := PackedVector2Array([join.corner(points,edges,edge,edge,-0.12),join.corner(points,edges,next,edge,-0.12),join.corner(points,edges,next,edge,outer),join.corner(points,edges,edge,edge,outer)])
			if Geometry2D.is_polygon_clockwise(polygon): polygon.reverse()
			facade.shell(polygon,y+0.12,y-0.12,material)
			var underside := SurfaceTool.new()
			underside.begin(Mesh.PRIMITIVE_TRIANGLES)
			var indices := Geometry2D.triangulate_polygon(polygon)
			assert(not indices.is_empty(),"Invalid academic rotunda eave segment")
			for i in range(0,indices.size(),3):
				var vertices: Array[Vector3] = []
				for j in 3:
					var p := polygon[indices[i+j]]
					vertices.append(Vector3(p.x,y-0.12,p.y))
				if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
				for vertex in vertices: underside.add_vertex(vertex)
			underside.generate_normals()
			underside.index()
			var node: MeshInstance3D = facade.host.mesh_node(facade.group,underside.commit(),material,"AcademicRingUnderside")
			node.set_meta("walk_collision",true)
