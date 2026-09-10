extends RefCounted

# Only photo-visible exterior features. No invented rooms, doors or furniture.
# Source mapping and dimensional limits: references/photos/README.md.
var builder
var group: Node3D

func edge_box(a: Vector2, b: Vector2, y: float, height: float, depth: float, mat: Material) -> void:
	var mid := (a+b)*0.5
	var node: MeshInstance3D = builder.box(group,Vector3(mid.x,y,mid.y),Vector3(a.distance_to(b),height,depth),mat,"PhotoFacade")
	node.rotation.y = -atan2((b-a).y,(b-a).x)

func build(host, parent: Node3D, points: PackedVector2Array, is_library: bool) -> void:
	builder = host
	group = parent
	var floors := 5 if is_library else 4
	# Photo-derived storey count; metre scale remains an estimate, not survey data.
	var storey := 4.4
	var height := floors*storey
	group.set_meta("photo_reference","references/photos/77917.json" if is_library else "references/photos/77914.json")
	group.set_meta("interior_available",false)
	group.set_meta("height_is_approximate",true)
	var wall: StandardMaterial3D = builder.material("Library masonry" if is_library else "Information taupe masonry",Color("898679") if is_library else Color("817c72"))
	wall.uv1_scale = Vector3.ONE*0.07
	var trim: StandardMaterial3D = builder.material("Photo pale bands",Color("c2c0b2"))
	trim.albedo_texture = null
	var metal: StandardMaterial3D = builder.material("Photo aluminium",Color("333c3d"))
	metal.albedo_texture = null
	metal.metallic = 0.55
	metal.roughness = 0.34
	var glass: StandardMaterial3D = builder.material("Photo glazing",Color("4e6264"))
	glass.albedo_texture = null
	glass.metallic = 0.55
	glass.roughness = 0.2
	builder.polygon(group,points,height,wall,"Building")
	group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
	builder.polygon(group,points,height+0.22,trim,"Roof",height)
	group.get_child(group.get_child_count()-1).set_meta("walk_collision",true)
	for edge in points.size():
		var a := points[edge]
		var b := points[(edge+1)%points.size()]
		var length := a.distance_to(b)
		var axis := (b-a).normalized()
		var outward := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+outward,points):
			outward = -outward
		# Photos show the library's curved curtain wall and information building's
		# long facade. Unverified faces keep the pre-existing footprint shell.
		var curved_glass := is_library and edge >= 3 and edge <= 20
		var observed := curved_glass or (not is_library and edge in [1,2,6,8])
		if not observed:
			continue
		for level in floors:
			var base := level*storey
			var bays := maxi(1,int(length/(1.65 if curved_glass else 3.2)))
			var window_height := 3.85 if curved_glass else 2.5
			var window_y := base+2.2
			for bay in bays:
				var left := a.lerp(b,float(bay)/bays)+outward*0.22
				var right := a.lerp(b,float(bay+1)/bays)+outward*0.22
				var mid := (left+right)*0.5
				# The upper information-building row is separate punched windows.
				var margin := 0.04 if curved_glass or level < floors-1 else 0.55
				edge_box(left+axis*margin,right-axis*margin,window_y,window_height,0.08,glass)
				edge_box(mid-axis*0.035+outward*0.07,mid+axis*0.035+outward*0.07,window_y,window_height,0.14,metal)
				edge_box(left+axis*margin+outward*0.07,right-axis*margin+outward*0.07,window_y+0.6,0.065,0.14,metal)
				if not curved_glass and bay%3==0 and level < floors-1:
					edge_box(left+outward*0.10,left+axis*0.48+outward*0.10,window_y,window_height+0.1,0.22,wall)
			edge_box(a+outward*0.32,b+outward*0.32,base+0.12,0.22 if curved_glass else 0.38,0.65,trim)
		edge_box(a+outward*0.35,b+outward*0.35,height+0.12,0.24,1.0,trim)
		if curved_glass:
			# Raised perimeter ring and radial roof members visible in image 2.
			edge_box(a+outward*1.3,b+outward*1.3,height+2.0,0.28,0.5,trim)
			if edge%2==0:
				var mid := (a+b)*0.5
				edge_box(mid-outward*0.6,mid+outward*1.3,height+1.9,0.16,0.18,trim)
				var column: MeshInstance3D = builder.box(group,Vector3(mid.x+outward.x*0.52,(height+2)*0.5,mid.y+outward.y*0.52),Vector3(0.38,height+2,0.38),trim,"PhotoFin")
				column.rotation.y = -atan2(axis.y,axis.x)
