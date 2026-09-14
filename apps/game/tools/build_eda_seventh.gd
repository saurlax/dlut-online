extends RefCounted

# Official overall height; internal plan and podium height remain photo estimates.
func shell(builder, group: Node3D, points: PackedVector2Array, top: float, base: float, mat: Material, name: String) -> void:
	builder.polygon(group,points,top,mat,name,base)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var st := SurfaceTool.new()
	st.create_from(node.mesh,0)
	st.index()
	node.mesh = st.commit()
	node.set_meta("walk_collision",true)

func panel(builder, group: Node3D, pos: Vector2, y: float, size: Vector3, angle: float, mat: Material) -> void:
	var node: MeshInstance3D = builder.box(group,Vector3(pos.x,y,pos.y),size,mat,"SeventhFacade")
	node.rotation.y = angle

func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	group.set_meta("photo_reference","references/photos/seventh-residence/profile.json")
	group.set_meta("height_source",profile.height_source)
	group.set_meta("interior_available",false)
	var white: Material = builder.material("Seventh white cladding",Color("d0d1cd"))
	var trim: Material = builder.material("Seventh cladding joints",Color("929b9c"))
	var glazing: Material = builder.material("Seventh opaque glazing",Color("41525c"))
	for mat in [white,trim,glazing]: mat.albedo_texture = null
	glazing.metallic = 0.35
	glazing.roughness = 0.3
	var podium: float = profile.podium_height
	var height: float = profile.height
	shell(builder,group,points,podium,0.0,white,"Podium")
	var raised: Dictionary = profile.raised_podium
	var raised_points := PackedVector2Array()
	for p in raised.points: raised_points.append(Vector2(p[0],p[1]))
	shell(builder,group,raised_points,float(raised.height),podium,white,"RaisedPodium")
	# Only the two outer roof edges visible in the construction aerial.
	var parapet: Dictionary = raised.parapet
	for edge in parapet.edges:
		var a := raised_points[int(edge)]
		var b := raised_points[(int(edge)+1)%raised_points.size()]
		var axis := (b-a).normalized()
		var inward := Vector2(-axis.y,axis.x)
		if not Geometry2D.is_point_in_polygon((a+b)*0.5+inward,raised_points): inward = -inward
		var thickness: float = parapet.thickness
		var wall_height: float = parapet.height
		var pos := (a+b)*0.5+inward*thickness*0.5
		var node: MeshInstance3D = builder.box(group,Vector3(pos.x,float(raised.height)+wall_height*0.5,pos.y),Vector3(a.distance_to(b),wall_height,thickness),white,"RaisedPodiumParapet")
		node.rotation.y = -atan2(axis.y,axis.x)
		node.set_meta("walk_collision",true)
	var tower := PackedVector2Array()
	for p in profile.tower_points: tower.append(Vector2(p[0],p[1]))
	var roof: Dictionary = profile.roof_parapet
	var roof_y := height-float(roof.height)
	shell(builder,group,tower,roof_y,podium,white,"Tower")
	# The aerial shows a lower roof inside the perimeter wall, not a solid top.
	var inset_polygons := Geometry2D.offset_polygon(tower,-float(roof.thickness),Geometry2D.JOIN_MITER)
	assert(inset_polygons.size()==1,"Seventh roof inset must remain one connected roof")
	var inset: PackedVector2Array = inset_polygons[0]
	assert(inset.size()==tower.size(),"Seventh roof inset must preserve the L-shaped corners")
	var inner := PackedVector2Array()
	for corner in tower:
		var closest := inset[0]
		for candidate in inset:
			if candidate.distance_squared_to(corner)<closest.distance_squared_to(corner): closest = candidate
		inner.append(closest)
	for edge in tower.size():
		var next := (edge+1)%tower.size()
		var strip := PackedVector2Array([tower[edge],tower[next],inner[next],inner[edge]])
		shell(builder,group,strip,height,roof_y,white,"TowerRoofParapet")
	# Do not invent rooftop equipment or rooms.
	# Construction photographs show two courtyard wings, not the unseen rear faces.
	for edge in [4,5]:
		var a := tower[edge]
		var b := tower[(edge+1)%tower.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+out,tower): out = -out
		var angle := -atan2(axis.y,axis.x)
		var length := a.distance_to(b)
		var columns := 9 if edge == 4 else 12
		var spacing := length/columns
		var storey := (height-podium-1.5)/13.0
		for row in 13:
			var y := podium+storey*(row+0.5)
			for col in columns:
				var pos := a.lerp(b,(col+0.5)/columns)
				var width := spacing*0.68
				var window_height := storey*0.65
				panel(builder,group,pos+out*0.08,y,Vector3(width,window_height,0.1),angle,glazing)
				for dx in [-width/2.0,0.0,width/2.0]:
					panel(builder,group,pos+axis*dx+out*0.15,y,Vector3(0.065,window_height+0.1,0.12),angle,trim)
				for dy in [-window_height/2.0,window_height*0.22,window_height/2.0]:
					panel(builder,group,pos+out*0.15,y+dy,Vector3(width+0.1,0.06,0.12),angle,trim)
			# Paired dark spandrels read as the vertical strips visible during construction.
			if row%2 == 0 and row<12:
				for col in columns:
					var pos := a.lerp(b,(col+0.5)/columns)+out*0.065
					panel(builder,group,pos,y+storey/2.0,Vector3(spacing*0.68,storey*0.35,0.08),angle,trim)
	var end_profile: Dictionary = profile.end_windows
	var end_edge := int(end_profile.edge)
	var end_a := tower[end_edge]
	var end_b := tower[(end_edge+1)%tower.size()]
	var end_axis := (end_b-end_a).normalized()
	var end_out := Vector2(end_axis.y,-end_axis.x)
	if Geometry2D.is_point_in_polygon((end_a+end_b)/2+end_out,tower): end_out = -end_out
	var end_angle := -atan2(end_axis.y,end_axis.x)
	var end_storey := (height-podium-1.5)/13.0
	for row in 13:
		var y := podium+end_storey*(row+0.5)
		for fraction in end_profile.fractions:
			var pos := end_a.lerp(end_b,float(fraction))
			var width: float = end_profile.width
			var window_height: float = end_profile.window_height
			panel(builder,group,pos+end_out*0.08,y,Vector3(width,window_height,0.1),end_angle,glazing)
			for dx in [-width/2,width/2]:
				panel(builder,group,pos+end_axis*dx+end_out*0.15,y,Vector3(0.06,window_height+0.1,0.12),end_angle,trim)
			for dy in [-window_height/2,window_height/2]:
				panel(builder,group,pos+end_out*0.15,y+dy,Vector3(width+0.1,0.06,0.12),end_angle,trim)
