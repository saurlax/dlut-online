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

func panel(x: float, y: float, width: float, height: float, depth: float, offset: float, mat: Material, solid := false) -> void:
	var pos := origin + axis*x + outward*offset
	var node: MeshInstance3D = host.box(group,Vector3(pos.x,y,pos.y),Vector3(width,height,depth),mat,"ResidenceDetail")
	node.rotation.y = -atan2(axis.y,axis.x)
	node.set_meta("walk_collision",solid)

func window(x: float, y: float, width: float, height: float) -> void:
	panel(x,y,width,height,0.08,0.08,glass)
	for dx in [-width/2.0,0.0,width/2.0]:
		panel(x+dx,y,0.055,height+0.1,0.12,0.16,frame)
	for dy in [-height/2.0,height*0.25,height/2.0]:
		panel(x,y+dy,width+0.1,0.055,0.12,0.16,frame)
	panel(x,y-height/2.0-0.06,width+0.18,0.1,0.26,0.17,frame)

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
	group.set_meta("photo_reference","references/photos/residence_facades.json")
	group.set_meta("interior_available",false)
	group.set_meta("photo_edges",[int(profile.edge)])
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
	shell(points,height,wall,"Building")
	shell(points,height+0.2,frame,"Roof",height)
	var edge := int(profile.edge)
	origin = points[edge]
	var end := points[(edge+1)%points.size()]
	axis = (end-origin).normalized()
	outward = Vector2(axis.y,-axis.x)
	if Geometry2D.is_point_in_polygon((origin+end)*0.5+outward,points):
		outward = -outward
	var length := origin.distance_to(end)
	var start: float = profile.span[0]*length
	var finish: float = profile.span[1]*length
	var count := int(profile.columns)
	var spacing := (finish-start)/count
	var balcony := -100.0 if profile.balcony_center == null else float(profile.balcony_center)*length
	var balcony_width := spacing*2.0
	for row in int(profile.get("window_rows",5)):
		var y := 4.8+row*3.15
		for col in count:
			var x := start+(col+0.5)*spacing
			var balcony_levels: Array = profile.get("balcony_levels",[9.85,13.0,16.15])
			if y>float(balcony_levels[0]) and y<float(balcony_levels[2]) and absf(x-balcony)<balcony_width*0.52:
				continue
			window(x,y,spacing*0.77,2.15)
			panel(x+spacing*0.35,y-1.43,spacing*0.22,0.48,0.07,0.1,accent)
			for dx in [-spacing*0.5,spacing*0.5]:
				panel(x+dx,y,0.18,3.15,0.22,0.12,frame)
		panel((start+finish)/2.0,y-1.2,finish-start,0.13,0.22,0.12,frame)
	# Smaller independent windows at the photographed connector-side ends.
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
			window(x,gallery_y,spacing*0.64,1.75)
			panel(start+col*spacing,gallery_y,0.2,2.8,0.8,0.4,wall,true)
		panel(finish,gallery_y,0.2,2.8,0.8,0.4,wall,true)
		panel((start+finish)/2.0,gallery_slab_y,finish-start,0.18,1.05,0.45,frame,true)
		var eaves_y: float = profile.get("eaves_y",23.1)
		if profile.has("eaves_upturn"):
			var turn: Dictionary = profile.eaves_upturn
			var tip := start-0.25
			var join: float = start+(finish-start)*float(turn.span_fraction)
			var rise: float = turn.rise
			var run := join-tip
			var pos := origin+axis*((tip+join)/2)+outward*0.6
			var inclined: MeshInstance3D = host.box(group,Vector3(pos.x,eaves_y+rise/2,pos.y),Vector3(sqrt(run*run+rise*rise),0.22,1.6),frame,"ResidenceUpturnedEave")
			var along := Vector3(axis.x*run,-rise,axis.y*run).normalized()
			var side := Vector3(-axis.y,0,axis.x)
			inclined.basis = Basis(along,side.cross(along),side)
			inclined.set_meta("walk_collision",true)
			panel((join+finish+0.25)/2,eaves_y,finish+0.25-join,0.22,1.6,0.6,frame,true)
		else:
			panel((start+finish)/2.0,eaves_y,finish-start+0.5,0.22,1.6,0.6,frame,true)
		if profile.get("enclosed_gallery",false):
			panel((start+finish)/2.0,gallery_y,finish-start,2.55,0.1,0.86,glass,true)
			for i in count*3+1:
				panel(start+(finish-start)*i/(count*3),gallery_y,0.065,2.65,0.12,0.94,frame)
			for dy in [-1.275,0.0,1.275]:
				panel((start+finish)/2.0,gallery_y+dy,finish-start,0.065,0.12,0.94,frame)
		else:
			railing((start+finish)/2.0,gallery_slab_y+0.15,finish-start,0.94,true)
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
		var tower_x := float(tower.fraction)*length
		var tower_height: float = tower.height
		var tower_width: float = tower.width
		var tower_depth: float = tower.depth
		var blue: Material = host.material("EDA residence blue grey stair tower",Color("78838b"))
		blue.albedo_texture = null
		panel(tower_x,tower_height/2,tower_width,tower_height,tower_depth,0.2-tower_depth/2,blue,true)
		# The two visible top slots stay closed; they do not expose an interior.
		for dx in [-0.6,0.6]:
			panel(tower_x+dx,21.4,0.8,2.0,0.06,0.24,glass)
		for dx in [-1.15,0.0,1.15]:
			panel(tower_x+dx,21.5,0.18,2.9,0.18,0.32,frame)
