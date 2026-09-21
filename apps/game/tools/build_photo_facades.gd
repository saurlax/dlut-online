extends RefCounted

# Only photo-visible exterior features. No invented rooms, doors or furniture.
# Source mapping and dimensional limits: references/eda/buildings/basis.md.
var builder
var group: Node3D

func uncovered_spans(first: float, last: float, exclusions: Array[Vector2]) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(first,last)]
	for gap in exclusions:
		var remaining: Array[Vector2] = []
		for span in spans:
			if gap.y <= span.x or gap.x >= span.y:
				remaining.append(span)
			else:
				if gap.x > span.x: remaining.append(Vector2(span.x,gap.x))
				if gap.y < span.y: remaining.append(Vector2(gap.y,span.y))
		spans = remaining
	return spans

func edge_box(a: Vector2, b: Vector2, y: float, height: float, depth: float, mat: Material, solid := false) -> void:
	var mid := (a+b)*0.5
	var node: MeshInstance3D = builder.box(group,Vector3(mid.x,y,mid.y),Vector3(a.distance_to(b),height,depth),mat,"PhotoFacade")
	node.rotation.y = -atan2((b-a).y,(b-a).x)
	node.set_meta("walk_collision",solid)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,mat,mid.x+mid.y,y)

func shell(points: PackedVector2Array, top: float, base: float, mat: Material, title: String) -> void:
	builder.polygon(group,points,top,mat,title,base)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var indexed := SurfaceTool.new()
	indexed.create_from(node.mesh,0)
	indexed.index()
	node.mesh = indexed.commit()
	node.set_meta("walk_collision",true)
	if title in ["Rotunda", "RotundaRoof", "LibraryMiteredRing"]:
		node.set_meta("facade_shell_polygon", points)

