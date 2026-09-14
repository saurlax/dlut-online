extends RefCounted

# Only photo-visible exterior features. No invented rooms, doors or furniture.
# Source mapping and dimensional limits: references/photos/README.md.
var builder
var group: Node3D

func edge_box(a: Vector2, b: Vector2, y: float, height: float, depth: float, mat: Material, solid := false) -> void:
	var mid := (a+b)*0.5
	var node: MeshInstance3D = builder.box(group,Vector3(mid.x,y,mid.y),Vector3(a.distance_to(b),height,depth),mat,"PhotoFacade")
	node.rotation.y = -atan2((b-a).y,(b-a).x)
	node.set_meta("walk_collision",solid)

func shell(points: PackedVector2Array, top: float, base: float, mat: Material, title: String) -> void:
	builder.polygon(group,points,top,mat,title,base)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var indexed := SurfaceTool.new()
	indexed.create_from(node.mesh,0)
	indexed.index()
	node.mesh = indexed.commit()
	node.set_meta("walk_collision",true)

func build(host, parent: Node3D, points: PackedVector2Array, is_library: bool) -> void:
	builder = host
	group = parent
	var profile_path := ProjectSettings.globalize_path("res://").path_join("../../references/photos/library_information_profiles.json").simplify_path()
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var profile: Dictionary = profiles["77917" if is_library else "77914"]
	# Photo proportions remain estimates; share the source with campus data.
	var storey: float = profile.storey
	var height: float = profile.height
	var floors := roundi(height/storey)
	group.set_meta("photo_reference","references/photos/library_information_profiles.json")
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
	if is_library:
		# Official outline divides at the two corners where the wing meets the rotunda.
		var rotunda := PackedVector2Array()
		for i in range(2,21): rotunda.append(points[i])
		var wing := PackedVector2Array()
		for i in [0,1,2,20,21,22,23]: wing.append(points[i])
		var wing_height: float = profile.wing_height
		shell(rotunda,height,0,wall,"Rotunda")
		shell(rotunda,height+0.22,height,trim,"RotundaRoof")
		shell(wing,wing_height,0,wall,"LibraryWing")
		shell(wing,wing_height+0.22,wing_height,trim,"LibraryWingRoof")
	else:
		shell(points,height,0,wall,"Building")
		shell(points,height+0.22,height,trim,"Roof")
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
		var curved_glass := is_library and edge >= 2 and edge <= 19
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
		edge_box(a+outward*0.35,b+outward*0.35,height+0.12,0.24,1.0,trim,true)
		if curved_glass:
			# Raised perimeter ring and radial roof members visible in image 2.
			edge_box(a+outward*1.3,b+outward*1.3,height+2.0,0.28,0.5,trim,true)
			if edge%2==0:
				var mid := (a+b)*0.5
				edge_box(mid-outward*0.6,mid+outward*1.3,height+1.9,0.16,0.18,trim,true)
				var column: MeshInstance3D = builder.box(group,Vector3(mid.x+outward.x*0.52,(height+2)*0.5,mid.y+outward.y*0.52),Vector3(0.38,height+2,0.38),trim,"PhotoFin")
				column.rotation.y = -atan2(axis.y,axis.x)
				column.set_meta("walk_collision",true)

	if not is_library:
		# Open roof frame visible on the long wing; its dimensions are estimates.
		var roof_frame: Dictionary = profile.roof_frame
		var a0 := Vector2(roof_frame.side_a[0][0],roof_frame.side_a[0][1])
		var a1 := Vector2(roof_frame.side_a[1][0],roof_frame.side_a[1][1])
		var b0 := Vector2(roof_frame.side_b[0][0],roof_frame.side_b[0][1])
		var b1 := Vector2(roof_frame.side_b[1][0],roof_frame.side_b[1][1])
		var beam_y: float = roof_frame.beam_center
		var base_y: float = roof_frame.base
		edge_box(a0,a1,beam_y,0.4,0.45,trim,true)
		edge_box(b0,b1,beam_y,0.4,0.45,trim,true)
		var bays := int(roof_frame.bays)
		for i in bays+1:
			var a := a0.lerp(a1,float(i)/bays)
			var b := b0.lerp(b1,float(i)/bays)
			edge_box(a,b,beam_y,0.4,0.45,trim,true)
			for side in 2:
				var pos := a if side==0 else b
				var column: MeshInstance3D
				if side==0:
					var mesh := CylinderMesh.new()
					mesh.top_radius = float(roof_frame.visible_column_diameter)/2
					mesh.bottom_radius = mesh.top_radius
					mesh.height = beam_y-base_y
					mesh.radial_segments = 16
					mesh.rings = 1
					column = MeshInstance3D.new()
					column.name = "InformationRoofRoundColumn"
					column.mesh = mesh
					column.material_override = trim
					column.position = Vector3(pos.x,(base_y+beam_y)/2,pos.y)
					group.add_child(column)
				else:
					column = builder.box(group,Vector3(pos.x,(base_y+beam_y)/2,pos.y),Vector3(0.5,beam_y-base_y,0.5),trim,"InformationRoofColumn")
				column.set_meta("walk_collision",true)
