extends RefCounted

var host
var group: Node3D
var origin: Vector2
var axis: Vector2
var out: Vector2
var length: float
var arcade
var south_end
var atrium
var atrium_settings: Dictionary = {}
var atrium_openings: Dictionary = {}
var access

func body(points: PackedVector2Array, top: float, base: float, material: Material) -> void:
	if access != null:
		access.body(self,points,top,base,material)
	elif atrium != null:
		shell(points,top,base,material,atrium_openings.body)
	elif south_end != null:
		south_end.body(self,points,top,base,material)
	elif arcade != null:
		arcade.body(self,points,top,base,material)
	else:
		shell(points,top,base,material)

func frame_for(points: PackedVector2Array, edge: int, end_vertex := -1) -> void:
	origin = points[edge]
	var end := points[(edge+1)%points.size() if end_vertex < 0 else end_vertex]
	axis = (end-origin).normalized()
	length = origin.distance_to(end)
	out = Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+end)/2.0+out,points): out = -out

func panel(x: float, y: float, width: float, height: float, depth: float, offset: float, mat: Material, solid := false) -> void:
	var p := origin+axis*x+out*offset
	var node: MeshInstance3D = host.box(group,Vector3(p.x,y,p.y),Vector3(width,height,depth),mat,"AcademicDetail")
	if mat.resource_name.begins_with("Surface square_ceramic "):
		preload("res://tools/build_surface_materials.gd").new().map_box(node,Vector2(x,y))
	node.rotation.y = -atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,mat,x,y)

func shell(points: PackedVector2Array, top: float, base: float, mat: Material, openings: Array = []) -> void:
	var holes: Array = []
	for opening: PackedVector2Array in openings:
		var coordinates: Array = []
		for point: Vector2 in opening: coordinates.append([point.x,point.y])
		holes.append(coordinates)
	host.polygon(group,points,top,mat,"AcademicShell",base,holes)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	var surface := SurfaceTool.new()
	surface.create_from(node.mesh,0)
	surface.index()
	node.mesh = surface.commit()
	node.set_meta("walk_collision",true)

func map_tower_masonry(node: MeshInstance3D, side: bool, height_center: float) -> void:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var uv := PackedVector2Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		uv.append(Vector2(vertex.z if side else vertex.x,-vertex.y-height_center))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mapped := ArrayMesh.new()
	mapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh = mapped

