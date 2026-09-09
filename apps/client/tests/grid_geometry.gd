extends SceneTree
const Grid = preload("res://tools/campus_packs/grid_mesh.gd")

func _initialize() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-20,0,-30),Vector3(150,0,-30),Vector3(-20,0,140)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(-20,-30),Vector2(150,-30),Vector2(-20,140)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED,Color.GREEN,Color.BLUE])
	var buckets := Grid.split_surface(arrays,Transform3D.IDENTITY)
	assert(Grid.cell(Vector3(-0.1,0,-100.1)) == Vector2i(-1,-2))
	var area := 0.0
	assert(buckets.size() > 4)
	for cell: Vector2i in buckets:
		var a: Array = buckets[cell].arrays()
		var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var p := points[i]
			assert(p.x >= cell.x*100-0.001 and p.x <= (cell.x+1)*100+0.001)
			assert(p.z >= cell.y*100-0.001 and p.z <= (cell.y+1)*100+0.001)
			assert(a[Mesh.ARRAY_TEX_UV][i].distance_to(Vector2(p.x,p.z)) < 0.001)
			assert(a[Mesh.ARRAY_NORMAL][i].distance_to(Vector3.UP) < 0.001)
		for i in range(0,points.size(),3): area += (points[i+1]-points[i]).cross(points[i+2]-points[i]).length()*0.5
	assert(absf(area-14450.0) < 0.01,"Clipping must preserve triangle area without gaps or overlap")
	print("PASS: negative grid coordinates, clipping bounds, area conservation, UVs and normals")
	quit()
