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
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,mat,pos.x+pos.y,y)

func courtyard_louver(builder, group: Node3D, pos: Vector2, outward: Vector2, y: float, width: float, height: float, angle: float) -> void:
	var backing: Material = builder.material("Seventh courtyard louver backing",Color("30393d"))
	var blades: Material = builder.material("Seventh courtyard louver blades",Color("596365"))
	for material in [backing,blades]:
		material.albedo_texture=null
		material.metallic=0.45
		material.roughness=0.55
	var center := pos+outward*0.235
	var node: MeshInstance3D = builder.box(group,Vector3(center.x,y,center.y),Vector3(width,height,0.04),backing,"SeventhCourtyardLouver")
	node.rotation.y=angle
	node.set_meta("walk_collision",false)
	var count := ceili(height/0.16)
	for blade in range(count+1):
		center=pos+outward*0.28
		node=builder.box(group,Vector3(center.x,y-height/2+height*blade/count,center.y),Vector3(width,0.022,0.045),blades,"SeventhCourtyardLouverBlade")
		node.rotation.y=angle
		node.set_meta("walk_collision",false)

func build(builder, group: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	group.set_meta("photo_reference","references/eda/buildings/seventh-residence/profile.json")
	group.set_meta("height_source",profile.height_source)
	group.set_meta("interior_available",false)
	var white: Material = builder.material("Seventh white cladding",Color("d0d1cd"))
	var trim: Material = builder.material("Seventh cladding joints",Color("929b9c"))
	var glazing: Material = builder.material("Seventh opaque glazing",Color("41525c"))
	var spandrel: Material = builder.material("Seventh lavender spandrels",Color("8d889b"))
	for mat in [white,trim,glazing,spandrel]: mat.albedo_texture = null
	glazing.metallic = 0.35
	glazing.roughness = 0.3
	var podium: float = profile.podium_height
	var height: float = profile.height
	var tower_storeys := int(profile.storeys)-1
	shell(builder,group,points,podium,0.0,white,"Podium")
	if profile.has("low_podium_parapet"):
		preload("res://tools/build_eda_seventh_podium.gd").new().build(builder,group,points,profile.low_podium_parapet,podium)
	var raised: Dictionary = profile.raised_podium
	var raised_points := PackedVector2Array()
	for p in raised.points: raised_points.append(Vector2(p[0],p[1]))
	if profile.has("raised_registration"):
		var spec: Dictionary = profile.raised_registration
		var start: Array = profile.tower_points[int(spec.start_vertex)]
		var finish: Array = profile.tower_points[int(spec.end_vertex)]
		var a := Vector2(start[0],start[1])
		var b := Vector2(finish[0],finish[1])
		var axis := (b-a).normalized()
		var courtyard := Vector2(-axis.y,axis.x)
		a += axis*float(spec.start_inset)
		b -= axis*float(spec.end_inset)
		raised_points = PackedVector2Array([a,b,b+courtyard*float(spec.width),a+courtyard*float(spec.width)])
		for point in raised_points:
			assert(Geometry2D.is_point_in_polygon(point,points),"Raised podium left the registered compound")
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
	var shell_tower := preload("res://tools/seventh_corner_profile.gd").rounded(tower)
	var roof: Dictionary = profile.roof_parapet
	var roof_y := height-float(roof.height)
	shell(builder,group,shell_tower,roof_y,podium,white,"Tower")
	# The aerial shows a lower roof inside the perimeter wall, not a solid top.
	var inset_polygons := Geometry2D.offset_polygon(shell_tower,-float(roof.thickness),Geometry2D.JOIN_MITER)
	assert(inset_polygons.size()==1,"Seventh roof inset must remain one connected roof")
	var inset: PackedVector2Array = inset_polygons[0]
	assert(inset.size()==shell_tower.size(),"Seventh roof inset must preserve straight and rounded corners")
	var inner := PackedVector2Array()
	for corner in shell_tower:
		var closest := inset[0]
		for candidate in inset:
			if candidate.distance_squared_to(corner)<closest.distance_squared_to(corner): closest = candidate
		inner.append(closest)
	for edge in shell_tower.size():
		var next := (edge+1)%shell_tower.size()
		var strip := PackedVector2Array([shell_tower[edge],shell_tower[next],inner[next],inner[edge]])
		shell(builder,group,strip,height,roof_y,white,"TowerRoofParapet")
	# Do not invent rooftop equipment or rooms.
	# Construction photographs show two courtyard wings, not the unseen rear faces.
	for face in profile.get("courtyard_faces",[{"edge":4,"columns":9},{"edge":5,"columns":12}]):
		var edge := int(face.edge)
		var a := tower[edge]
		var b := tower[(edge+1)%tower.size()]
		var axis := (b-a).normalized()
		var out := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+out,tower): out = -out
		var angle := -atan2(axis.y,axis.x)
		var length := a.distance_to(b)
		var columns := int(face.columns)
		var spacing := length/columns
		var storey := (height-podium-1.5)/tower_storeys
		for row in tower_storeys:
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
			# Muted lavender infills join each pair of floors into one window band.
			if row%2 == 0 and row<tower_storeys-1:
				for col in columns:
					var pos := a.lerp(b,(col+0.5)/columns)+out*0.065
					panel(builder,group,pos,y+storey/2.0,Vector3(spacing*0.68,storey*0.35,0.08),angle,spandrel)
		# Edge 7 starts at the exposed north end and runs toward the courtyard corner.
		# Only its first four clearly visible bays have registered central louvers.
		if edge==7:
			for col in range(mini(columns,4)):
				var pos := a.lerp(b,(col+0.5)/columns)
				for pair in 7:
					courtyard_louver(builder,group,pos,out,podium+storey*(pair*2+1),spacing*0.68*0.36,storey*1.65,angle)
	if profile.has("south_visible_faces"):
		preload("res://tools/build_eda_seventh_south.gd").new().build(builder,group,tower,profile.south_visible_faces,podium,height,tower_storeys,glazing,spandrel,trim)
	if profile.has("west_end_facade"):
		preload("res://tools/build_eda_seventh_end.gd").new().build(builder,group,tower,profile.west_end_facade,podium,height,glazing,spandrel,trim)
	var end_profile: Dictionary = profile.end_windows
	var end_edge := int(end_profile.edge)
	var end_a := tower[end_edge]
	var end_b := tower[(end_edge+1)%tower.size()]
	var end_axis := (end_b-end_a).normalized()
	var end_out := Vector2(end_axis.y,-end_axis.x)
	if Geometry2D.is_point_in_polygon((end_a+end_b)/2+end_out,tower): end_out = -end_out
	var end_angle := -atan2(end_axis.y,end_axis.x)
	var end_storey := (height-podium-1.5)/tower_storeys
	for row in tower_storeys:
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
