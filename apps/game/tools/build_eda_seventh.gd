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
	var tower := PackedVector2Array()
	for p in profile.tower_points: tower.append(Vector2(p[0],p[1]))
	shell(builder,group,tower,height,podium,white,"Tower")
	# The completed roof remains level; do not invent rooftop equipment or rooms.
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
