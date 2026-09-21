extends RefCounted

func build_cross_members(facade, points: PackedVector2Array, profile: Dictionary, height: float, material: Material) -> void:
	var edges := PackedInt32Array(profile.edges)
	var total := 0.0
	for edge in edges: total+=points[edge].distance_to(points[(edge+1)%points.size()])
	var count := maxi(1,roundi(total/float(profile.spacing)))
	var spacing := total/count
	var distance := spacing/2
	var start := 0.0
	for edge in edges:
		var a := points[edge]
		var b := points[(edge+1)%points.size()]
		var length := a.distance_to(b)
		var normal := outward(points,edge)
		while distance<start+length:
			var at := a.lerp(b,(distance-start)/length)
			facade.edge_box(at-normal*0.6,at+normal*1.3,height,0.16,0.18,material,true)
			var axis := (b-a).normalized()
			var inner := at-normal*0.6
			var roof := height-1.68
			facade.edge_box(inner-axis*0.09,inner+axis*0.09,(roof+height)/2,height-roof,0.18,material,true)
			distance+=spacing
		start+=length

func outward(points: PackedVector2Array, edge: int) -> Vector2:
	var a := points[edge]
	var b := points[(edge+1)%points.size()]
	var normal := Vector2((b-a).y,-(b-a).x).normalized()
	return -normal if Geometry2D.is_point_in_polygon((a+b)/2+normal,points) else normal

func corner(points: PackedVector2Array, edges: PackedInt32Array, vertex: int, edge: int, distance: float) -> Vector2:
	var previous := (vertex-1+points.size())%points.size()
	var normal := outward(points,edge)
	if previous in edges and vertex in edges:
		var bisector := (outward(points,previous)+outward(points,vertex)).normalized()
		return points[vertex]+bisector*(distance/bisector.dot(normal))
	return points[vertex]+normal*distance

func build_segment(facade, points: PackedVector2Array, edges: PackedInt32Array, edge: int, height: float, material: Material) -> void:
	var next := (edge+1)%points.size()
	var polygon := PackedVector2Array([corner(points,edges,edge,edge,1.05),corner(points,edges,next,edge,1.05),corner(points,edges,next,edge,1.55),corner(points,edges,edge,edge,1.55)])
	facade.shell(polygon,height+0.14,height-0.14,material,"LibraryMiteredRing")
	# Building shells omit the underside; this exposed beam needs one.
	var underside := SurfaceTool.new()
	underside.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		var vertices: Array[Vector3] = []
		for j in 3:
			var p := polygon[indices[i+j]]
			vertices.append(Vector3(p.x,height-0.14,p.y))
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
		for vertex in vertices: underside.add_vertex(vertex)
	underside.generate_normals()
	underside.index()
	var node: MeshInstance3D = facade.builder.mesh_node(facade.group,underside.commit(),material,"LibraryRingUnderside")
	node.set_meta("walk_collision",true)
