extends RefCounted

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(a)
	if (b-a).cross(c-a).dot(normal)>0:
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(b)
		st.add_vertex(c)

func prism(host, group: Node3D, ring: PackedVector2Array, bottom: float, top: float, mat: Material, title: String, solid: bool) -> void:
	if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(ring)
	for i in range(0,indices.size(),3):
		var a := ring[indices[i]]
		var b := ring[indices[i+1]]
		var c := ring[indices[i+2]]
		triangle(st,Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(c.x,top,c.y),Vector3.UP)
		triangle(st,Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(c.x,bottom,c.y),Vector3.DOWN)
	for i in ring.size():
		var p := ring[i]
		var q := ring[(i+1)%ring.size()]
		var normal := Vector3(q.y-p.y,0,p.x-q.x).normalized()
		var a := Vector3(p.x,bottom,p.y)
		var b := Vector3(q.x,bottom,q.y)
		var c := Vector3(q.x,top,q.y)
		var d := Vector3(p.x,top,p.y)
		triangle(st,a,b,c,normal)
		triangle(st,a,c,d,normal)
	var node: MeshInstance3D = host.mesh_node(group,st.commit(),mat,title)
	node.set_meta("walk_collision",solid)

func ring_for(f, radius: float, offset: float, center: Vector2, segments: int) -> PackedVector2Array:
	var ring := PackedVector2Array()
	var begin := -asin(offset/radius)
	for i in segments+1:
		var angle := lerpf(begin,PI-begin,float(i)/segments)
		ring.append(center+f.axis*cos(angle)*radius+f.out*sin(angle)*radius)
	return ring

func build(host, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	var s: Dictionary = profile.round_annex
	var f = preload("res://tools/build_eda_academic.gd").new()
	f.frame_for(points,int(profile.court_edge),int(profile.court_end_vertex))
	var offset := float(s.outward_offset)
	var center: Vector2 = f.origin+f.axis*f.length*float(s.station)+f.out*offset
	var materials := []
	for item in [["wall","acada4"],["lower","878d87"],["glass","435551"],["coping","c3c6b7"],["roof","535e59"],["frame","4b514e"]]:
		var mat: StandardMaterial3D = host.material("EDA comprehensive annex "+item[0],Color(item[1]))
		mat.albedo_texture=null
		mat.cull_mode=BaseMaterial3D.CULL_BACK
		materials.append(mat)
	for layer in [[s.lower_radius,s.bottom,s.lower_top,materials[1],"Lower"],[s.upper_radius,s.lower_top,s.upper_top,materials[0],"Upper"],[s.upper_radius,s.upper_top,s.roof_top,materials[4],"Roof"]]:
		prism(host,group,ring_for(f,layer[0],offset,center,int(s.segments)),layer[1],layer[2],layer[3],"ComprehensiveAnnex"+layer[4],true)
	# Only the outer curved edge receives coping; the attachment chord stays bare.
	var outer := ring_for(f,float(s.upper_radius),offset,center,int(s.segments))
	var inner := ring_for(f,float(s.upper_radius)-float(s.coping_width),offset,center,int(s.segments))
	for i in int(s.segments):
		prism(host,group,PackedVector2Array([outer[i],outer[i+1],inner[i+1],inner[i]]),float(s.roof_top),float(s.coping_top),materials[3],"ComprehensiveAnnexCoping",false)
	for layer in [[s.lower_radius,s.lower_window_y,s.lower_window_angles],[s.upper_radius,s.upper_window_y,s.upper_window_angles]]:
		for degrees in layer[2]:
			var angle := deg_to_rad(float(degrees))
			var n: Vector2 = f.axis*cos(angle)+f.out*sin(angle)
			for part in [[float(s.window_width)+0.10,float(s.window_height)+0.10,0.035,0.0,materials[5],"Frame"],[s.window_width,s.window_height,0.075,0.0,materials[2],"Window"],[s.window_width,0.045,0.115,0.35,materials[5],"Mullion"]]:
				var p: Vector2 = center+n*(float(layer[0])+float(part[2]))
				var node: MeshInstance3D = host.box(group,Vector3(p.x,float(layer[1])+float(part[3]),p.y),Vector3(part[0],part[1],0.04),part[4],"ComprehensiveAnnex"+part[5])
				node.rotation.y=-atan2(-n.x,n.y)
				node.set_meta("walk_collision",false)
