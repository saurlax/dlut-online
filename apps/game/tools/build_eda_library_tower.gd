extends RefCounted

func build(facade, points: PackedVector2Array, profile: Dictionary, body_height: float, trim: Material, glass: Material, metal: Material) -> void:
	var footprint := PackedVector2Array()
	for index in profile.vertices: footprint.append(points[int(index)])
	var top := float(profile.height)
	# Keep the registered ground footprint. The existing shell forms the base;
	# only the visible tower above the rotunda is added here.
	facade.shell(footprint,top,body_height,trim,"LibraryTowerUpperBody")
	facade.shell(footprint,top+0.24,top,trim,"LibraryTowerCap")
	var low := float(profile.glass_bottom)
	var high := float(profile.glass_top)
	var rows := int(profile.rows)
	for edge in profile.glazed_edges:
		var a := points[int(edge)]
		var b := points[(int(edge)+1)%points.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)/2+out,points): out=-out
		var first := a+axis*0.22+out*0.16
		var last := b-axis*0.22+out*0.16
		var columns := maxi(1,roundi(first.distance_to(last)/float(profile.column_spacing)))
		for column in columns:
			for row in rows:
				var y := low+(high-low)*(row+0.5)/rows
				facade.edge_box(first.lerp(last,float(column)/columns),first.lerp(last,float(column+1)/columns),y,(high-low)/rows,0.07,glass)
		for column in columns+1:
			var at := first.lerp(last,float(column)/columns)+out*0.055
			facade.edge_box(at-axis*0.035,at+axis*0.035,(high+low)/2,high-low,0.12,metal)
		for row in rows+1:
			facade.edge_box(first+out*0.055,last+out*0.055,low+(high-low)*row/rows,0.055,0.12,metal)
		# Pale vertical ribs separate the glazed faces.
		facade.edge_box(a+out*0.23,a+axis*0.2+out*0.23,(low+top)/2,top-low,0.22,trim)
	if profile.has("head"):
		build_head(facade,footprint,profile.head,top+0.24,trim,metal)

func build_head(facade, footprint: PackedVector2Array, profile: Dictionary, base: float, trim: Material, metal: Material) -> void:
	var center := Vector2.ZERO
	for p in footprint: center+=p
	center/=footprint.size()
	# Orient the visible fins along the registered north face toward the west.
	var axis := (footprint[1]-footprint[0]).normalized()
	var width := float(profile.panel_width)
	var height := float(profile.panel_height)
	facade.edge_box(center-axis*width/2,center+axis*width/2,base+height/2,height,float(profile.panel_depth),trim)
	for y in profile.fin_heights:
		facade.edge_box(center+axis*width/2,center+axis*(width/2+float(profile.fin_projection)),base+float(y),0.40,float(profile.panel_depth)+0.10,trim)
	var mast_at := center-axis*float(profile.mast_offset)
	var mast_height := float(profile.mast_height)
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=0.10
	mesh.top_radius=0.055
	mesh.height=mast_height
	mesh.radial_segments=12
	mesh.rings=1
	var node: MeshInstance3D = facade.builder.mesh_node(facade.group,mesh,metal,"LibraryTowerMast")
	node.position=Vector3(mast_at.x,base+mast_height/2,mast_at.y)
	node.set_meta("walk_collision",false)
	facade.edge_box(mast_at-axis*0.7,mast_at+axis*0.7,base+float(profile.crossbar_height),0.08,0.08,metal)
