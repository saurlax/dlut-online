extends RefCounted

# Individually registered photo-visible faces; no inferred rear windows or interiors.
var host
var group: Node3D
var origin: Vector2
var axis: Vector2
var outward: Vector2
var wall: Material
var frame: Material
var glass: Material
var accent: Material
var rail: Material
var facade_path: RefCounted

func panel(x: float, y: float, width: float, height: float, depth: float, offset: float, mat: Material, solid := false) -> void:
	var pos := origin + axis*x + outward*offset
	var node: MeshInstance3D = host.box(group,Vector3(pos.x,y,pos.y),Vector3(width,height,depth),mat,"ResidenceDetail")
	node.rotation.y = -atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)
	if facade_path != null: facade_path.deform(node)
	preload("res://tools/eda_surface_details.gd").tint_glazing(node,mat,x,y)

func window(x: float, y: float, width: float, height: float, detailed := false, reveals := true, transom_offset := INF, outward_shift := 0.0) -> void:
	panel(x,y,width,height,0.08,0.08+outward_shift,glass)
	# Main bays have shallow tiled reveals; keep small terminal windows unchanged.
	if detailed and reveals:
		for dx in [-width/2.0-0.055,width/2.0+0.055]:
			panel(x+dx,y,0.11,height+0.16,0.32,0.16,wall)
		panel(x,y+height/2.0+0.055,width+0.22,0.11,0.32,0.16,wall)
	var divisions: Array = [-width/2.0,-width*0.10,width*0.32,width/2.0] if detailed else [-width/2.0,0.0,width/2.0]
	for dx in divisions:
		panel(x+dx,y,0.055,height+0.1,0.12,0.16+outward_shift,frame)
	for dy in [-height/2.0,height*0.25 if is_inf(transom_offset) else transom_offset,height/2.0]:
		panel(x,y+dy,width+0.1,0.055,0.12,0.16+outward_shift,frame)
	panel(x,y-height/2.0-0.06,width+0.18,0.1,0.26,0.17+outward_shift,frame)

func window_grilles(settings: Dictionary, start: float, spacing: float) -> void:
	# Fixed to the registered window modules; no extra wall or collision.
	for col in settings.columns:
		var x:=start+(float(col)+0.5)*spacing
		var width:=spacing*0.77
		var count:=int(settings.vertical_bars)
		for i in range(1,count+1):
			var dx:float=-width/2+width*i/(count+1)
			panel(x+dx,float(settings.center_y),float(settings.bar_width_m),2.15,float(settings.bar_depth_m),float(settings.offset_m),rail)

func railing(x: float, y: float, width: float, offset: float, vertical: bool) -> void:
	for dy in [0.0,0.3,0.6,0.9]:
		panel(x,y+dy,width,0.045,0.05,offset,rail)
	var posts := maxi(2,ceili(width/(0.22 if vertical else 1.5)))
	for i in range(posts+1):
		panel(x-width/2.0+width*i/posts,y+0.45,0.04,0.94,0.05,offset,rail)

func shell(points: PackedVector2Array, height: float, mat: Material, title: String, base := 0.0) -> void:
	host.polygon(group,points,height,mat,title,base)
	var node: MeshInstance3D = group.get_child(group.get_child_count()-1)
	# append_from must receive indexed shell triangles when merging with BoxMesh.
	var surface := SurfaceTool.new()
	surface.create_from(node.mesh,0)
	surface.index()
	node.mesh = surface.commit()
	node.set_meta("walk_collision",true)