func build(builder, parent: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	host = builder
	var curve_first_child := parent.get_child_count()
	group = parent
	group.set_meta("photo_reference","references/eda/buildings/academic_facades.json")
	group.set_meta("interior_available",false)
	var wall: Material = host.material("EDA academic "+str(profile.color),Color(profile.color))
	var stone: Material = host.material("EDA academic pale bands",Color("b6b7a7"))
	var glass: Material = host.material("EDA academic opaque glazing",Color("42575a"))
	var metal: Material = host.material("EDA academic window metal",Color("454a48"))
	for mat in [wall,stone,glass,metal]: mat.albedo_texture = null
	glass.metallic = 0.35
	glass.roughness = 0.3
	var height: float = profile.height
	atrium = null
	atrium_settings = profile.get("atria",{})
	atrium_openings = {}
	access = null
	if not atrium_settings.is_empty():
		atrium = preload("res://tools/build_eda_a_atrium.gd").new()
		atrium_openings = atrium.cutouts(atrium_settings)
		if profile.get("entry",{}).get("open_entry",false):
			access = preload("res://tools/build_eda_a_access.gd").new()
			access.configure(points,profile.entry,atrium_openings)
			atrium_settings.entry_lining_cuts = access.lining_cuts
	south_end=null
	if profile.has("south_end"):
		south_end=preload("res://tools/build_eda_b_south_end.gd").new()
		south_end.configure(points,profile.south_end)
	arcade=null
	if profile.has("rotunda"):
		arcade=preload("res://tools/build_eda_academic_arcade.gd").new()
		arcade.configure(points)
	var recess: Dictionary = profile.get("recess",{})
	if recess.is_empty():
		body(points,height,0,wall)
	else:
		frame_for(points,int(recess.edge))
		var recessed := PackedVector2Array()
		for i in points.size():
			recessed.append(points[i])
			if i==int(recess.edge):
				var a := origin+axis*length*float(recess.span[0])
				var b := origin+axis*length*float(recess.span[1])
				recessed.append(a)
				recessed.append(a-out*float(recess.depth))
				recessed.append(b-out*float(recess.depth))
				recessed.append(b)
		body(points,float(recess.bottom),0,wall)
		body(recessed,float(recess.top),float(recess.bottom),wall)
		body(points,height,float(recess.top),wall)
	if arcade != null: arcade.finishes(self,stone)
	shell(points,height+0.18,height,stone,atrium_openings.get("roof",[]))
	if atrium != null:
		atrium.build(host,group,atrium_settings)
	if access != null:
		access.finishes(self)
	for face in profile.faces:
		frame_for(points,int(face.edge))
		var start: float = face.span[0]*length
		var finish: float = face.span[1]*length
		var spacing: float = (finish-start)/int(face.columns)
		var width: float = spacing*float(face.width_ratio)
		var wh: float = face.window_height
		for row in int(face.rows):
			var y: float = face.first_y+row*face.storey
			for col in int(face.columns):
				var x := start+(col+0.5)*spacing
				if profile.has("tower") and absf(x-float(profile.tower.fraction)*length)<float(profile.tower.width)*0.6: continue
				if row==0 and profile.has("entry") and int(face.edge)==int(profile.entry.edge):
					var entry: Dictionary = profile.entry
					if absf(x-float(entry.fraction)*length)<float(entry.bay_pitch)+float(entry.bay_width)/2+width/2: continue
				var inset := 0.0
				if not recess.is_empty() and int(face.edge)==int(recess.edge) and y>float(recess.bottom) and y<float(recess.top) and x>length*float(recess.span[0]) and x<length*float(recess.span[1]):
					inset = float(recess.depth)
				panel(x,y,width,wh,0.08,0.08-inset,glass)
				for dx in [-width/2.0-0.045,width/2.0+0.045]:
					panel(x+dx,y,0.09,wh+0.16,0.26,0.13-inset,stone)
				for dx in [-width/2.0,width/2.0]: panel(x+dx,y,0.06,wh+0.1,0.12,0.16-inset,metal)
				if row>0 and profile.get("upper_window_layout","")=="three_lower_two_upper":
					for dx in [-width*0.25,width*0.25]:
						panel(x+dx,y-wh*0.125,0.06,wh*0.75,0.12,0.16-inset,metal)
					panel(x,y+wh*0.375,0.06,wh*0.25,0.12,0.16-inset,metal)
				else:
					panel(x,y,0.06,wh+0.1,0.12,0.16-inset,metal)
				for dy in [-wh/2.0,wh*0.25,wh/2.0]: panel(x,y+dy,width+0.12,0.065,0.14,0.16-inset,metal)
				panel(x,y-wh/2.0-0.1,width+0.22,0.16,0.24,0.17-inset,stone)
			var band_y := y-wh/2.0-0.45
			if not recess.is_empty() and int(face.edge)==int(recess.edge) and band_y>float(recess.bottom) and band_y<float(recess.top):
				var cut_a: float = length*float(recess.span[0])
				var cut_b: float = length*float(recess.span[1])
				for part in [[start,minf(finish,cut_a),0.0],[maxf(start,cut_a),minf(finish,cut_b),-float(recess.depth)],[maxf(start,cut_b),finish,0.0]]:
					if float(part[1])>float(part[0]): panel((float(part[0])+float(part[1]))/2,band_y,float(part[1])-float(part[0]),0.18,0.16,0.12+float(part[2]),stone)
			else:
				panel((start+finish)/2.0,band_y,finish-start,0.18,0.16,0.12,stone)
		panel((start+finish)/2.0,height+0.09,finish-start,0.18,0.8,0.25,stone,true)
	if south_end != null: south_end.finishes(self,stone,glass,metal)
	if profile.has("courtyard_entry"):
		preload("res://tools/build_eda_b_courtyard_entry.gd").new().build(self,points,profile.courtyard_entry)
	if profile.has("entry"):
		preload("res://tools/build_eda_academic_entry.gd").new().build(self,points,profile.entry,glass,metal,stone)
	if profile.has("tower"):
		var tower: Dictionary = profile.tower
		frame_for(points,int(tower.edge))
		var x: float = tower.fraction*length
		var top: float = tower.height
		var width: float = tower.width
		var body_top: float = tower.get("body_height",top)
		panel(x,body_top/2.0,width,body_top,2.0,0.0,wall,true)
		var glazing_top: float = tower.get("glazing_top",body_top-0.5)
		panel(x,(glazing_top+0.5)/2.0,width-0.6,glazing_top-0.5,0.1,1.06,glass)
		for dx in [-width/2.0,width/2.0]: panel(x+dx,body_top/2.0,0.18,body_top+0.6,0.25,1.16,stone)
		var glazing_width: float = width-0.6
		var glazing_columns: int = int(tower.get("glazing_columns",4))
		for column in range(glazing_columns+1):
			var dx: float = -glazing_width/2.0+glazing_width*column/glazing_columns
			panel(x+dx,(glazing_top+0.5)/2.0,0.065,glazing_top-0.5,0.12,1.16,metal)
		for i in range(1,15): panel(x,float(i)*glazing_top/15.0,width,0.09,0.18,1.2,metal)
		panel(x,body_top+0.1,width+0.4,0.2,2.3,0.0,stone,true)
		if tower.has("body_height"):
			var fin_tops: Array = tower.get("head_fin_tops",[top+0.3,top+0.3])
			var head_masonry := ShaderMaterial.new()
			head_masonry.resource_name = "EDA academic tower head masonry"
			var head_shader: Shader = preload("res://assets/campuses/eda/materials/academic_tile.gdshader").duplicate()
			# Local single-sided variant leaves the existing facade shader unchanged.
			head_shader.code = head_shader.code.replace("cull_disabled","cull_back")
			head_masonry.shader = head_shader
			head_masonry.set_shader_parameter("tile_color",Color("65665e"))
			head_masonry.set_shader_parameter("pale_color",Color("777970"))
			for side in 2:
				var dx: float = width*(side-0.5)
				var fin_top: float = fin_tops[side]
				panel(x+dx,(body_top+fin_top)/2,0.2,fin_top-body_top,2.3,0.0,stone,true)
				# Only the two visible west-facing faces receive inset masonry.
				if tower.get("visible_head_masonry",false):
					panel(x+dx+0.106,(body_top+fin_top)/2,0.012,fin_top-body_top-0.24,2.06,0.0,head_masonry)
					map_tower_masonry(group.get_child(group.get_child_count()-1),true,(body_top+fin_top)/2)
			if tower.get("visible_head_masonry",false):
				panel(x,(glazing_top+body_top)/2,width-0.6,body_top-glazing_top,0.012,1.006,head_masonry)
				map_tower_masonry(group.get_child(group.get_child_count()-1),false,(glazing_top+body_top)/2)
			if tower.has("head_aperture"):
				preload("res://tools/build_eda_academic_tower_head.gd").new().build(self,x,tower,stone)
			else:
				panel(x,float(tower.head_beam_y),width,0.2,2.3,0.0,stone,true)
		if tower.has("head_rods"): build_tower_rods(x,tower,metal)
	if profile.has("rotunda"):
		var rotunda: Dictionary = profile.rotunda
		preload("res://tools/build_eda_academic_ring.gd").new().build(self,points,rotunda,stone)
		for edge in rotunda.edges:
			frame_for(points,int(edge))
			# A dark upper recess, kept closed without claiming usable space.
			panel(length/2,23.65,length,0.9,0.08,0.07,glass)
			if int(edge)%2==0:
				panel(length/2,23.65,0.3,1.2,0.4,0.22,stone,true)
		for edge in rotunda.window_edges:
			frame_for(points,int(edge))
			var columns := maxi(1,ceili(length/1.5))
			for y in rotunda.window_centers:
				panel(length/2,float(y),length,2.4,0.08,0.08,glass)
				for i in columns+1:
					panel(i*length/columns,float(y),0.06,2.45,0.12,0.16,metal)
				for dy in [-1.2,0.4,1.2]:
					panel(length/2,float(y)+dy,length,0.06,0.12,0.16,metal)
		for edge in rotunda.column_edges:
			frame_for(points,int(edge))
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.35
			cylinder.bottom_radius = 0.35
			cylinder.height = 8.8
			cylinder.radial_segments = 24
			cylinder.rings = 1
			var p := origin+axis*length/2+out*0.48
			var column: MeshInstance3D = host.mesh_node(group,cylinder,stone,"AcademicRoundColumn")
			column.position = Vector3(p.x,4.4,p.y)
			column.set_meta("walk_collision",true)
			column.set_meta("preserve_round_column",true)
	for bay in profile.get("court_bays",[]):
		frame_for(points,int(bay.edge))
		var start: float = length*float(bay.span[0])
		var finish: float = length*float(bay.span[1])
		var center := (start+finish)/2
		var width := (finish-start)*0.78
		for y in [2.2,6.6]:
			panel(center,y,width,2.3,0.08,0.08,glass)
			for i in 9:
				panel(center-width/2+i*width/8,y,0.07,2.4,0.12,0.17,metal)
			for dy in [-1.15,0.5,1.15]:
				panel(center,y+dy,width+0.1,0.07,0.12,0.17,metal)
			panel(center,y-1.5,width,0.55,0.16,0.14,stone)
		for x in [start,finish]:
			panel(x,height/2,0.4,height,0.8,0.4,wall,true)
		panel(center,4.4,finish-start,0.28,0.8,0.35,stone,true)
		panel(center,height+0.16,finish-start+0.4,0.22,1.2,0.45,stone,true)

	for canopy in profile.get("canopies",[]):
		frame_for(points,int(canopy.edge))
		var center: float = length*float(canopy.fraction)
		var width: float = canopy.width
		var projection: float = canopy.projection
		var y: float = canopy.y
		for x in [center-width/2,center+width/2]:
			panel(x,y,0.16,0.18,projection,projection/2,stone,true)
		for i in 4:
			panel(center,y,width,0.14,0.14,0.1+(projection-0.2)*i/3,stone,true)
	# Bounded upper shadow slots; these do not open an unverified interior.
	for slot in profile.get("roof_slots",[]):
		frame_for(points,int(slot.edge))
		var start: float = length*float(slot.span[0])
		var finish: float = length*float(slot.span[1])
		var shade: Material = host.material("EDA academic roof shadow recess",Color("252c29"))
		shade.albedo_texture = null
		shade.roughness = 0.95
		panel((start+finish)/2,float(slot.y),finish-start,float(slot.height),0.035,0.025,shade)

	if profile.has("curve_refinement"):
		var curve := preload("res://tools/eda_ellipse_envelope.gd").new()
		curve.configure(points,profile.curve_refinement)
		host.surface_deformations.append({"curve":curve,"group":group,"first_child":curve_first_child})

func build_tower_rods(x: float, tower: Dictionary, metal: Material) -> void:
	var rods: Dictionary = tower.head_rods
	for side in 2:
		var top: float = tower.head_fin_tops[side]
		var exposed := float(rods.exposed_height_m)
		var embed := float(rods.embed_m)
		var along := x+float(tower.width)*(side-0.5)
		var p := origin+axis*along+out*float(rods.offset_m)
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=float(rods.radius_m)
		cylinder.bottom_radius=cylinder.top_radius
		cylinder.height=exposed+embed
		cylinder.radial_segments=12
		cylinder.rings=1
		var rod: MeshInstance3D = host.mesh_node(group,cylinder,metal,"AcademicTowerRod")
		rod.position=Vector3(p.x,top+(exposed-embed)*0.5,p.y)
		rod.set_meta("walk_collision",false)
