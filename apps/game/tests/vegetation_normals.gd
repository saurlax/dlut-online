extends SceneTree

func _initialize() -> void:
	check_shared_tubes()
	var generator := preload("res://tools/vegetation_meshes.gd").new()
	# Adjacent leaning trunk segments must share ring positions and UVs even
	# when their radius crosses the branch LOD threshold.
	var rings: Array = []
	for segment in [[Vector3.ZERO,Vector3(0.04,1.5,0.03),0.09,0.06],[Vector3(0.04,1.5,0.03),Vector3(0.1,3,0.05),0.06,0.03]]:
		generator.wood = SurfaceTool.new()
		generator.wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		generator.twig(segment[0],segment[1],segment[2],segment[3],true)
		var arrays: Array = generator.wood.commit().surface_get_arrays(0)
		var ring: Dictionary = {}
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
			if absf(point.y-1.5)<0.00001:
				ring[point] = arrays[Mesh.ARRAY_TEX_UV][i]
		rings.append(ring)
	assert(rings[0].size()==rings[1].size(),"Trunk ring changes polygon count at joint")
	for point: Vector3 in rings[0]:
		assert(rings[1].has(point) and rings[0][point].is_equal_approx(rings[1][point]),"Open trunk seam or discontinuous bark UV")
	for segment in [
		[Vector3.ZERO,Vector3(0,2,0),0.22,0.18],
		[Vector3(1,2,3),Vector3(2.4,3.1,2.2),0.07,0.025],
		[Vector3(0,4,0),Vector3(0.7,2.4,0.3),0.015,0.003],
	]:
		generator.wood = SurfaceTool.new()
		generator.wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		generator.twig(segment[0],segment[1],segment[2],segment[3])
		var mesh: ArrayMesh = generator.wood.commit()
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var a: Vector3 = segment[0]
		var axis: Vector3 = (segment[1]-a).normalized()
		for i in range(0,vertices.size(),3):
			var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
			var radial := center-a-axis*(center-a).dot(axis)
			var front := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
			assert(front.dot(radial.normalized())>0.7,"Bark triangle front faces the axis")
			for j in 3:
				assert(normals[i+j].dot(front)>0.999,"Bark normal disagrees with its front face")
	# Pruning-head bark must face outward and its recessed cut must close the tip.
	for lod in 2:
		generator.detail = lod
		generator.wood = SurfaceTool.new()
		generator.wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base := Vector3(0.1, 2.9, -0.2)
		var end := base + Vector3(0.25, 0.19, 0.12)
		var axis := (end-base).normalized()
		generator.willow_pruning_head(base,end,0.12)
		var arrays: Array = generator.wood.commit().surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var sides := 10 if lod == 0 else 6
		assert(vertices.size()==sides*7*3,"Pruning head tip must be closed")
		for i in range(0,vertices.size(),3):
			var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
			var front := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
			if i < sides*6*3:
				var radial := center-base-axis*(center-base).dot(axis)
				assert(front.dot(radial.normalized())>0.7,"Pruning head side faces inward")
			else:
				assert(front.dot(axis)>0.98,"Pruning cut faces inward")
			for j in 3:
				assert(normals[i+j].dot(front)>0.999,"Pruning head normal disagrees with winding")
	# Check every saved wood triangle, including branch tips and distant LODs.
	var wood_triangles := 0
	for kind in ["broadleaf","willow","ginkgo","hedge","juniper","magnolia","cherry"]:
		for variant in 3:
			for lod in 2:
				var mesh: ArrayMesh = load("res://assets/campuses/eda/models/vegetation/%s_%d_%d.res" % [kind,variant,lod])
				var arrays := mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size(),3):
					var a := vertices[indices[i]]
					var b := vertices[indices[i+1]]
					var c := vertices[indices[i+2]]
					var front := (c-a).cross(b-a).normalized()
					assert(front.length_squared()>0.99,"Degenerate saved wood triangle")
					for j in 3:
						assert(normals[indices[i+j]].dot(front)>0.98,"Saved branch normal disagrees with winding: %s/%d/%d" % [kind,variant,lod])
					wood_triangles += 1
	# Independently check outward winding against the actual trunk axes.
	for kind in ["broadleaf","willow","ginkgo","hedge","magnolia","cherry"]:
		for variant in 3:
			for lod in 2:
				var mesh: ArrayMesh = load("res://assets/campuses/eda/models/vegetation/%s_%d_%d.res" % [kind,variant,lod])
				var arrays := mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size() if kind=="hedge" else (72 if lod==0 else 42),3):
					var a := vertices[indices[i]]
					var b := vertices[indices[i+1]]
					var c := vertices[indices[i+2]]
					var radial := (a+b+c)/3.0
					if kind=="hedge":
						# Shrubs have nine leaning stems rather than one origin-centered trunk.
						var angle := floori(i/24.0)*2.399963
						var root := Vector3(cos(angle),0,sin(angle))*0.13
						var tip := Vector3(cos(angle)*0.42,0.7,sin(angle)*0.42)
						radial -= Geometry3D.get_closest_point_to_segment(radial,root,tip)
					elif kind=="cherry":
						# First horizontal ring pair follows the actual leaning root segment.
						var tip:=Vector3.UP*(4.8+variant*0.3)*0.29/7.0+Vector3(0.12*(variant-1),0,0.09)/49.0
						radial-=Geometry3D.get_closest_point_to_segment(radial,Vector3.ZERO,tip)
					else:
						radial.y = 0.0
					var front := (c-a).cross(b-a).normalized()
					# Four-sided twigs can approach cos(45 degrees) at the facet edge.
					assert(front.dot(radial.normalized())>(0.7 if kind=="hedge" else 0.8),"Saved trunk is inside-out")
					assert(normals[indices[i]].dot(front)>0.98,"Saved trunk normals are inverted")
	print("VEGETATION NORMALS PASS: vertical, inclined and hanging branches; 36 saved trunk/hedge checks; ",wood_triangles," wood triangles across 42 saved meshes")
	quit()

func check_shared_tubes() -> void:
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