func build(builder, parent: Node3D, points: PackedVector2Array, profile: Dictionary) -> void:
	host = builder
	group = parent
	group.set_meta("photo_reference","references/eda/buildings/residence_facades.json")
	group.set_meta("interior_available",false)
	var photo_edges: Array = [int(profile.edge)]
	if profile.has("facade_vertices"):
		photo_edges.clear()
		for i in profile.facade_vertices.size()-1:
			photo_edges.append(mini(int(profile.facade_vertices[i]),int(profile.facade_vertices[i+1])))
	for side in profile.get("side_windows",[]): photo_edges.append(int(side.edge))
	if profile.has("stair_tower") and profile.stair_tower.has("edge"):
		photo_edges.append(int(profile.stair_tower.edge))
	for face_key in ["courtyard_windows","north_facade"]:
		if not profile.has(face_key): continue
		var vertices: Array = profile[face_key].vertices
		for i in vertices.size()-1:
			var a := int(vertices[i])
			var b := int(vertices[i+1])
			var wall_edge := maxi(a,b) if absi(a-b)==points.size()-1 else mini(a,b)
			if wall_edge not in photo_edges: photo_edges.append(wall_edge)
	group.set_meta("photo_edges",photo_edges)
	wall = host.material("EDA residence pale tile",Color("b8b6a3"))
	# Small rectangular ceramic tiles visible in each residence photo.
	var tile_image := Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var joint := x%32 == 0 or y%16 == 0
			var tone := 0.82 if joint else 0.96 + float((x/32+y/16*7)%5)*0.008
			tile_image.set_pixel(x,y,Color(tone,tone,tone))
	tile_image.generate_mipmaps()
	wall.albedo_texture = ImageTexture.create_from_image(tile_image)
	wall.uv1_scale = Vector3.ONE*2.0
	frame = host.material("EDA residence ivory frames",Color("d5d2bc"))
	glass = host.material("EDA residence opaque glazing",Color("536567"))
	accent = host.material("EDA residence lavender panels",Color("9794a7"))
	rail = host.material("EDA residence railing",Color("515957"))
	for mat in [frame,glass,accent,rail]:
		mat.albedo_texture = null
	glass.metallic = 0.35
	glass.roughness = 0.28
	var height: float = profile.height
	if profile.has("end_gallery"):
		var gallery: Dictionary = profile.end_gallery
		var recessed := PackedVector2Array()
		var recess_edge := int(profile.get("recess_edge",profile.edge))
		var recess_span: Array = profile.get("recess_span",gallery.span)
		var a := points[recess_edge]
		var b := points[(recess_edge+1)%points.size()]
		var out := Vector2((b-a).y,-(b-a).x).normalized()
		if Geometry2D.is_point_in_polygon((a+b)/2+out,points): out = -out
		for i in points.size():
			recessed.append(points[i])
			if i==recess_edge:
				var first := a.lerp(b,float(recess_span[0]))
				var last := a.lerp(b,float(recess_span[1]))
				recessed.append(first)
				recessed.append(first-out*float(gallery.depth))
				recessed.append(last-out*float(gallery.depth))
				recessed.append(last)
		if profile.has("ground_arcade"):
			preload("res://tools/build_eda_residence_arcade.gd").new().build(self,points,profile,float(gallery.bottom))
		else:
			shell(points,float(gallery.bottom),wall,"GalleryBase")
		shell(recessed,float(gallery.top),wall,"GalleryRecess",float(gallery.bottom))
		shell(points,height,wall,"GalleryHead",float(gallery.top))
	else:
		shell(points,height,wall,"Building")
	shell(points,height+0.2,frame,"Roof",height)
	var edge := int(profile.edge)
	origin = points[edge]
	var end := points[(edge+1)%points.size()]
	if profile.get("reverse_edge",false):
		assert(not profile.has("end_gallery"),"Recessed gallery needs explicit reversed polygon registration")
		origin = points[(edge+1)%points.size()]
		end = points[edge]
	axis = (end-origin).normalized()
	outward = Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+end)*0.5+outward,points):
		outward = -outward
	var length := origin.distance_to(end)
	if profile.has("facade_vertices"):
		facade_path = preload("res://tools/residence_facade_path.gd").new()
		facade_path.configure(points,profile.facade_vertices)
		origin = facade_path.origin
		axis = facade_path.axis
		outward = facade_path.outward
		length = facade_path.length
		group.set_meta("photo_facade_vertices",profile.facade_vertices)
	if profile.has("ground_arcade") and profile.ground_arcade.has("rear_windows"):
		var arcade: Dictionary = profile.ground_arcade
		var rear: Dictionary = arcade.rear_windows
		var front_origin := origin
		origin -= outward*float(arcade.depth)
		for opening in rear.openings:
			var fraction := lerpf(float(arcade.span[0]),float(arcade.span[1]),(float(opening.bay)+float(opening.within_bay))/int(arcade.bays))
			window(fraction*length,float(rear.center_y),float(opening.get("width",rear.width)),float(rear.height),true,false)
		if arcade.has("rear_entry"):
			var entry:Dictionary=arcade.rear_entry.duplicate(true)
			entry.fraction=lerpf(float(arcade.span[0]),float(arcade.span[1]),(float(entry.bay)+float(entry.within_bay))/int(arcade.bays))
			preload("res://tools/build_eda_residence_entry.gd").new().build(self,entry,true)
		origin = front_origin
	if profile.has("end_gallery"):
		var gallery: Dictionary = profile.end_gallery
		var first: float = length*float(gallery.span[0])
		var last: float = length*float(gallery.span[1])
		var depth: float = gallery.depth
		for floor_y in gallery.floors:
			panel((first+last)/2,float(floor_y),last-first,0.18,depth,-depth/2,frame,true)
			railing((first+last)/2,float(floor_y)+0.15,last-first,0.02,true)
	var start: float = profile.span[0]*length
	var finish: float = profile.span[1]*length
	var count := int(profile.columns)
	var spacing := (finish-start)/count
	if profile.has("window_grilles"):window_grilles(profile.window_grilles,start,spacing)
	var balcony := -100.0 if profile.balcony_center == null else float(profile.balcony_center)*length
	var balcony_width := spacing*2.0
	if profile.has("roof_panels"):
		preload("res://tools/build_eda_residence_roof.gd").new().build(self,profile.roof_panels,length)
	for row in int(profile.get("window_rows",5)):
		var y := 4.8+row*3.15
		for col in count:
			var x := start+(col+0.5)*spacing
			var balcony_levels: Array = profile.get("balcony_levels",[9.85,13.0,16.15])
			if y>float(balcony_levels[0]) and y<float(balcony_levels[2]) and absf(x-balcony)<balcony_width*0.52:
				continue
			window(x,y,spacing*0.77,2.15,true)
			panel(x+spacing*0.35,y-1.43,spacing*0.22,0.48,0.07,0.1,accent)
			for dx in [-spacing*0.5,spacing*0.5]:
				panel(x+dx,y,0.18,3.15,0.22,0.12,frame)
		panel((start+finish)/2.0,y-1.2,finish-start,0.13,0.22,0.12,frame)
	# Smaller independent windows at the photographed connector-side ends.
	if profile.has("terminal_vents"):
		var vents: Dictionary = profile.terminal_vents
		var size: float = vents.size
		for fraction in vents.fractions:
			var x: float = float(fraction)*length
			for center_y in profile.terminal_windows.centers_y:
				for offset in vents.row_offsets:
					var y: float = float(center_y)+float(offset)
					panel(x,y,size,size,0.06,0.06,glass)
					for side in [-1.0,1.0]:
						panel(x+side*size/2,y,0.045,size+0.045,0.12,0.13,frame)
						panel(x,y+side*size/2,size+0.045,0.045,0.12,0.13,frame)
	if profile.has("terminal_windows"):
		var terminal: Dictionary = profile.terminal_windows
		for fraction in terminal.fractions:
			for y in terminal.centers_y:
				window(float(fraction)*length,float(y),float(terminal.width),float(terminal.height))
	if profile.get("gallery_available",true):
		# Only the visible upper gallery: closed shell behind it, no invented access.
		var gallery_y: float = profile.get("gallery_y",20.65)
		var gallery_slab_y: float = profile.get("gallery_slab_y",19.25)
		for col in count:
			var x := start+(col+0.5)*spacing
			window(x,gallery_y,spacing*float(profile.get("gallery_window_width_ratio",0.64)),float(profile.get("gallery_window_height",1.75)))
			panel(start+col*spacing,gallery_y,0.2,2.8,0.8,0.4,wall,true)
		panel(finish,gallery_y,0.2,2.8,0.8,0.4,wall,true)
		panel((start+finish)/2.0,gallery_slab_y,finish-start,0.18,1.05,0.45,frame,true)
		var eaves_y: float = profile.get("eaves_y",23.1)
		if profile.has("eaves_upturn"):
			var turn: Dictionary = profile.eaves_upturn
			var at_end: bool = turn.get("at_end",false)
			var tip := finish+0.25 if at_end else start-0.25
			var join: float = finish-(finish-start)*float(turn.span_fraction) if at_end else start+(finish-start)*float(turn.span_fraction)
			var rise: float = turn.rise
			var run := join-tip
			var pos := origin+axis*((tip+join)/2)+outward*0.6
			var inclined: MeshInstance3D = host.box(group,Vector3(pos.x,eaves_y+rise/2,pos.y),Vector3(sqrt(run*run+rise*rise),0.22,1.6),frame,"ResidenceUpturnedEave")
			var along := Vector3(axis.x*run,-rise,axis.y*run).normalized()
			var side := Vector3(-axis.y,0,axis.x)
			inclined.basis = Basis(along,side.cross(along),side)
			inclined.set_meta("walk_collision",true)
			if facade_path != null: facade_path.deform(inclined)
			var flat_start := start-0.25 if at_end else join
			var flat_end := join if at_end else finish+0.25
			panel((flat_start+flat_end)/2,eaves_y,flat_end-flat_start,0.22,1.6,0.6,frame,true)
		else:
			var eave_span: Array = profile.get("eaves_span",profile.span)
			var eave_start := float(eave_span[0])*length
			var eave_end := float(eave_span[1])*length
			panel((eave_start+eave_end)/2.0,eaves_y,eave_end-eave_start+0.5,0.22,1.6,0.6,frame,true)
		if profile.get("enclosed_gallery",false):
			panel((start+finish)/2.0,gallery_y,finish-start,2.55,0.1,0.86,glass,true)
			for i in count*3+1:
				panel(start+(finish-start)*i/(count*3),gallery_y,0.065,2.65,0.12,0.94,frame)
			for dy in [-1.275,float(profile.get("gallery_transom_offset",0.0)),1.275]:
				panel((start+finish)/2.0,gallery_y+dy,finish-start,0.065,0.12,0.94,frame)
		if not profile.get("enclosed_gallery",false) or profile.get("gallery_outer_railing",false):
			railing((start+finish)/2.0,gallery_slab_y+0.15,finish-start,0.94,true)
	for extra in profile.get("additional_windows",[]):
		for y in extra.centers_y:
			var x:=float(extra.fraction)*length
			var width:=float(extra.width)
			window(x,float(y),width,float(extra.height),bool(extra.get("detailed",false)),false,float(extra.get("transom_offset",INF)),float(extra.get("outward_shift",0.0)))
			var bars:=int(extra.get("vertical_bars",0))
			for i in range(1,bars+1):
				panel(x-width/2+width*i/(bars+1),float(y),0.016,float(extra.height),0.02,0.24,rail)
			if extra.has("guard"):
				var guard:Dictionary=extra.guard
				var bottom:=float(guard.get("bottom",float(y)-float(extra.height)/2+0.06))
				var guard_height:=float(guard.height)
				var guard_offset:=float(guard.get("offset",0.31))
				var mat:Material=frame if bool(guard.get("light",false)) else rail
				var vertical:=bool(guard.get("vertical",false))
				var rows:=2 if vertical else 4
				for row in rows:
					panel(x,bottom+guard_height*row/(rows-1),width,0.035,0.04,guard_offset,mat)
				var posts:=maxi(2,ceili(width/0.15)) if vertical else 1
				for post in posts+1:
					panel(x-width/2+width*post/posts,bottom+guard_height/2,0.025,guard_height,0.04,guard_offset,mat)
	if profile.get("ground_windows",false):
		for col in count:
			var x := start+(col+0.5)*spacing
			# The area below the yellow surround includes doors and is not inferred.
			if absf(x-balcony)<balcony_width*0.65: continue
			window(x,1.7,spacing*0.77,2.4)
	if profile.get("ground_bars",false):
		for col in count:
			var x := start+(col+0.5)*spacing
			var width := spacing*0.77
			window(x,1.7,width,2.4)
			var bars := maxi(2,ceili(width/0.18))
			for i in bars+1:
				panel(x-width/2+float(i)*width/bars,1.7,0.035,2.45,0.05,0.3,frame)
			for y in [0.5,1.7,2.9]:
				panel(x,y,width,0.04,0.05,0.3,frame)
			# The close photo shows boxed guards with side returns to the wall.
			for dx in [-width/2,width/2]:
				panel(x+dx,1.7,0.045,2.45,0.24,0.18,frame)
			for y in [0.5,2.9]:
				panel(x,y,width+0.08,0.06,0.24,0.18,frame)

	if profile.has("yellow_frame"):
		# Sixth residence photo confirms a surround, not the balcony layout behind it.
		var surround: Dictionary = profile.yellow_frame
		var yellow: Material = host.material("EDA residence yellow surround",Color("d5ae25"))
		yellow.albedo_texture = null
		var center := float(surround.fraction)*length
		var width: float = surround.width
		var bottom: float = surround.bottom
		var top: float = surround.top
		var border: float = surround.border
		for x in [center-(width-border)/2,center+(width-border)/2]:
			panel(x,(bottom+top)/2,border,top-bottom,float(surround.depth),float(surround.offset),yellow)
		for y in [bottom+border/2,top-border/2]:
			panel(center,y,width-2*border,border,float(surround.depth),float(surround.offset),yellow)

	if profile.balcony_center != null:
		var yellow: Material = host.material("EDA residence yellow surround",Color("d5ae25"))
		yellow.albedo_texture = null
		# Two open balcony bays per floor, outside the retained closed footprint.
		var levels: Array = profile.get("balcony_levels",[9.85,13.0,16.15])
		var middle: float = levels[1]
		for y in levels:
			panel(balcony,y,balcony_width,0.2,1.25,0.57,wall,true)
		for x in [balcony-balcony_width/2.0,balcony,balcony+balcony_width/2.0]:
			panel(x,middle,0.22,6.5,1.25,0.57,wall,true)
		if profile.get("enclosed_balcony",false):
			for floor_index in 2:
				var lower := float(levels[floor_index])
				var upper := float(levels[floor_index+1])
				var center := (lower+upper)*0.5
				panel(balcony,center,balcony_width-0.3,upper-lower-0.2,0.1,1.18,glass,true)
				for i in 7:
					panel(balcony-balcony_width/2+balcony_width*i/6,center,0.065,upper-lower-0.1,0.12,1.26,frame)
				for y in [lower+0.1,center,upper-0.1]:
					panel(balcony,y,balcony_width,0.065,0.12,1.26,frame)
		else:
			for y in [float(levels[0])+0.17,middle+0.17]:
				railing(balcony,y,balcony_width-0.3,1.16,false)
		for x in [balcony-balcony_width/2.0,balcony+balcony_width/2.0]:
			panel(x,middle,0.55,7.0,0.18,1.3,yellow)
		for y in [float(levels[0])-0.35,float(levels[2])+0.35]:
			panel(balcony,y,balcony_width+0.55,0.55,0.18,1.3,yellow)

	if profile.has("stair_tower"):
		var tower: Dictionary = profile.stair_tower
		if tower.has("edge"):
			facade_path = null
			origin = points[int(tower.edge)]
			var tower_end := points[(int(tower.edge)+1)%points.size()]
			axis = (tower_end-origin).normalized()
			outward = Vector2(axis.y,-axis.x)
			if Geometry2D.is_point_in_polygon((origin+tower_end)/2+outward,points): outward = -outward
			length = origin.distance_to(tower_end)
		var tower_x := float(tower.fraction)*length
		var tower_height: float = tower.height
		var tower_width: float = tower.width
		var tower_depth: float = tower.depth
		var blue: Material = host.material("EDA residence blue grey stair tower",Color("78838b"))
		blue.albedo_texture = null
		panel(tower_x,tower_height/2,tower_width,tower_height,tower_depth,0.2-tower_depth/2,blue,true)
		# The two visible top slots stay closed; they do not expose an interior.
		var slot_y: float = tower.get("slot_y",21.4)
		for dx in [-0.6,0.6]:
			panel(tower_x+dx,slot_y,0.8,2.0,0.06,0.24,glass)
		for dx in [-1.15,0.0,1.15]:
			panel(tower_x+dx,slot_y+0.1,0.18,2.9,0.18,0.32,frame)

	for side in profile.get("side_windows",[]):
		facade_path = null
		origin = points[int(side.edge)]
		var end_point := points[(int(side.edge)+1)%points.size()]
		axis = (end_point-origin).normalized()
		outward = Vector2(axis.y,-axis.x)
		if Geometry2D.is_point_in_polygon((origin+end_point)/2+outward,points): outward = -outward
		for fraction in side.fractions:
			for y in side.centers_y:
				window(origin.distance_to(end_point)*float(fraction),float(y),float(side.width),float(side.height))

	if profile.has("courtyard_windows"):
		var courtyard: Dictionary = profile.courtyard_windows
		facade_path = preload("res://tools/residence_facade_path.gd").new()
		facade_path.configure(points,courtyard.vertices)
		origin = facade_path.origin
		axis = facade_path.axis
		outward = facade_path.outward
		var first: float = float(courtyard.span[0])*facade_path.length
		var last: float = float(courtyard.span[1])*facade_path.length
		var count_courtyard := int(courtyard.columns)
		var bay_width: float = (last-first)/count_courtyard
		var glazing_width := float(courtyard.get("glazing_width_fraction",0.77))*bay_width
		var alternating_offset := float(courtyard.get("alternating_offset_fraction",0.0))*bay_width
		var infill: Material
		if alternating_offset>0:
			infill = host.material("EDA residence gray infill",Color("858784"))
			infill.albedo_texture = null
		for row in courtyard.centers_y.size():
			var y := float(courtyard.centers_y[row])
			var shift := alternating_offset*(1.0 if row%2==0 else -1.0)
			for column in count_courtyard:
				var x: float = first+(column+0.5)*bay_width
				if infill!=null:
					# The complete opening stays fixed while its internal glazing alternates.
					panel(x,y-0.35,bay_width*0.90,2.85,0.04,0.035,infill)
					for side in [-1.0,1.0]:
						panel(x+side*bay_width*0.45,y-0.35,0.055,2.95,0.12,0.16,frame)
					for level in [-1.775,1.075]:
						panel(x,y+level,bay_width*0.90+0.055,0.055,0.12,0.16,frame)
					var division := x+shift-signf(shift)*glazing_width/2
					panel(division,y-1.425,0.055,0.70,0.12,0.16,frame)
					panel(x,y-1.075,bay_width*0.90,0.055,0.12,0.16,frame)
				window(x+shift,y,glazing_width,2.15,true,infill==null)
				var accent_side := -1.0 if shift>0 else 1.0
				panel(x+accent_side*bay_width*(0.34 if infill!=null else 0.35),y-1.425 if infill!=null else y-1.43,bay_width*0.22,0.65 if infill!=null else 0.48,0.07,0.1,accent)
				for dx in [-bay_width/2,bay_width/2]: panel(x+dx,float(y),0.18,3.15,0.22,0.12,frame)
			if infill==null: panel((first+last)/2,float(y)-1.2,last-first,0.13,0.22,0.12,frame)
			window(float(courtyard.terminal_fraction)*facade_path.length,float(y),2.2,1.65)
		for column in count_courtyard*2:
			window(first+(column+0.5)*bay_width/2,float(courtyard.gallery_y),bay_width*0.43,float(courtyard.gallery_height))
		if courtyard.has("gallery_railing"):
			var guard: Dictionary = courtyard.gallery_railing
			var guard_start: float = facade_path.length*float(guard.span[0])
			var guard_end: float = facade_path.length*float(guard.span[1])
			var guard_width := guard_end-guard_start
			var bottom: float = guard.bottom_y
			var guard_height: float = guard.height
			var offset: float = guard.offset
			for y in [bottom,bottom+guard_height]:
				panel((guard_start+guard_end)/2,y,guard_width,0.035,0.04,offset,frame)
			var bars := ceili(guard_width/float(guard.spacing))
			for i in range(bars+1):
				panel(guard_start+guard_width*i/bars,bottom+guard_height/2,0.02,guard_height,0.025,offset,frame)
			var posts := ceili(guard_width/float(guard.post_spacing))
			for i in range(posts+1):
				panel(guard_start+guard_width*i/posts,bottom+guard_height/2,0.045,guard_height+0.05,0.05,offset,frame)
		if courtyard.has("eave"):
			var eave: Dictionary = courtyard.eave
			var join: float = facade_path.length*float(eave.upturn_start)
			var tip: float = facade_path.length+float(eave.end_extension)
			panel(join/2,float(eave.center_y),join,float(eave.thickness),float(eave.depth),float(eave.offset),frame,true)
			var run := tip-join
			var pos := origin+axis*((join+tip)/2)+outward*float(eave.offset)
			var raised: MeshInstance3D = host.box(group,Vector3(pos.x,float(eave.center_y),pos.y),Vector3(run,float(eave.thickness),float(eave.depth)),frame,"CourtyardRaisedEave")
			# Shear the slab, keeping the shared join vertical and exactly closed.
			var arrays := raised.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size(): vertices[i].y += float(eave.rise)*(vertices[i].x/run+0.5)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			raised.mesh = mesh
			raised.rotation.y = -atan2(axis.y,axis.x)
			raised.set_meta("walk_collision",true)
			facade_path.deform(raised)
		if courtyard.has("ground_windows"):
			var ground: Dictionary = courtyard.ground_windows
			var centers: Array[float] = []
			for column in ground.columns:
				centers.append(first+(float(column)+0.5)*bay_width)
			if ground.get("terminal",false): centers.append(float(courtyard.terminal_fraction)*facade_path.length)
			var width: float = ground.width
			var window_height: float = ground.height
			var y: float = ground.center_y
			var bars := ceili(width/float(ground.bar_spacing))
			for x in centers:
				window(x,y,width,window_height)
				for i in range(bars+1):
					panel(x-width/2+width*i/bars,y,0.018,window_height,0.022,0.27,rail)
				for dy in [-window_height/2,window_height/2]:
					panel(x,y+dy,width+0.04,0.025,0.025,0.27,rail)
		if courtyard.has("entry"):
			preload("res://tools/build_eda_residence_entry.gd").new().build(self,courtyard.entry)

	if profile.has("north_facade"):
		preload("res://tools/build_eda_residence_north.gd").new().build(self,points,profile.north_facade)

	if profile.has("number_markers"):
		preload("res://tools/build_eda_residence_markers.gd").new().build(self,points,profile.number_markers)