func build(host, parent: Node3D, points: PackedVector2Array, is_library: bool, registration: Dictionary = {}) -> void:
	builder = host
	var curve_first_child := parent.get_child_count()
	group = parent
	var profile_path := ProjectSettings.globalize_path("res://").path_join("../../references/eda/buildings/library_information_profiles.json").simplify_path()
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var profile: Dictionary = profiles["77917" if is_library else "77914"]
	if not registration.is_empty():
		profile.merge(registration,true)
		assert(points.size() == int(profile.expected_vertices),"Photo facade footprint/profile mismatch")
		group.set_meta("osm_id",profile.osm_id)
		group.set_meta("osm_version",profile.osm_version)
		group.set_meta("footprint_refinement",profile.footprint_refinement)
	# Photo proportions remain estimates; share the source with campus data.
	var storey: float = profile.storey
	var height: float = profile.height
	var floors := roundi(height/storey)
	group.set_meta("photo_reference","references/eda/buildings/library_information_profiles.json")
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
	var ground_openings: Dictionary = {}
	var rotunda_envelope = null
	if is_library and profile.has("rotunda_envelope"):
		rotunda_envelope = preload("res://tools/build_eda_library_rotunda.gd").new()
		rotunda_envelope.configure(points, profile.rotunda_envelope)
	if is_library:
		# Use the registered junction corners for each source geometry version.
		var rotunda := PackedVector2Array()
		for i in profile.get("rotunda_vertices",range(2,21)): rotunda.append(points[int(i)])
		var wing := PackedVector2Array()
		for i in profile.get("wing_vertices",[0,1,2,20,21,22,23]): wing.append(points[int(i)])
		var wing_height: float = profile.wing_height
		var shell_start := group.get_child_count()
		shell(rotunda,height,0,wall,"Rotunda")
		shell(rotunda,height+0.22,height,trim,"RotundaRoof")
		if rotunda_envelope != null: rotunda_envelope.deform_range(group, shell_start)
		if profile.has("lower_connector"):
			preload("res://tools/build_eda_library_connector.gd").new().build(self,points,profile.lower_connector,wing_height,wall,trim,glass,metal)
		else:
			shell(wing,wing_height,0,wall,"LibraryWing")
			shell(wing,wing_height+0.22,wing_height,trim,"LibraryWingRoof")
	else:
		if profile.has("corner_portico"):
			ground_openings = preload("res://tools/build_eda_information_portico.gd").new().build(self,points,profile.corner_portico,height,wall,trim)
		else:
			shell(points,height,0,wall,"Building")
		shell(points,height+0.22,height,trim,"Roof")
	var observed_edges := PackedInt32Array(profile.get("observed_edges",[1,2,6,8]))
	for edge in points.size():
		var edge_start := group.get_child_count()
		var a := points[edge]
		var b := points[(edge+1)%points.size()]
		var length := a.distance_to(b)
		var axis := (b-a).normalized()
		var outward := Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+outward,points):
			outward = -outward
		var windows: Dictionary = {}
		if is_library:
			for region: Dictionary in profile.get("wing_window_regions",[profile.wing_windows]):
				if edge==int(region.edge): windows=region
		if not windows.is_empty():
			var first := a.lerp(b,float(windows.span[0]))
			var last := a.lerp(b,float(windows.span[1]))
			var columns := int(windows.columns)
			var spacing := first.distance_to(last)/columns
			var width := spacing*float(windows.width_fraction)
			var window_height: float = windows.height
			if windows.has("east_round_columns"):
				preload("res://tools/build_eda_library_east_columns.gd").new().build(self,first,last,outward,windows)
			for y in windows.centers_y:
				for bay in columns:
					var center := first.lerp(last,(bay+0.5)/columns)+outward*0.12
					var left := center-axis*width/2
					var right := center+axis*width/2
					edge_box(left,right,float(y),window_height,0.08,glass)
					var mullions := int(windows.get("mullion_columns",3))
					for division in mullions+1:
						var upright := left.lerp(right,float(division)/mullions)+outward*0.07
						edge_box(upright-axis*0.035,upright+axis*0.035,float(y),window_height+0.1,0.12,metal)
					for fraction in windows.get("horizontal_frame_fractions",[0.0,0.75,1.0]):
						var frame_y := float(y)+window_height*(float(fraction)-0.5)
						edge_box(left+outward*0.07,right+outward*0.07,frame_y,0.065,0.12,metal)
				if windows.has("pale_spandrel_height"):
					var band_height := float(windows.pale_spandrel_height)
					edge_box(first+outward*0.16,last+outward*0.16,float(y)-window_height/2-band_height/2,band_height,0.16,trim)
					if windows.get("spandrel_panel_joints",false):
						for bay in columns:
							var center := first.lerp(last,(bay+0.5)/columns)
							for division in int(windows.mullion_columns)+1:
								var joint := center+axis*width*(float(division)/int(windows.mullion_columns)-0.5)+outward*0.245
								edge_box(joint-axis*0.008,joint+axis*0.008,float(y)-window_height/2-band_height/2,band_height,0.008,wall)
			continue
		# Photos show the library's curved curtain wall and information building's
		# long facade. Unverified faces keep the pre-existing footprint shell.
		var curved_glass := is_library and edge in PackedInt32Array(profile.get("curved_edges",range(2,20)))
		var observed: bool = curved_glass or (not is_library and edge in observed_edges)
		if not observed:
			continue
		var upper_windows: Dictionary = {}
		var entry: Dictionary = profile.get("south_entry",{}) if not is_library else {}
		if int(entry.get("edge",-1)) != edge: entry = {}
		var end_curtain: Dictionary = {}
		if not is_library:
			for region: Dictionary in profile.get("end_curtain_regions",[profile.get("end_curtain",{})]):
				if int(region.get("edge",-1)) == edge: end_curtain = region
		if not end_curtain.is_empty():
			var frame: StandardMaterial3D = builder.material("Information curtain aluminium",Color("899899"))
			frame.albedo_texture = null
			frame.metallic = 0.65
			frame.roughness = 0.38
			var first := a.lerp(b,float(end_curtain.span[0]))+outward*0.22
			var last := a.lerp(b,float(end_curtain.span[1]))+outward*0.22
			var curtain_height := float(end_curtain.height)
			var columns := int(end_curtain.columns)
			var rows := int(end_curtain.rows)
			for level in range(int(end_curtain.first_level),int(end_curtain.last_level)+1):
				var center_y := level*storey+2.2
				for column in columns:
					for row in rows:
						var pane_y := center_y-curtain_height/2+curtain_height*(row+0.5)/rows
						edge_box(first.lerp(last,float(column)/columns),first.lerp(last,float(column+1)/columns),pane_y,curtain_height/rows,0.08,glass)
				for column in columns+1:
					var pos := first.lerp(last,float(column)/columns)+outward*0.07
					edge_box(pos-axis*0.04,pos+axis*0.04,center_y,curtain_height+0.08,0.14,frame)
				for row in rows+1:
					var y := center_y-curtain_height/2+curtain_height*row/rows
					edge_box(first+outward*0.07,last+outward*0.07,y,0.08,0.14,frame)
		if not is_library:
			for region: Dictionary in profile.get("upper_window_regions",[]):
				if edge == int(region.edge): upper_windows = region
		for level in floors:
			var base := level*storey
			if level == floors-1 and not upper_windows.is_empty():
				var first := a.lerp(b,float(upper_windows.span[0]))
				var last := a.lerp(b,float(upper_windows.span[1]))
				var count := int(upper_windows.columns)
				var half_width := float(upper_windows.width)*0.5
				var window_height := float(upper_windows.height)
				var window_y := base+2.2
				for bay in count:
					var center := first.lerp(last,(bay+0.5)/count)+outward*0.22
					if upper_windows.has("pair_spacing"):
						center = first.lerp(last,(floori(bay/2.0)+0.5)/(count/2.0))+outward*0.22
						center += axis*(float(bay%2)-0.5)*float(upper_windows.pair_spacing)
					var left := center-axis*half_width
					var right := center+axis*half_width
					edge_box(left,right,window_y,window_height,0.08,glass)
					for end: Vector2 in [left,right]:
						edge_box(end-axis*0.035+outward*0.07,end+axis*0.035+outward*0.07,window_y,window_height+0.07,0.14,metal)
					for dy in [-window_height*0.5,-window_height*0.28,window_height*0.5]:
						edge_box(left+outward*0.07,right+outward*0.07,window_y+dy,0.065,0.14,metal)
				edge_box(a+outward*0.32,b+outward*0.32,base+0.12,0.38,0.65,trim)
				continue
			var bays := maxi(1,int(length/(1.65 if curved_glass else 3.2)))
			var window_height := 3.85 if curved_glass else 2.5
			var window_y := base+2.2
			var exclusions: Array[Vector2] = []
			if level==0:
				for region: Dictionary in profile.get("ground_window_exclusions",[]):
					if int(region.edge)==edge:
						exclusions.append(Vector2(region.span[0],region.span[1]))
			if not end_curtain.is_empty() and level >= int(end_curtain.first_level) and level <= int(end_curtain.last_level):
				exclusions.append(Vector2(maxf(0,float(end_curtain.span[0])-0.005),minf(1,float(end_curtain.span[1])+0.005)))
			if level==0 and ground_openings.has(edge): exclusions.append(ground_openings[edge])
			if not entry.is_empty() and window_y > float(entry.landing_height) and window_y < float(entry.glass_top):
				exclusions.append(Vector2(entry.span[0],entry.span[1]))
			for bay in bays:
				for span in uncovered_spans(float(bay)/bays,float(bay+1)/bays,exclusions):
					var left := a.lerp(b,span.x)+outward*0.22
					var right := a.lerp(b,span.y)+outward*0.22
					var mid := (left+right)*0.5
					var margin := 0.04 if curved_glass or level < floors-1 else 0.55
					if left.distance_to(right) <= 2*margin: continue
					var grid: Dictionary = profile.get("curtain_grid",{})
					if curved_glass and edge in PackedInt32Array(grid.get("edges",[])) and level >= int(grid.first_level):
						var columns := int(grid.columns_per_bay)
						var rows := int(grid.rows)
						var first := left+axis*margin
						var last := right-axis*margin
						for column in columns:
							for row in rows:
								var y := window_y-window_height/2+window_height*(row+0.5)/rows
								edge_box(first.lerp(last,float(column)/columns),first.lerp(last,float(column+1)/columns),y,window_height/rows,0.08,glass)
						for column in columns+1:
							var at := first.lerp(last,float(column)/columns)+outward*0.07
							edge_box(at-axis*0.025,at+axis*0.025,window_y,window_height,0.12,metal)
						for row in rows+1:
							var y := window_y-window_height/2+window_height*row/rows
							edge_box(first+outward*0.07,last+outward*0.07,y,0.05,0.12,metal)
						continue
					edge_box(left+axis*margin,right-axis*margin,window_y,window_height,0.08,glass)
					edge_box(mid-axis*0.035+outward*0.07,mid+axis*0.035+outward*0.07,window_y,window_height,0.14,metal)
					edge_box(left+axis*margin+outward*0.07,right-axis*margin+outward*0.07,window_y+0.6,0.065,0.14,metal)
					if not curved_glass and bay%3==0 and level < floors-1:
						edge_box(left+outward*0.10,left+axis*minf(0.48,left.distance_to(right))+outward*0.10,window_y,window_height+0.1,0.22,wall)
			var band_exclusions: Array[Vector2] = []
			if level==0 and ground_openings.has(edge): band_exclusions.append(ground_openings[edge])
			if not entry.is_empty() and base+0.12 > float(entry.landing_height)+0.3 and base+0.12 < float(entry.glass_top):
				band_exclusions.append(Vector2(entry.span[0],entry.span[1]))
			for span in uncovered_spans(0,1,band_exclusions):
				edge_box(a.lerp(b,span.x)+outward*0.32,a.lerp(b,span.y)+outward*0.32,base+0.12,0.22 if curved_glass else 0.38,0.65,trim)
		edge_box(a+outward*0.35,b+outward*0.35,height+0.12,0.24,1.0,trim,true)
		if curved_glass:
			# Raised perimeter ring and radial roof members visible in image 2.
			preload("res://tools/build_eda_library_ring.gd").new().build_segment(self,points,PackedInt32Array(profile.get("curved_edges",range(2,20))),edge,height+2.0,trim)
			if edge%2==0:
				var mid := (a+b)*0.5
				if edge not in PackedInt32Array(profile.get("roof_cross_members",{}).get("edges",[])):
					edge_box(mid-outward*0.6,mid+outward*1.3,height+1.9,0.16,0.18,trim,true)
				if rotunda_envelope == null or edge not in PackedInt32Array(profile.rotunda_envelope.get("replaced_fin_edges", [])):
					var column: MeshInstance3D = builder.box(group,Vector3(mid.x+outward.x*0.52,(height+2)*0.5,mid.y+outward.y*0.52),Vector3(0.38,height+2,0.38),trim,"PhotoFin")
					column.rotation.y = -atan2(axis.y,axis.x)
					column.set_meta("walk_collision",true)
		if curved_glass and rotunda_envelope != null:
			rotunda_envelope.deform_range(group, edge_start)
	if rotunda_envelope != null:
		var fins_start := group.get_child_count()
		rotunda_envelope.build_fins(self, height + 2.0, trim)
		rotunda_envelope.deform_range(group, fins_start)

	if is_library and profile.has("roof_cross_members"):
		var members_start := group.get_child_count()
		preload("res://tools/build_eda_library_ring.gd").new().build_cross_members(self,points,profile.roof_cross_members,height+1.9,trim)
		if rotunda_envelope != null: rotunda_envelope.deform_range(group, members_start)
	if is_library and profile.has("west_facade"):
		preload("res://tools/build_eda_library_west.gd").new().build(self,points,profile.west_facade)
	if is_library and profile.has("lettering"):
		preload("res://tools/build_eda_library_letters.gd").new().build(self,points,profile.lettering)
	if is_library and profile.has("tower"):
		preload("res://tools/build_eda_library_tower.gd").new().build(self,points,profile.tower,height,trim,glass,metal)

	if not is_library:
		if profile.has("south_entry"):
			preload("res://tools/build_eda_information_entry.gd").new().build(self,points,profile.south_entry)
		# Open roof frame visible on the long wing; its dimensions are estimates.
		var roof_frame: Dictionary = profile.roof_frame
		var a0: Vector2
		var a1: Vector2
		var b0: Vector2
		var b1: Vector2
		if roof_frame.has("edge"):
			var start := points[int(roof_frame.edge)]
			var finish := points[(int(roof_frame.edge)+1)%points.size()]
			var axis := (finish-start).normalized()
			var inward := Vector2(-axis.y,axis.x)
			if not Geometry2D.is_point_in_polygon((start+finish)/2.0+inward,points): inward = -inward
			a0 = start.lerp(finish,float(roof_frame.span[0]))+inward*float(roof_frame.depths[0])
			a1 = start.lerp(finish,float(roof_frame.span[1]))+inward*float(roof_frame.depths[0])
			b0 = start.lerp(finish,float(roof_frame.span[0]))+inward*float(roof_frame.depths[1])
			b1 = start.lerp(finish,float(roof_frame.span[1]))+inward*float(roof_frame.depths[1])
		else:
			a0 = Vector2(roof_frame.side_a[0][0],roof_frame.side_a[0][1])
			a1 = Vector2(roof_frame.side_a[1][0],roof_frame.side_a[1][1])
			b0 = Vector2(roof_frame.side_b[0][0],roof_frame.side_b[0][1])
			b1 = Vector2(roof_frame.side_b[1][0],roof_frame.side_b[1][1])
		for point in [a0,a1,b0,b1]:
			assert(Geometry2D.is_point_in_polygon(point,points),"Information roof frame outside footprint")
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

	if is_library and profile.has("curve_refinement"):
		var curve := preload("res://tools/eda_ellipse_envelope.gd").new()
		curve.configure(points,profile.curve_refinement,rotunda_envelope)
		builder.surface_deformations.append({"curve":curve,"group":group,"first_child":curve_first_child})
