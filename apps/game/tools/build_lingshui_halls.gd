extends RefCounted

# Photo-supported shells of Feature 77445. Shared official footprint stays unchanged.
# Ring split, elevations and curvature are explicit photo-proportion estimates.
func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var masonry: Material = builder.material("Sports halls stone", Color("c0c2b9"))
	builder.polygon(group, points, 1.2, masonry, "ClosedPodium")
	group.get_child(group.get_child_count()-1).set_meta("walk_collision", true)
	for main_hall in [true, false]:
		var ring := PackedVector2Array()
		for index in profile.main_ring_indices if main_hall else profile.pool_ring_indices:
			ring.append(points[int(index)])
		var base: float = profile.podium_height if main_hall else 1.2
		if main_hall:
			builder.polygon(group, ring, base, masonry, "MainPodium")
			group.get_child(group.get_child_count()-1).set_meta("walk_collision", true)
		build_shell(builder, group, ring, main_hall, base)

func roof_height(p: Vector2, main_hall: bool) -> float:
	if main_hall:
		var u := clampf((p.x-406.0)/47.0,-1.0,1.0)
		var v := clampf((p.y-169.0)/44.0,-1.0,1.0)
		return 12.0 + 7.0 * sqrt(maxf(0.0,1.0-v*v)) + 8.0 * sin(PI * absf(u))
	var u := clampf((p.y-239.0)/26.0,-1.0,1.0)
	return 13.0 + 4.5 * sqrt(maxf(0.0,1.0-u*u))

func build_shell(builder, group: Node3D, ring: PackedVector2Array, main_hall: bool, base: float) -> void:
	var glass: Material = builder.material("Sports halls glazing",Color("47666c"))
	glass.metallic = 0.5
	glass.roughness = 0.24
	glass.albedo_texture = null
	var frame: Material = builder.material("Sports halls frames",Color("9daaa8"))
	var roof: Material = builder.material("Sports halls standing seam metal",Color("bfc7c7"))
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var join_wall := SurfaceTool.new()
	join_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_join := false
	# The photographs show a projecting eave above recessed glazing.
	var inset := Geometry2D.offset_polygon(ring, -1.6)
	assert(inset.size() == 1, "Each hall must retain one closed exterior shell")
	var wall_ring: PackedVector2Array = inset[0]
	var clockwise := Geometry2D.is_polygon_clockwise(wall_ring)
	for i in wall_ring.size():
		var a := wall_ring[i]
		var b := wall_ring[(i+1)%wall_ring.size()]
		var direction := (b-a).normalized()
		var outward := Vector2(direction.y,-direction.x) * (-1.0 if clockwise else 1.0)
		var join_edge := ring.size()-1 if main_hall else 6
		var midpoint := (a+b)*0.5
		var unverified_join := midpoint.distance_to(Geometry2D.get_closest_point_to_segment(midpoint,ring[join_edge],ring[(join_edge+1)%ring.size()])) < 2.0
		var surface: SurfaceTool = join_wall if unverified_join else wall
		has_join = has_join or unverified_join
		var count := maxi(1,ceili(a.distance_to(b)/2.5))
		for j in count:
			var p := a.lerp(b,float(j)/count)
			var q := a.lerp(b,float(j+1)/count)
			var h0 := roof_height(p,main_hall)
			var h1 := roof_height(q,main_hall)
			builder.triangle(surface,Vector3(p.x,base,p.y),Vector3(q.x,base,q.y),Vector3(q.x,h1,q.y))
			builder.triangle(surface,Vector3(p.x,base,p.y),Vector3(q.x,h1,q.y),Vector3(p.x,h0,p.y))
			if unverified_join:
				continue
			var outside := p + outward * 0.10
			beam(builder,group,Vector3(outside.x,base,outside.y),Vector3(outside.x,h0,outside.y),0.11,frame)
			for y in range(int(base)+2,int(minf(h0,h1)),2):
				beam(builder,group,Vector3(p.x,y,p.y)+Vector3(outward.x,0,outward.y)*0.12,Vector3(q.x,y,q.y)+Vector3(outward.x,0,outward.y)*0.12,0.065,frame)
			# Exposed roof-edge truss, visible in the main and swimming hall photos.
			beam(builder,group,Vector3(p.x,h0+0.08,p.y),Vector3(q.x,h1+0.08,q.y),0.20,frame)
			beam(builder,group,Vector3(p.x,h0-0.85,p.y),Vector3(q.x,h1-0.85,q.y),0.12,frame)
			beam(builder,group,Vector3(p.x,h0-0.85,p.y),Vector3(q.x,h1,q.y),0.085,frame)
	wall.generate_normals()
	var shell: MeshInstance3D = builder.mesh_node(group,wall.commit(),glass,"ClosedGlazedShell")
	shell.set_meta("walk_collision",true)
	if has_join:
		join_wall.generate_normals()
		var closed_join: MeshInstance3D = builder.mesh_node(group,join_wall.commit(),builder.material("Sports halls stone",Color("c0c2b9")),"UnverifiedClosedJoin")
		closed_join.set_meta("walk_collision",true)
	# Sample and clip the curved roof instead of substituting a box or a flat cap.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds := Rect2(ring[0],Vector2.ZERO)
	for p in ring:
		bounds = bounds.expand(p)
	var step := 2.0
	for xi in ceili(bounds.size.x/step):
		for zi in ceili(bounds.size.y/step):
			var p := bounds.position+Vector2(xi,zi)*step
			var cell := PackedVector2Array([p,p+Vector2(step,0),p+Vector2(step,step),p+Vector2(0,step)])
			for piece in Geometry2D.intersect_polygons(cell,ring):
				var indices := Geometry2D.triangulate_polygon(piece)
				for index in indices:
					var v: Vector2 = piece[index]
					st.add_vertex(Vector3(v.x,roof_height(v,main_hall),v.y))
	st.generate_normals()
	var cap: MeshInstance3D = builder.mesh_node(group,st.commit(),roof,"CurvedRoof")
	cap.set_meta("walk_collision",true)
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i+1)%ring.size()]
		var count := maxi(1, ceili(a.distance_to(b)/2.0))
		for j in count:
			var p := a.lerp(b,float(j)/count)
			var q := a.lerp(b,float(j+1)/count)
			beam(builder,group,Vector3(p.x,roof_height(p,main_hall),p.y),Vector3(q.x,roof_height(q,main_hall),q.y),0.22,frame)
	# Thin raised metal seams follow the actual generated surface, merged by material.
	for xi in range(1,ceili(bounds.size.x/1.6)):
		var x := bounds.position.x+xi*1.6
		for zi in ceili(bounds.size.y/step):
			var p := Vector2(x,bounds.position.y+zi*step)
			var q := p+Vector2(0,step)
			if Geometry2D.is_point_in_polygon(p,ring) and Geometry2D.is_point_in_polygon(q,ring):
				beam(builder,group,Vector3(p.x,roof_height(p,main_hall)+0.035,p.y),Vector3(q.x,roof_height(q,main_hall)+0.035,q.y),0.045,frame)

func beam(builder, group: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	if a.distance_to(b) < 0.001:
		return
	var node: MeshInstance3D = builder.box(group,(a+b)*0.5,Vector3(width,width,a.distance_to(b)),mat,"HallDetail")
	var direction := (b-a).normalized()
	node.basis = Basis.looking_at(direction,Vector3.RIGHT if absf(direction.y)>0.99 else Vector3.UP)
