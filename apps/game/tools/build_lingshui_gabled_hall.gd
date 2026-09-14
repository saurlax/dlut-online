extends RefCounted

# Photo-supported roof only; preserve the official footprint including chamfers.
func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var angle := float(profile.get("roof_rotation",0.0))
	if is_zero_approx(angle):
		build_aligned(builder,group,points,profile)
		return
	var local_points := PackedVector2Array()
	for point in points:
		local_points.append(point.rotated(-angle))
	var first := group.get_child_count()
	build_aligned(builder,group,local_points,profile)
	var transform := Transform3D(Basis(Vector3.UP,-angle),Vector3.ZERO)
	for index in range(first,group.get_child_count()):
		var child: Node3D = group.get_child(index)
		child.transform = transform * child.transform

func build_aligned(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var wall: Material = builder.material("Lingshui " + profile.color,Color(profile.color))
	builder.polygon(group,points,float(profile.eave_height),wall,"Building")
	group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
	var axis := 1 if profile.has("ridge_z") else 0
	var ridge: float = profile.get("ridge_z",profile.get("ridge_x",0.0))
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	roof.set_smooth_group(-1)
	for limits in [Vector2(bounds.position[axis]-1,ridge),Vector2(ridge,bounds.end[axis]+1)]:
		var clip := PackedVector2Array([Vector2(limits.x,bounds.position.y-1),Vector2(limits.y,bounds.position.y-1),Vector2(limits.y,bounds.end.y+1),Vector2(limits.x,bounds.end.y+1)])
		if axis == 1:
			clip = PackedVector2Array([Vector2(bounds.position.x-1,limits.x),Vector2(bounds.end.x+1,limits.x),Vector2(bounds.end.x+1,limits.y),Vector2(bounds.position.x-1,limits.y)])
		for piece in Geometry2D.intersect_polygons(points,clip):
			var indices := Geometry2D.triangulate_polygon(piece)
			assert(not indices.is_empty())
			for index in indices:
				var p: Vector2 = piece[index]
				roof.add_vertex(Vector3(p.x,roof_height(p[axis],profile,bounds),p.y))
	roof.generate_normals()
	var roof_node: MeshInstance3D = builder.mesh_node(group,roof.commit(),builder.material("Gabled hall roof",Color("777b70")),"GabledRoof")
	roof_node.set_meta("walk_collision",true)
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	caps.set_smooth_group(-1)
	for i in points.size():
		var p := points[i]
		var q := points[(i+1)%points.size()]
		var edge := PackedVector2Array([p])
		if (p[axis]-ridge)*(q[axis]-ridge)<0:
			edge.append(p.lerp(q,(ridge-p[axis])/(q[axis]-p[axis])))
		edge.append(q)
		for j in edge.size()-1:
			var a := Vector3(edge[j].x,float(profile.eave_height),edge[j].y)
			var b := Vector3(edge[j+1].x,float(profile.eave_height),edge[j+1].y)
			var c := Vector3(b.x,roof_height(edge[j+1][axis],profile,bounds),b.z)
			var d := Vector3(a.x,roof_height(edge[j][axis],profile,bounds),a.z)
			if a.distance_to(d)>0.001 or b.distance_to(c)>0.001:
				builder.triangle(caps,a,b,c)
				builder.triangle(caps,a,c,d)
	caps.generate_normals()
	var cap_node: MeshInstance3D = builder.mesh_node(group,caps.commit(),wall,"GableWalls")
	cap_node.set_meta("walk_collision",true)

func roof_height(x: float, profile: Dictionary, bounds: Rect2) -> float:
	var axis := 1 if profile.has("ridge_z") else 0
	var ridge: float = profile.get("ridge_z",profile.get("ridge_x",0.0))
	var span := ridge-bounds.position[axis] if x<ridge else bounds.end[axis]-ridge
	return lerpf(float(profile.height),float(profile.eave_height),clampf(absf(x-ridge)/span,0,1))
