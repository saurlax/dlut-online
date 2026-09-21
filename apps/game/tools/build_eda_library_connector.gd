extends RefCounted
## Lower southern volume and the two visible exterior galleries.
func build(facade, points: PackedVector2Array, profile: Dictionary, wing_height: float, wall: Material, trim: Material, glass: Material, metal: Material) -> void:
	var east := points[1].lerp(points[2],float(profile.east_split))
	var west := points[38].lerp(points[0],float(profile.west_split))
	var high := PackedVector2Array([east,points[2],points[37],points[38],west])
	var low := PackedVector2Array([points[0],points[1],east,west])
	var height := float(profile.height)
	var floor_y := float(profile.gallery_floor)
	var depth := float(profile.gallery_depth)
	facade.shell(high,wing_height,0,wall,"LibraryHighWing")
	facade.shell(high,wing_height+0.22,wing_height,trim,"LibraryHighWingRoof")
	var render: StandardMaterial3D=facade.builder.material("Library connector render",Color("89877e"))
	render.albedo_texture=load("res://assets/textures/buildings/mineral_render_albedo.png")
	render.uv1_triplanar=true
	render.uv1_scale=Vector3.ONE*0.8
	facade.shell(low,floor_y,0,render,"LibraryConnectorBase")
	var rear := low
	var openings: Array[PackedVector2Array] = []
	for face in profile.faces:
		var a := points[int(face.edge)]
		var b := points[(int(face.edge)+1)%points.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)/2+out,points): out=-out
		var first := a.lerp(b,float(face.span[0]))
		var last := a.lerp(b,float(face.span[1]))
		var opening := PackedVector2Array([first+out,last+out,last-out*depth,first-out*depth])
		var clipped := Geometry2D.clip_polygons(rear,opening)
		assert(clipped.size()==1,"Connector gallery must preserve one closed rear volume")
		rear=clipped[0]
		var rings := Geometry2D.intersect_polygons(low,opening)
		assert(rings.size()==1)
		openings.append(rings[0])
		var count := int(face.columns)
		for i in count:
			var p := first.lerp(last,(i+0.2)/(count-0.6))-out*0.4
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=0.22
			cylinder.bottom_radius=0.22
			cylinder.height=height-floor_y
			cylinder.radial_segments=20
			var column_finish: Material=trim
			if int(face.edge)==1 and i in [1,2,3]:
				column_finish=preload("res://tools/build_eda_library_east_columns.gd").column_material(facade.builder)
			var node: MeshInstance3D=facade.builder.mesh_node(facade.group,cylinder,column_finish,"LibraryGalleryColumn")
			node.position=Vector3(p.x,(height+floor_y)/2,p.y)
			node.set_meta("walk_collision",true)
		if int(face.edge)==1:
			# Three exposed transverse beams follow the visible east support axes.
			for support_index in [1,2,3]:
				var support := first.lerp(last,(float(support_index)+0.2)/(count-0.6))
				var beam_start := support-out*0.4
				var beam_end := support-out*depth
				var beam_center := (beam_start+beam_end)/2
				var beam: MeshInstance3D=facade.builder.box(facade.group,Vector3(beam_center.x,height-0.1,beam_center.y),Vector3(beam_start.distance_to(beam_end),0.2,0.22),trim,"LibraryGalleryEndSoffitBeam")
				beam.rotation.y=-atan2((beam_end-beam_start).y,(beam_end-beam_start).x)
				beam.set_meta("walk_collision",false)
		facade.edge_box(first+out*0.08,last+out*0.08,floor_y-0.2,0.4,0.3,trim)
		var panes := int(face.glass_columns)
		facade.edge_box(first+out*0.09,last+out*0.09,(floor_y+0.3)/2,floor_y-0.6,0.08,glass)
		for i in panes+1:
			var p := first.lerp(last,float(i)/panes)+out*0.18
			facade.edge_box(p-axis*0.025,p+axis*0.025,floor_y/2,floor_y-0.5,0.07,metal)
		for i in 6:
			facade.edge_box(first+out*0.18,last+out*0.18,0.3+(floor_y-0.6)*i/5,0.055,0.07,metal)
		for y in [floor_y+0.4,floor_y+0.75,floor_y+1.1]:
			facade.edge_box(first-out*0.1,last-out*0.1,y,0.035,0.04,metal,y>floor_y+1)
		for i in panes+1:
			var p := first.lerp(last,float(i)/panes)-out*0.1
			facade.edge_box(p-axis*0.018,p+axis*0.018,floor_y+0.55,1.1,0.035,metal)
	facade.shell(rear,height,floor_y,render,"LibraryGalleryRear")
	facade.shell(low,height+0.22,height,trim,"LibraryConnectorRoof")
	# Polygon shells omit their bottom face; add indexed soffits over the openings.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in openings:
		var triangles := Geometry2D.triangulate_polygon(ring)
		for i in range(0,triangles.size(),3):
			var vertices: Array[Vector3] = []
			for j in 3:
				var p := ring[triangles[i+j]]
				vertices.append(Vector3(p.x,height,p.y))
			if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).y>0: vertices.reverse()
			for vertex in vertices: st.add_vertex(vertex)
	st.generate_normals()
	st.index()
	var soffit: MeshInstance3D=facade.builder.mesh_node(facade.group,st.commit(),trim,"LibraryGallerySoffit")
	soffit.set_meta("walk_collision",true)
