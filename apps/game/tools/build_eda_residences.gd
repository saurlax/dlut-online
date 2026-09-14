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
	for row in 5:
		var y := 4.8+row*3.15
		for col in count:
			var x := start+(col+0.5)*spacing
			if row in [2,3] and absf(x-balcony)<balcony_width*0.52:
				continue
			window(x,y,spacing*0.77,2.15)
			panel(x+spacing*0.35,y-1.43,spacing*0.22,0.48,0.07,0.1,accent)
			for dx in [-spacing*0.5,spacing*0.5]:
				panel(x+dx,y,0.18,3.15,0.22,0.12,frame)
		panel((start+finish)/2.0,y-1.2,finish-start,0.13,0.22,0.12,frame)
	# Only the visible upper gallery: closed shell behind it, no invented access.
	for col in count:
		var x := start+(col+0.5)*spacing
		window(x,20.65,spacing*0.64,1.75)
		panel(start+col*spacing,20.65,0.2,2.8,0.8,0.4,wall,true)
	panel(finish,20.65,0.2,2.8,0.8,0.4,wall,true)
	panel((start+finish)/2.0,19.25,finish-start,0.18,1.05,0.45,frame,true)
	panel((start+finish)/2.0,23.1,finish-start+0.5,0.22,1.6,0.6,frame,true)
	railing((start+finish)/2.0,19.4,finish-start,0.94,true)
	if profile.balcony_center != null:
		var yellow: Material = host.material("EDA residence yellow surround",Color("d5ae25"))
		yellow.albedo_texture = null
		# Two open balcony bays per floor, outside the retained closed footprint.
		for y in [9.85,13.0,16.15]:
			panel(balcony,y,balcony_width,0.2,1.25,0.57,wall,true)
		for x in [balcony-balcony_width/2.0,balcony,balcony+balcony_width/2.0]:
			panel(x,13.0,0.22,6.5,1.25,0.57,wall,true)
		for y in [10.02,13.17]:
			railing(balcony,y,balcony_width-0.3,1.16,false)
		for x in [balcony-balcony_width/2.0,balcony+balcony_width/2.0]:
			panel(x,13.0,0.55,7.0,0.18,1.3,yellow)
		for y in [9.5,16.5]:
			panel(balcony,y,balcony_width+0.55,0.55,0.18,1.3,yellow)
